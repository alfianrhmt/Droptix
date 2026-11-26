import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_config.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/chat_widgets.dart';
import '../listings/listing_detail_screen.dart';
import '../listings/listing_models.dart';
import '../moderation/moderation_repository.dart';
import '../moderation/report_bottom_sheet.dart';
import 'chat_models.dart';
import 'chat_repository.dart';
import 'chat_socket_service.dart';

typedef UrlLauncherFn = Future<bool> Function(Uri uri);

/// Layar obrolan chat per DESIGN.md bagian 9b.
/// Memuat ChatListingCard di bawah AppBar, riwayat ChatBubble dengan DateSeparator,
/// QuickReplyChips jika chat kosong, dan ChatInput di bagian bawah.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.conversationId,
    this.listingId,
    this.initialConversation,
    this.listingDetail,
    this.chatRepository,
    this.socketService,
    this.urlLauncher,
    this.moderationRepository,
  });

  final int? conversationId;
  final int? listingId;
  final ConversationModel? initialConversation;
  final ListingItem? listingDetail;
  final ChatRepository? chatRepository;
  final ChatSocketService? socketService;
  final UrlLauncherFn? urlLauncher;
  final ModerationRepository? moderationRepository;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatRepository _repo;
  ChatSocketService? _socketService;
  bool _repoInitialized = false;

  int? _conversationId;
  int? _listingId;
  ConversationModel? _conversation;
  ListingItem? _listingDetail;

  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _isBlocked = false;

  Timer? _pollingTimer;
  StreamSubscription? _socketSubscription;
  StreamSubscription? _socketDeleteSubscription;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId ?? widget.initialConversation?.id;
    _listingId = widget.listingId ??
        widget.initialConversation?.listing.id ??
        widget.listingDetail?.id;
    _conversation = widget.initialConversation;
    _listingDetail = widget.listingDetail;

    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInitialized) {
      final client = AuthScope.of(context).repository.client;
      _repo = widget.chatRepository ?? ChatRepository(client);
      _socketService = widget.socketService;

      _repoInitialized = true;
      _initChat();
      _startPolling();
      _listenToSocket();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _socketSubscription?.cancel();
    _socketDeleteSubscription?.cancel();
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 150 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadOlderMessages();
    }
  }

  Future<void> _initChat() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Jika percakapan belum diketahui ID-nya, coba cari berdasarkan listingId
      if (_conversationId == null && _listingId != null) {
        final existing = await _repo.getConversationForListing(_listingId!);
        if (existing != null) {
          _conversation = existing;
          _conversationId = existing.id;
        }
      }

      // 2. Jika percakapan sudah ada, muat pesan dan tandai sudah dibaca
      if (_conversationId != null) {
        _conversation ??= await _repo.getConversation(_conversationId!);

        final res = await _repo.getMessages(_conversationId!);
        _messages = res.messages;
        _hasMore = res.adaLebihLama;

        // Tandai dibaca
        _repo.markAsRead(_conversationId!).catchError((_) => (
              belumDibaca: 0,
              chatsBelumDibaca: 0,
            ));
      } else {
        // Chat baru (belum ada pesan)
        _messages = [];
        _hasMore = false;
      }
    } on ApiException catch (e) {
      if (e.code == 'BLOCKED') {
        _isBlocked = true;
      } else {
        _errorMessage = e.message;
      }
    } catch (e) {
      _errorMessage = 'Gagal memuat percakapan. Silakan coba lagi.';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Polling tiap 5 detik sebagai cadangan (API.md bagian 10)
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_conversationId == null || !mounted) return;
      try {
        final res = await _repo.getMessages(_conversationId!, limit: 30);
        if (!mounted) return;

        // Jangan duplikasi pesan yang sudah ada atau sedang dikirim secara optimistik
        final serverList = res.messages;
        final serverIds = serverList.map((m) => m.id).toSet();
        final existingIds = _messages.map((m) => m.id).toSet();

        final newOnes = serverList.where((incoming) {
          if (existingIds.contains(incoming.id)) return false;
          // Cek apakah cocok dengan pesan optimistik yang masih berstatus sending
          final matchesPending = _messages.any(
            (m) =>
                m.id < 0 &&
                m.sendStatus == MessageSendStatus.sending &&
                m.senderId == incoming.senderId &&
                m.isi == incoming.isi,
          );
          return !matchesPending;
        }).toList();

        // Deteksi pesan terhapus di rentang 30 pesan terbaru server
        final oldestServerId = serverList.isNotEmpty ? serverList.last.id : null;
        final hasDeletedLocal = _messages.any(
          (m) =>
              m.id > 0 &&
              (oldestServerId == null || m.id >= oldestServerId) &&
              !serverIds.contains(m.id),
        );

        if (newOnes.isNotEmpty || hasDeletedLocal) {
          setState(() {
            var updated = _messages.where((m) {
              if (m.id <= 0) return true;
              if (oldestServerId != null && m.id < oldestServerId) return true;
              return serverIds.contains(m.id);
            }).toList();

            if (newOnes.isNotEmpty) {
              updated = [...newOnes, ...updated];
            }
            _messages = updated;
          });
          if (newOnes.isNotEmpty) {
            _repo.markAsRead(_conversationId!).catchError((_) => (
                  belumDibaca: 0,
                  chatsBelumDibaca: 0,
                ));
          }
        }
      } catch (_) {
        // Jangan tampilkan dialog error pada polling latar belakang
      }
    });
  }

  void _listenToSocket() {
    if (_socketService == null) return;
    _socketSubscription = _socketService!.onNewMessage.listen((data) {
      if (!mounted) return;
      final convData = data['conversation'] as Map?;
      final incomingConvId = convData?['id'];
      final msgData = data['message'] as Map?;

      if (_conversationId != null &&
          incomingConvId != null &&
          _conversationId == incomingConvId &&
          msgData != null) {
        final newMsg =
            ChatMessageModel.fromJson(Map<String, dynamic>.from(msgData));

        if (_messages.any((m) => m.id == newMsg.id)) return;

        // Jika cocok dengan pesan optimistik yang sedang dikirim, ganti saja
        final pendingIdx = _messages.indexWhere(
          (m) =>
              m.id < 0 &&
              m.sendStatus == MessageSendStatus.sending &&
              m.senderId == newMsg.senderId &&
              m.isi == newMsg.isi,
        );

        setState(() {
          if (pendingIdx != -1) {
            _messages[pendingIdx] = newMsg;
          } else {
            _messages.insert(0, newMsg);
          }
        });
        _repo.markAsRead(_conversationId!).catchError((_) => (
              belumDibaca: 0,
              chatsBelumDibaca: 0,
            ));
      }
    });

    _socketDeleteSubscription = _socketService!.onMessageDeleted.listen((data) {
      if (!mounted) return;
      final incomingConvId = (data['conversation_id'] as num?)?.toInt();
      final deletedMsgId = (data['message_id'] as num?)?.toInt();
      if (_conversationId != null &&
          incomingConvId == _conversationId &&
          deletedMsgId != null) {
        setState(() {
          _messages.removeWhere((m) => m.id == deletedMsgId);
        });
      }
    });
  }

  Future<void> _loadOlderMessages() async {
    if (_conversationId == null || _messages.isEmpty) return;
    setState(() => _isLoadingMore = true);

    try {
      final oldestId = _messages.last.id;
      final res = await _repo.getMessages(
        _conversationId!,
        before: oldestId,
        limit: 30,
      );

      if (mounted) {
        setState(() {
          _messages.addAll(res.messages);
          _hasMore = res.adaLebihLama;
        });
      }
    } catch (_) {
      // Abaikan error pagination
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final currentUserId = AuthScope.of(context).user?.id ?? 0;

    // Pesan optimistik lokal
    final tempMsg = ChatMessageModel(
      id: -DateTime.now().millisecondsSinceEpoch,
      conversationId: _conversationId ?? 0,
      senderId: currentUserId,
      isi: trimmed,
      createdAt: DateTime.now(),
      sendStatus: MessageSendStatus.sending,
    );

    setState(() {
      _messages.insert(0, tempMsg);
    });

    try {
      if (_conversationId != null) {
        // Percakapan sudah ada
        final sent = await _repo.sendMessage(_conversationId!, trimmed);
        if (!mounted) return;
        setState(() {
          // Hapus duplikat jika pesan dengan ID sama sudah masuk lewat polling/socket
          _messages.removeWhere((m) => m.id == sent.id);
          final idx = _messages.indexWhere((m) => m.id == tempMsg.id);
          if (idx != -1) {
            _messages[idx] = sent;
          } else {
            _messages.insert(0, sent);
          }
        });
      } else if (_listingId != null) {
        // Percakapan baru
        final res = await _repo.startListingConversation(_listingId!, trimmed);
        if (!mounted) return;
        setState(() {
          _conversationId = res.conversation.id;
          _conversation = res.conversation;
          _messages.removeWhere((m) => m.id == res.message.id);
          final idx = _messages.indexWhere((m) => m.id == tempMsg.id);
          if (idx != -1) {
            _messages[idx] = res.message;
          } else {
            _messages.insert(0, res.message);
          }
        });
        _startPolling();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'BLOCKED') {
        setState(() {
          _isBlocked = true;
          _messages.removeWhere((m) => m.id == tempMsg.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.urgent,
          ),
        );
      } else {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == tempMsg.id);
          if (idx != -1) {
            _messages[idx] = tempMsg.copyWith(
              sendStatus: MessageSendStatus.failed,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.urgent,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempMsg.id);
        if (idx != -1) {
          _messages[idx] = tempMsg.copyWith(
            sendStatus: MessageSendStatus.failed,
          );
        }
      });
    }
  }

  Future<void> _retryMessage(ChatMessageModel failedMsg) async {
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == failedMsg.id);
      if (idx != -1) {
        _messages[idx] = failedMsg.copyWith(
          sendStatus: MessageSendStatus.sending,
        );
      }
    });

    try {
      if (_conversationId != null) {
        final sent =
            await _repo.sendMessage(_conversationId!, failedMsg.isi);
        if (!mounted) return;
        setState(() {
          _messages.removeWhere((m) => m.id == sent.id);
          final idx = _messages.indexWhere((m) => m.id == failedMsg.id);
          if (idx != -1) {
            _messages[idx] = sent;
          } else {
            _messages.insert(0, sent);
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == failedMsg.id);
        if (idx != -1) {
          _messages[idx] = failedMsg.copyWith(
            sendStatus: MessageSendStatus.failed,
          );
        }
      });
    }
  }

  Future<void> _showMessageActions(ChatMessageModel msg, bool isSelf) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_rounded,
                    color: AppColors.textPrimary),
                title: Text('Salin pesan', style: AppTextStyles.body),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await Clipboard.setData(ClipboardData(text: msg.isi));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pesan disalin.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              if (isSelf && msg.sendStatus != MessageSendStatus.sending)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.urgent),
                  title: Text(
                    'Hapus pesan',
                    style:
                        AppTextStyles.body.copyWith(color: AppColors.urgent),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmDeleteMessage(msg);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMessage(ChatMessageModel msg) async {
    // Jika pesan lokal gagal terkirim, langsung hapus tanpa perlu API
    if (msg.id <= 0) {
      setState(() {
        _messages.removeWhere((m) => m.id == msg.id);
      });
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Hapus pesan?', style: AppTextStyles.titleMedium),
        content: Text(
          'Pesan ini akan dihapus dari percakapan untuk semua peserta.',
          style:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Hapus',
              style: AppTextStyles.label.copyWith(color: AppColors.urgent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted || _conversationId == null) return;

    final removedIdx = _messages.indexWhere((m) => m.id == msg.id);
    if (removedIdx == -1) return;

    setState(() {
      _messages.removeAt(removedIdx);
    });

    try {
      await _repo.deleteMessage(_conversationId!, msg.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.insert(removedIdx.clamp(0, _messages.length), msg);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.urgent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.insert(removedIdx.clamp(0, _messages.length), msg);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus pesan.'),
          backgroundColor: AppColors.urgent,
        ),
      );
    }
  }

  void _openListingDetail() {
    final targetId = _listingId ?? _conversation?.listing.id;
    if (targetId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ListingDetailScreen(
          listingId: targetId,
          initialItem: _listingDetail,
        ),
      ),
    );
  }

  Future<void> _handleLanjutWhatsApp() async {
    if (_conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mulai percakapan terlebih dahulu untuk melanjutkan via WhatsApp.',
          ),
        ),
      );
      return;
    }

    try {
      final waUrl = await _repo.getWhatsAppUrl(_conversationId!);
      if (waUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Penjual tidak mengizinkan WhatsApp.'),
            backgroundColor: AppColors.urgent,
          ),
        );
        return;
      }

      final uri = Uri.parse(waUrl);
      final launcher = widget.urlLauncher ??
          (u) => launchUrl(u, mode: LaunchMode.externalApplication);
      final launched = await launcher(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal membuka WhatsApp. Pastikan aplikasi WhatsApp terpasang.',
            ),
            backgroundColor: AppColors.urgent,
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.urgent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka WhatsApp.'),
          backgroundColor: AppColors.urgent,
        ),
      );
    }
  }

  void _handleReportUser() {
    final otherId = _conversation?.lawan.id ?? _listingDetail?.seller?.id;
    if (otherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat menentukan pengguna yang dilaporkan.'),
          backgroundColor: AppColors.urgent,
        ),
      );
      return;
    }
    final otherName =
        _conversation?.lawan.nama ?? _listingDetail?.seller?.nama ?? 'Pengguna';

    showReportBottomSheet(
      context,
      targetType: 'user',
      targetId: otherId,
      targetTitle: otherName,
      repository: widget.moderationRepository,
    );
  }

  Future<void> _handleBlockUser() async {
    final otherId = _conversation?.lawan.id ?? _listingDetail?.seller?.id;
    if (otherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat menentukan pengguna yang akan diblokir.'),
          backgroundColor: AppColors.urgent,
        ),
      );
      return;
    }
    final otherName =
        _conversation?.lawan.nama ?? _listingDetail?.seller?.nama ?? 'Pengguna';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Blokir $otherName?', style: AppTextStyles.titleMedium),
        content: Text(
          'Kamu tidak akan dapat mengirim atau menerima pesan dari pengguna ini.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style:
                  AppTextStyles.label.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Blokir',
              style: AppTextStyles.label.copyWith(color: AppColors.urgent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final client = AuthScope.of(context).repository.client;
    final modRepo =
        widget.moderationRepository ?? ModerationRepository(client);

    try {
      await modRepo.blockUser(otherId);
      if (!mounted) return;
      setState(() {
        _isBlocked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$otherName telah diblokir.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.urgent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memblokir pengguna.'),
          backgroundColor: AppColors.urgent,
        ),
      );
    }
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) return 'Hari ini';
    if (msgDate == today.subtract(const Duration(days: 1))) return 'Kemarin';

    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatPrice(int harga) {
    final str = harga.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp $buffer';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthScope.of(context).user?.id ?? 0;
    final otherName = _conversation?.lawan.nama ??
        _listingDetail?.seller?.nama ??
        'Penjual';
    final otherUsername = _conversation?.lawan.username ??
        _listingDetail?.seller?.username;

    final eventTitle = _conversation?.listing.judul ??
        _listingDetail?.event.nama ??
        'Tiket Acara';

    String? poster = _conversation?.listing.fullPosterUrl;
    if (poster == null && _listingDetail != null) {
      final pUrl = _listingDetail!.event.posterUrl ??
          (_listingDetail!.photos.isNotEmpty
              ? _listingDetail!.photos.first.url
              : null);
      if (pUrl != null && pUrl.isNotEmpty) {
        poster = pUrl.startsWith('http://') || pUrl.startsWith('https://')
            ? pUrl
            : '${ApiConfig.hostUrl}$pUrl';
      }
    }

    final price = _conversation?.listing.harga ?? _listingDetail?.harga ?? 0;
    final status =
        _conversation?.listing.status ?? _listingDetail?.status ?? 'tersedia';

    final isPhysical = _listingDetail?.tipe == 'fisik';
    final quickReplies = [
      'Halo, masih tersedia?',
      'Boleh nego?',
      if (isPhysical) 'Bisa COD?',
    ];

    final canWa = (_conversation?.izinkanWa ?? _listingDetail?.izinkanWa ?? false) &&
        (_conversation?.isBuyer ?? true);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              otherName,
              style: AppTextStyles.titleMedium,
            ),
            if (otherUsername != null && otherUsername.isNotEmpty)
              Text(
                '@$otherUsername',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textPrimary),
            color: AppColors.surfaceHigh,
            onSelected: (val) {
              if (val == 'wa') {
                _handleLanjutWhatsApp();
              } else if (val == 'report') {
                _handleReportUser();
              } else if (val == 'block') {
                _handleBlockUser();
              }
            },
            itemBuilder: (ctx) => [
              if (canWa)
                const PopupMenuItem(
                  value: 'wa',
                  child: Text('Lanjut via WhatsApp'),
                ),
              const PopupMenuItem(
                value: 'report',
                child: Text('Laporkan'),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Text('Blokir pengguna'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ChatListingCard ringkas di bawah AppBar
            ChatListingCard(
              eventName: eventTitle,
              priceLabel: _formatPrice(price),
              status: status == 'tersedia'
                  ? 'Tersedia'
                  : status == 'terjual'
                      ? 'Terjual'
                      : 'Kedaluwarsa',
              posterUrl: poster,
              onTap: _openListingDetail,
            ),
            const Divider(height: 1, color: AppColors.divider),

            // Daftar Pesan
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AppColors.urgent, size: 48),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                ElevatedButton(
                                  onPressed: _initChat,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.onPrimary,
                                  ),
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _messages.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 48,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      'Mulai percakapan dengan $otherName',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    QuickReplyChips(
                                      suggestions: quickReplies,
                                      onTap: (s) => _sendMessage(s),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              itemCount: _messages.length +
                                  (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _messages.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(AppSpacing.md),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final msg = _messages[index];
                                final isSelf = msg.senderId == currentUserId;

                                // Hitung apakah perlu menampilkan separator tanggal
                                bool showDateSep = false;
                                if (index == _messages.length - 1) {
                                  showDateSep = true;
                                } else {
                                  final prevDate =
                                      _messages[index + 1].createdAt;
                                  if (msg.createdAt.year != prevDate.year ||
                                      msg.createdAt.month != prevDate.month ||
                                      msg.createdAt.day != prevDate.day) {
                                    showDateSep = true;
                                  }
                                }

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (showDateSep)
                                      DateSeparator(
                                        label: _formatDateHeader(msg.createdAt),
                                      ),
                                    ChatBubble(
                                      message: msg.isi,
                                      isSelf: isSelf,
                                      timeLabel: _formatTime(msg.createdAt),
                                      status: msg.sendStatus,
                                      onRetry: msg.sendStatus ==
                                              MessageSendStatus.failed
                                          ? () => _retryMessage(msg)
                                          : null,
                                      onLongPress: () =>
                                          _showMessageActions(msg, isSelf),
                                    ),
                                  ],
                                );
                              },
                            ),
            ),

            // Bar Input Chat
            ChatInput(
              onSend: _sendMessage,
              isBlocked: _isBlocked,
            ),
          ],
        ),
      ),
    );
  }
}
