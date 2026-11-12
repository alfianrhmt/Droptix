import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/location/location_controller.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../gallery/component_gallery_screen.dart';
import '../location/location_picker_sheet.dart';
import '../profile/profile_screen.dart';

/// Kerangka navigasi utama 4 tab: Home, Activity, Sell, Profile.
/// Tab Activity dan Sell menerapkan alur "login saat aksi" untuk tamu.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tabIndex = 0;
  bool _promptedLocation = false;

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
    if (index == 1 || index == 2) {
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
        body = const SafeArea(
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'Activity akan hadir di milestone berikutnya.',
          ),
        );
        break;
      case 2:
        body = const SafeArea(
          child: EmptyState(
            icon: Icons.sell_outlined,
            message: 'Form jual tiket akan hadir di M3.',
          ),
        );
        break;
      case 3:
        body = const ProfileScreen();
        break;
      default:
        body = const ComponentGalleryScreen(embedded: true);
        break;
    }

    return AppBackground(
      child: Scaffold(
        body: body,
        bottomNavigationBar: DroptixBottomNav(
          currentIndex: _tabIndex,
          onTap: _onTabTap,
        ),
      ),
    );
  }
}

