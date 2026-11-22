import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/hardware_panel.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/tactile_button.dart';
import 'controllers/peq_state.dart';
import 'models/peq_band.dart';
import 'widgets/peq_graph_widget.dart';

/// Full Interactive Parametric EQ Modal Sheet (Lean 3+3 Step 4)
class PeqEditorSheet extends StatefulWidget {
  final PeqState peqState;

  const PeqEditorSheet({
    super.key,
    required this.peqState,
  });

  static Future<void> show(BuildContext context, PeqState peqState) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusPanel)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: PeqEditorSheet(peqState: peqState),
      ),
    );
  }

  @override
  State<PeqEditorSheet> createState() => _PeqEditorSheetState();
}

class _PeqEditorSheetState extends State<PeqEditorSheet> {
  PeqState get _state => widget.peqState;
  final TextEditingController _importController = TextEditingController();

  void _showAutoEqImportDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('IMPORT AUTOEQ / SQUIGLINK', style: AppTypography.header.copyWith(fontSize: 14)),
          content: TextField(
            controller: _importController,
            maxLines: 8,
            style: AppTypography.telemetrySmall.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Tempel profil .txt EqualizerAPO / AutoEq di sini...\nContoh:\nPreamp: -4.5 dB\nFilter 1: ON PK Fc 62 Hz Gain -1.5 dB Q 1.41',
              hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceInset,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.evaPurple,
                foregroundColor: AppColors.textPrimary,
              ),
              onPressed: () {
                final success = _state.parseAutoEq(_importController.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Profil AutoEq berhasil diterapkan!' : 'Gagal membaca format AutoEq.'),
                    backgroundColor: success ? AppColors.acidGreenDim : AppColors.errorRed,
                  ),
                );
              },
              child: const Text('Terapkan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final selectedBand = _state.selectedBand;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
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
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, color: AppColors.evaPurple, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'PARAMETRIC EQ',
                          style: AppTypography.header.copyWith(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusPill(
                        label: _state.isEnabled ? 'DSP ON' : 'BYPASS',
                        type: _state.isEnabled ? StatusPillType.dspActive : StatusPillType.bitPerfect,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Switch(
                        value: _state.isEnabled,
                        activeColor: AppColors.acidGreen,
                        activeTrackColor: AppColors.acidGreenDim,
                        inactiveThumbColor: AppColors.textMuted,
                        inactiveTrackColor: AppColors.surfaceInset,
                        onChanged: (val) => _state.setEnabled(val),
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
                      // 1. Live Interactive Curve Graph
                      PeqGraphWidget(peqState: _state),
                      const SizedBox(height: AppSpacing.md),

                      // 2. Pre-Amp Control Panel
                      HardwarePanel(
                        inset: true,
                        padding: AppSpacing.edgeSm,
                        child: Row(
                          children: [
                            Text(
                              'PRE-AMP: ${_state.preAmpDb.toStringAsFixed(1)} dB',
                              style: AppTypography.telemetrySmall.copyWith(
                                color: _state.preAmpDb < 0 ? AppColors.hazardOrange : AppColors.textPrimary,
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.evaPurple,
                                  thumbColor: AppColors.evaPurple,
                                  trackHeight: 2,
                                ),
                                child: Slider(
                                  value: _state.preAmpDb,
                                  min: -12.0,
                                  max: 12.0,
                                  onChanged: _state.isEnabled ? (v) => _state.setPreAmp(v) : null,
                                ),
                              ),
                            ),
                            TactileButton(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              label: 'AUTO',
                              onPressed: _state.isEnabled ? _state.autoPreamp : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 3. Band Selector Chips (1 to 10)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_state.bands.length, (idx) {
                            final b = _state.bands[idx];
                            final isSel = idx == _state.selectedBandIndex;

                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  'B${idx + 1}',
                                  style: AppTypography.telemetrySmall.copyWith(
                                    color: isSel ? AppColors.textPrimary : AppColors.textSecondary,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSel,
                                selectedColor: AppColors.evaPurple,
                                backgroundColor: AppColors.surfaceInset,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(
                                    color: isSel ? AppColors.evaPurple : AppColors.border,
                                  ),
                                ),
                                onSelected: (_) => _state.selectBand(idx),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 4. Active Band Parameters Hardware Panel
                      HardwarePanel(
                        padding: AppSpacing.edgeMd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'BAND ${_state.selectedBandIndex + 1} // ${selectedBand.type.shortCode}',
                                  style: AppTypography.header.copyWith(fontSize: 13),
                                ),
                                Switch(
                                  value: selectedBand.enabled,
                                  activeColor: AppColors.evaPurple,
                                  onChanged: _state.isEnabled
                                      ? (v) => _state.updateSelectedBand(enabled: v)
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Filter Type Dropdown
                            DropdownButtonFormField<PeqFilterType>(
                              value: selectedBand.type,
                              dropdownColor: AppColors.surface,
                              style: AppTypography.bodySmall,
                              decoration: InputDecoration(
                                labelText: 'Filter Topology',
                                labelStyle: AppTypography.telemetrySmall.copyWith(color: AppColors.textMuted),
                                filled: true,
                                fillColor: AppColors.surfaceInset,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: PeqFilterType.values.map((t) {
                                return DropdownMenuItem(value: t, child: Text(t.label));
                              }).toList(),
                              onChanged: _state.isEnabled
                                  ? (t) => _state.updateSelectedBand(type: t)
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Fc Slider
                            _buildSliderRow(
                              'Frequency (${_state.selectedBand.fc.toInt()} Hz)',
                              selectedBand.fc,
                              20.0,
                              20000.0,
                              (v) => _state.updateSelectedBand(fc: v),
                            ),

                            // Gain Slider
                            _buildSliderRow(
                              'Gain (${_state.selectedBand.gainDb.toStringAsFixed(1)} dB)',
                              selectedBand.gainDb,
                              -12.0,
                              12.0,
                              (v) => _state.updateSelectedBand(gainDb: v),
                            ),

                            // Q Factor Slider
                            _buildSliderRow(
                              'Q Factor (${_state.selectedBand.q.toStringAsFixed(2)})',
                              selectedBand.q,
                              0.1,
                              10.0,
                              (v) => _state.updateSelectedBand(q: v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // 5. AutoEq Importer Button
                      TactileButton(
                        height: 44,
                        icon: Icons.file_upload_outlined,
                        label: 'IMPORT AUTOEQ / SQUIGLINK (.TXT)',
                        onPressed: _showAutoEqImportDialog,
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

  Widget _buildSliderRow(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.telemetrySmall.copyWith(color: AppColors.textSecondary)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            activeTrackColor: AppColors.acidGreen,
            thumbColor: AppColors.acidGreen,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: _state.isEnabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
