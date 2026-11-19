import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../network/api_config.dart';
import '../theme/theme.dart';

/// Komponen avatar pengguna Droptix yang menampilkan foto profil,
/// inisial nama, atau ikon default secara elegan.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.fotoUrl,
    this.nama,
    this.radius = 28,
    this.showEditBadge = false,
    this.previewBytes,
    this.onTap,
  });

  final String? fotoUrl;
  final String? nama;
  final double radius;
  final bool showEditBadge;
  final Uint8List? previewBytes;
  final VoidCallback? onTap;

  static String? resolveUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '${ApiConfig.hostUrl}$normalized';
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final resolved = resolveUrl(fotoUrl);
    final initials = _getInitials(nama);

    Widget avatarContent;
    if (previewBytes != null) {
      avatarContent = Image.memory(
        previewBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildInitials(initials, size),
      );
    } else if (resolved != null) {
      avatarContent = Image.network(
        resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildInitials(initials, size),
      );
    } else {
      avatarContent = _buildInitials(initials, size);
    }

    final avatarCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withAlpha(80),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarContent,
      ),
    );

    Widget mainWidget;
    if (!showEditBadge) {
      mainWidget = avatarCircle;
    } else {
      final badgeSize = (radius * 0.7).clamp(24.0, 36.0);
      mainWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarCircle,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surface,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: badgeSize * 0.55,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: mainWidget,
      );
    }

    return mainWidget;
  }

  Widget _buildInitials(String initials, double size) {
    if (initials.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFF6C5CE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withAlpha(40),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        color: AppColors.primary,
        size: size * 0.55,
      ),
    );
  }
}
