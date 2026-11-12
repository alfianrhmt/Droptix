import 'package:flutter/material.dart';
import '../../core/location/cities.dart';
import '../../core/location/location_controller.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

/// Membuka bottom sheet pemilih lokasi (GPS atau pilih kota manual).
Future<void> showLocationPickerSheet(
  BuildContext context, {
  bool isInitialPrompt = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => _LocationPickerSheet(isInitialPrompt: isInitialPrompt),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({required this.isInitialPrompt});

  final bool isInitialPrompt;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_query != _searchController.text) {
        setState(() => _query = _searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useGps(LocationController location) async {
    final ok = await location.requestGpsLocation();
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _selectCity(
      LocationController location, CityOption city) async {
    await location.selectManualCity(city);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = LocationScope.of(context);
    final filtered = kIndonesianCities
        .where(
            (c) => c.name.toLowerCase().contains(_query.trim().toLowerCase()))
        .toList();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.isInitialPrompt
                    ? 'Aktifkan lokasi atau pilih kotamu'
                    : 'Pilih lokasi',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Dipakai untuk menampilkan tiket dan acara terdekat di sekitarmu.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Gunakan lokasi saat ini (GPS)',
                icon: Icons.my_location_rounded,
                isLoading: location.isLocating,
                onPressed: () => _useGps(location),
              ),
              if (location.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.urgent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.urgent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.urgent,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          location.errorMessage!,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _searchController,
                label: 'Atau pilih kota manual',
                hintText: 'Cari kota (mis. Jakarta, Surabaya)',
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Text(
                          'Kota tidak ditemukan.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: AppColors.divider,
                        ),
                        itemBuilder: (ctx, i) {
                          final city = filtered[i];
                          final isSelected =
                              !location.isGps && location.city == city.name;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs),
                            leading: Icon(
                              Icons.location_city_rounded,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            title: Text(
                              city.name,
                              style: AppTextStyles.body.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () => _selectCity(location, city),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
