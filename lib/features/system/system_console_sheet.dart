import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/eva_palette.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/hardware_panel.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/tactile_button.dart';
import '../player/controllers/player_state.dart';
import '../player/widgets/sleep_timer_sheet.dart';
import '../library/widgets/scan_terminal_sheet.dart';

/// Hardware Diagnostics & Audio Engine Console Modal Sheet (Lean 3+3 Step 6)
class SystemConsoleSheet extends StatefulWidget {
  final PlayerState playerState;

  const SystemConsoleSheet({
    super.key,
    required this.playerState,
  });

  static Future<void> show(BuildContext context, PlayerState playerState) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusPanel)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: SystemConsoleSheet(playerState: playerState),
      ),
    );
  }

  @override
  State<SystemConsoleSheet> createState() => _SystemConsoleSheetState();
}

class _SystemConsoleSheetState extends State<SystemConsoleSheet> {
  PlayerState get _state => widget.playerState;
  bool _audioTrackFallbackEnabled = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final isUsb = _state.isUsbConnected;
        final info = _state.playbackInfo;
        final sampleRate = info?.sampleRate ?? 0;
        final bitDepth = info?.bitDepth ?? 0;
        final channels = info?.channels ?? 0;

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Top drag pill
                Container(
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.settings_input_component, color: AppColors.of(context).evaPurple, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'SYSTEM CONSOLE',
                          style: AppTypography.header.copyWith(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusPill(
                        label: isUsb ? 'DAC ACTIVE' : 'NO DAC',
                        type: isUsb ? StatusPillType.bitPerfect : StatusPillType.noDac,
                      ),
                    ],
                  ),
                ),
                const Divider(),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: AppSpacing.screenPadding,
                    children: [
                      // 1. USB DAC Hardware Telemetry
                      HardwarePanel(
                        inset: true,
                        padding: AppSpacing.edgeMd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'USB HARDWARE DIAGNOSTICS',
                              style: AppTypography.telemetrySmall.copyWith(
                                color: AppColors.of(context).textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _buildInfoRow('Perangkat', _state.usbDeviceName),
                            _buildInfoRow('Transport', 'libusb Isochronous Stream'),
                            _buildInfoRow('Protokol', 'USB Audio Class 2.0 (UAC2)'),
                            _buildInfoRow('Android Mixer', 'BYPASS (Zero Mixer Policy)'),
                            _buildInfoRow('Status JNI', isUsb ? 'FD Claimed & Wrapped' : 'Standby / Unplugged'),
                            _buildInfoRow(
                              'Format Aktif',
                              sampleRate > 0
                                  ? '$sampleRate Hz • $bitDepth-bit • $channels ch'
                                  : 'Idle (Tidak ada audio aktif)',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 2. Hardware Actions Panel
                      HardwarePanel(
                        padding: AppSpacing.edgeMd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AKSI HARDWARE & PENYIMPANAN',
                              style: AppTypography.telemetrySmall.copyWith(
                                color: AppColors.of(context).textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: TactileButton(
                                    height: 42,
                                    icon: Icons.usb,
                                    label: 'PINDAI USB DAC',
                                    onPressed: () {
                                      _state.scanUsb();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Memindai ulang perangkat USB...'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: TactileButton(
                                    height: 42,
                                    icon: Icons.radar,
                                    label: 'PINDAI PENYIMPANAN',
                                    onPressed: () {
                                      Navigator.pop(context);
                                      ScanTerminalSheet.show(context, _state);
                                      _state.scanStorage(rescan: true);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TactileButton(
                              height: 42,
                              icon: Icons.snooze,
                              label: _state.isSleepTimerActive
                                  ? 'SLEEP TIMER: ${_state.sleepTimeFormatted}'
                                  : 'ATUR SLEEP TIMER',
                              isActive: _state.isSleepTimerActive,
                              ledColor: AppColors.of(context).acidGreen,
                              onPressed: () {
                                Navigator.pop(context);
                                SleepTimerSheet.show(context, _state);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 3. Terminal Color Palette Selector (EVA-00 .. EVA-13)
                      _buildPaletteSelector(context),
                      const SizedBox(height: AppSpacing.md),

                      // 4. Blacklist / Excluded Folders Panel
                      HardwarePanel(
                        padding: AppSpacing.edgeMd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FOLDER TERKECUALIKAN (${_state.excludedFolders.length})',
                              style: AppTypography.telemetrySmall.copyWith(
                                color: AppColors.of(context).textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            if (_state.excludedFolders.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                child: Text(
                                  'Tidak ada folder yang dikeluarkan dari library. Tekan lama pada folder di tab FOLDERS untuk mengeluarkan folder yang tidak diinginkan.',
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.of(context).textMuted),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _state.excludedFolders.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final folder = _state.excludedFolders[idx];
                                  final folderName = folder.split('/').last;

                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.folder_off, color: AppColors.of(context).hazardOrange, size: 20),
                                    title: Text(
                                      folderName,
                                      style: AppTypography.trackTitle.copyWith(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      folder,
                                      style: AppTypography.codeSnippet.copyWith(fontSize: 10, color: AppColors.of(context).textMuted),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: TextButton.icon(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: AppColors.of(context).acidGreen,
                                      ),
                                      icon: const Icon(Icons.restore, size: 16),
                                      label: const Text('PULIHKAN'),
                                      onPressed: () {
                                        _state.restoreFolder(folder);
                                      },
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 4. Debug & Fallback Settings
                      HardwarePanel(
                        inset: true,
                        padding: AppSpacing.edgeMd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SOFTWARE PREVIEW FALLBACK',
                                        style: AppTypography.telemetrySmall.copyWith(
                                          color: AppColors.of(context).textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Rute PCM ke AudioTrack saat DAC belum dicolok (hanya untuk pengujian UI/seek/PEQ).',
                                        style: AppTypography.bodySmall.copyWith(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _audioTrackFallbackEnabled,
                                  activeColor: AppColors.of(context).evaPurple,
                                  onChanged: (val) {
                                    setState(() {
                                      _audioTrackFallbackEnabled = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPaletteSelector(BuildContext context) {
    final colors = AppColors.of(context);
    final themeController = ThemeScope.maybeOf(context);
    final activeId = themeController?.palette.id ?? colors.id;

    return HardwarePanel(
      padding: AppSpacing.edgeMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'SKEMA WARNA TERMINAL',
                  style: AppTypography.telemetrySmall.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primaryDim.withOpacity(0.45),
                  borderRadius: AppSpacing.borderBadge,
                  border: Border.all(color: colors.primary, width: 0.8),
                ),
                child: Text(
                  colors.unitCode,
                  style: AppTypography.telemetrySmall.copyWith(
                    fontSize: 9.5,
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih profil warna Evangelion Unit (EVA-00 s.d. EVA-13). Perubahan diterapkan seketika.',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 10.5,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: EvaPalette.presets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.35,
            ),
            itemBuilder: (context, idx) {
              final preset = EvaPalette.presets[idx];
              final isSelected = preset.id == activeId;

              return Semantics(
                button: true,
                selected: isSelected,
                label: 'Tema ${preset.name}, ${preset.subtitle}',
                child: InkWell(
                  onTap: () {
                    themeController?.setPalette(preset.id);
                  },
                  borderRadius: AppSpacing.borderButton,
                  splashColor: preset.primaryDim.withOpacity(0.4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? preset.primaryDim.withOpacity(0.32)
                          : colors.surfaceInset,
                      borderRadius: AppSpacing.borderButton,
                      border: Border.all(
                        color: isSelected ? preset.primary : colors.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                preset.unitCode,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.telemetrySmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? preset.primary : colors.textPrimary,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _swatchDot(preset.primary),
                                const SizedBox(width: 3),
                                _swatchDot(preset.secondary),
                                const SizedBox(width: 3),
                                _swatchDot(preset.warning),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          preset.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 9.5,
                            color: isSelected ? colors.textPrimary : colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _swatchDot(Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.of(context).textMuted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.telemetrySmall.copyWith(
                color: AppColors.of(context).textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
