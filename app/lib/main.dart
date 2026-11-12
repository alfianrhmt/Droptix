import 'package:flutter/material.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/token_storage.dart';
import 'core/location/location_controller.dart';
import 'core/network/api_client.dart';
import 'core/theme/theme.dart';
import 'core/widgets/widgets.dart';
import 'features/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DroptixApp());
}

class DroptixApp extends StatefulWidget {
  const DroptixApp({
    super.key,
    this.authController,
    this.locationController,
  });

  final AuthController? authController;
  final LocationController? locationController;

  @override
  State<DroptixApp> createState() => _DroptixAppState();
}

class _DroptixAppState extends State<DroptixApp> {
  late final AuthController _auth;
  late final bool _ownsAuth;
  late final LocationController _location;
  late final bool _ownsLocation;

  @override
  void initState() {
    super.initState();
    if (widget.authController != null) {
      _auth = widget.authController!;
      _ownsAuth = false;
    } else {
      _ownsAuth = true;
      final tokenStorage = TokenStorage();
      late final AuthController controller;
      final apiClient = ApiClient(
        tokenStorage: tokenStorage,
        onUnauthorized: (_) => controller.handleForcedLogout(),
      );
      controller = AuthController(
        repository: AuthRepository(apiClient),
        tokenStorage: tokenStorage,
      );
      _auth = controller;
      _auth.restoreSession();
    }

    if (widget.locationController != null) {
      _location = widget.locationController!;
      _ownsLocation = false;
    } else {
      _ownsLocation = true;
      _location = LocationController()..restore();
    }
  }

  @override
  void dispose() {
    if (_ownsAuth) {
      _auth.dispose();
    }
    if (_ownsLocation) {
      _location.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _auth,
      child: LocationScope(
        controller: _location,
        child: CountdownTimerProvider(
          child: MaterialApp(
            title: 'Droptix',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: const AppShell(),
          ),
        ),
      ),
    );
  }
}
