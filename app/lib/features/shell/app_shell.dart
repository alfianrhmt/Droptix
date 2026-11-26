import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/location/location_controller.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../chat/chat_inbox_screen.dart';
import '../chat/chat_repository.dart';
import '../chat/chat_socket_service.dart';
import '../home/home_screen.dart';
import '../location/location_picker_sheet.dart';
import '../notifications/notification_repository.dart';
import '../profile/profile_screen.dart';
import '../saved/saved_screen.dart';
import '../sell/sell_tab_screen.dart';

/// Kerangka navigasi utama 5 tab: Home, Saved, Sell, Chat, Profile.
/// Tab Saved, Sell, dan Chat menerapkan alur "login saat aksi" untuk tamu.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.socketService,
    this.chatRepository,
  });

  final ChatSocketService? socketService;
  final ChatRepository? chatRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tabIndex = 0;
  bool _promptedLocation = false;
  late final ChatSocketService _socketService;
  late final bool _ownsSocketService;
  ChatRepository? _chatRepo;
  NotificationRepository? _notificationRepo;
  bool _lastLoggedIn = false;

  @override
  void initState() {
    super.initState();
    if (widget.socketService != null) {
      _socketService = widget.socketService!;
      _ownsSocketService = false;
    } else {
      _socketService = ChatSocketService();
      _ownsSocketService = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = AuthScope.of(context);
    final client = auth.repository.client;
    _chatRepo ??= widget.chatRepository ?? ChatRepository(client);
    _notificationRepo ??= NotificationRepository(client);

    if (auth.isLoggedIn != _lastLoggedIn) {
      _lastLoggedIn = auth.isLoggedIn;
      if (auth.isLoggedIn) {
        _socketService.connect();
        _chatRepo!.getUnreadChatsCount().then((count) {
          if (mounted) _socketService.setUnreadCount(count);
        }).catchError((_) {});
        _notificationRepo!.getUnreadCount().then((count) {
          if (mounted) _socketService.setUnreadNotificationsCount(count);
        }).catchError((_) {});
      } else {
        _socketService.disconnect();
      }
    }
  }

  @override
  void dispose() {
    if (_ownsSocketService) {
      _socketService.dispose();
    }
    super.dispose();
  }

  void _maybePromptLocation(LocationController? location) {
    if (_promptedLocation || location == null) return;
    if (location.isRestoring || location.hasChosen) return;
    _promptedLocation = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showLocationPickerSheet(context, isInitialPrompt: true);
    });
  }

  void _onTabTap(int index) {
    if (index == 1 || index == 2 || index == 3) {
      AuthScope.of(context).requireAuthAction(context, () {
        setState(() => _tabIndex = index);
      });
      return;
    }
    setState(() => _tabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final location = LocationScope.maybeOf(context);

    if (auth.isRestoring || (location != null && location.isRestoring)) {
      return const AppBackground(
        child: Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    _maybePromptLocation(location);

    Widget body;
    switch (_tabIndex) {
      case 1:
        body = SavedScreen(
          onNavigateToHome: () => setState(() => _tabIndex = 0),
        );
        break;
      case 2:
        body = const SellTabScreen();
        break;
      case 3:
        body = ChatInboxScreen(
          chatRepository: _chatRepo,
          socketService: _socketService,
        );
        break;
      case 4:
        body = const ProfileScreen();
        break;
      default:
        body = HomeScreen(
          onNavigateToTab: _onTabTap,
          socketService: _socketService,
          notificationRepository: _notificationRepo,
        );
        break;
    }

    return AppBackground(
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: body,
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: _socketService.unreadCountNotifier,
          builder: (context, unreadCount, _) {
            return DroptixBottomNav(
              currentIndex: _tabIndex,
              onTap: _onTabTap,
              unreadCount: unreadCount,
            );
          },
        ),
      ),
    );
  }
}

