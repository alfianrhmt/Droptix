import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'chat_models.dart';
import 'chat_repository.dart';
import 'chat_screen.dart';
import 'chat_socket_service.dart';

/// Halaman khusus Inbox Chat percakapan pembeli & penjual.
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({
    super.key,
    this.chatRepository,
    this.socketService,
  });

  final ChatRepository? chatRepository;
  final ChatSocketService? socketService;

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  late ChatRepository _chatRepo;
  ChatSocketService? _socketService;
  bool _repoInitialized = false;

  List<ConversationModel> _conversations = [];
  bool _loading = false;
  String? _errorMessage;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _socketSub;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInitialized) {
      final auth = AuthScope.of(context);
      _chatRepo =
          widget.chatRepository ?? ChatRepository(auth.repository.client);
      _socketService = widget.socketService;
      _repoInitialized = true;
      _startPolling();
      _listenToSocket();
      _fetchConversations();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _socketSub?.cancel();
    _pollingTimer?.cancel();
    _socketService?.unreadCountNotifier.removeListener(_onUnreadUpdate);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _page++;
      _loadingMore = true;
      _fetchConversations();
    }
  }

  void _listenToSocket() {
    if (_socketService == null) return;
    _socketSub?.cancel();
    _socketSub = _socketService!.onNewMessage.listen((_) {
      if (mounted) {
        _fetchConversations(isRefresh: true, isSilent: true);
      }
    });
    _socketService!.unreadCountNotifier.addListener(_onUnreadUpdate);
  }

  void _onUnreadUpdate() {
    if (mounted) {
      _fetchConversations(isRefresh: true, isSilent: true);
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _fetchConversations(isRefresh: true, isSilent: true);
      }
    });
  }

  Future<void> _fetchConversations({
    bool isRefresh = false,
    bool isSilent = false,
  }) async {
    if (isRefresh) {
      _page = 1;
      _hasMore = true;
    }
    if (!isSilent) {
      setState(() {
        _loading = _page == 1 && !isRefresh;
        _errorMessage = null;
      });
    }

    try {
      final res = await _chatRepo.getConversations(
        page: _page,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          if (isRefresh || _page == 1) {
            _conversations = res;
          } else {
            _conversations.addAll(res);
          }
          _hasMore = res.length >= 20;
          _loading = false;
          _loadingMore = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (!isSilent || _conversations.isEmpty) {
          setState(() {
            _errorMessage = e.message;
            _loading = false;
            _loadingMore = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        if (!isSilent || _conversations.isEmpty) {
          setState(() {
            _errorMessage = 'Gagal memuat percakapan. Coba lagi.';
            _loading = false;
            _loadingMore = false;
          });
        }
      }
    }
  }

  Future<void> _openChat(ConversationModel conv) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conv.id,
          chatRepository: _chatRepo,
          socketService: _socketService,
        ),
      ),
    );
    _fetchConversations(isRefresh: true, isSilent: true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.lg,
              AppSpacing.screenH,
              AppSpacing.md,
            ),
            child: Text('Chat', style: AppTextStyles.titleLarge),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.urgent),
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Coba Lagi',
                onPressed: () => _fetchConversations(isRefresh: true),
              ),
            ],
          ),
        ),
      );
    }

    if (_conversations.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          message:
              'Mulai percakapan dengan penjual atau pembeli melalui tombol Chat pada halaman detail tiket.',
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => _fetchConversations(isRefresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _conversations.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(
          color: AppColors.divider,
          height: 1,
        ),
        itemBuilder: (ctx, index) {
          if (index == _conversations.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          }
          final conv = _conversations[index];
          return ConversationRow(
            key: Key('chat_conversation_${conv.id}'),
            conversation: conv.toConversationData(),
            onTap: () => _openChat(conv),
          );
        },
      ),
    );
  }
}
