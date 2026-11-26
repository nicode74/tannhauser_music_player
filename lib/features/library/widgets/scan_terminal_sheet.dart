import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../player/controllers/player_state.dart';

class ScanTerminalSheet extends StatefulWidget {
  final PlayerState playerState;

  const ScanTerminalSheet({
    super.key,
    required this.playerState,
  });

  static Future<void> show(BuildContext context, PlayerState playerState) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: !playerState.isScanning,
      enableDrag: !playerState.isScanning,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusPanel)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: ScanTerminalSheet(playerState: playerState),
      ),
    );
  }

  @override
  State<ScanTerminalSheet> createState() => _ScanTerminalSheetState();
}

class _ScanTerminalSheetState extends State<ScanTerminalSheet> {
  PlayerState get _playerState => widget.playerState;

  List<Map<String, dynamic>> _roots = [];
  List<Map<String, dynamic>> _currentEntries = [];
  String? _currentBrowsePath;
  final List<String> _pathHistory = [];
  bool _isLoadingDirs = true;

  @override
  void initState() {
    super.initState();
    _loadRoots();
  }

  Future<void> _loadRoots() async {
    setState(() => _isLoadingDirs = true);
    final roots = await _playerState.getStorageRoots();
    if (!mounted) return;
    setState(() {
      _roots = roots;
      _currentBrowsePath = null;
      _pathHistory.clear();
      _currentEntries = roots;
      _isLoadingDirs = false;
    });
  }

  Future<void> _openDirectory(String path, {bool pushHistory = true}) async {
    setState(() => _isLoadingDirs = true);
    if (pushHistory && _currentBrowsePath != null) {
      _pathHistory.add(_currentBrowsePath!);
    } else if (pushHistory && _currentBrowsePath == null) {
      _pathHistory.add('__ROOTS__');
    }
    final subdirs = await _playerState.listSubdirectories(path);
    if (!mounted) return;
    setState(() {
      _currentBrowsePath = path;
      _currentEntries = subdirs;
      _isLoadingDirs = false;
    });
  }

  Future<void> _navigateBack() async {
    if (_pathHistory.isEmpty) {
      await _loadRoots();
      return;
    }
    final prev = _pathHistory.removeLast();
    if (prev == '__ROOTS__') {
      await _loadRoots();
    } else {
      await _openDirectory(prev, pushHistory: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _playerState,
      builder: (context, _) {
        final isScanning = _playerState.isScanning;
        final currentDir = _playerState.scanCurrentDir;
        final count = _playerState.scanCount;
        final selectedPaths = _playerState.selectedScanPaths;

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Header
              Row(
                children: [
                  Icon(
                    isScanning ? Icons.radar : Icons.folder_copy_outlined,
                    color: isScanning ? AppColors.of(context).acidGreen : AppColors.of(context).evaPurple,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isScanning
                          ? 'NERV STORAGE SCANNER // LIVE'
                          : 'PILIH FOLDER PEMINDAIAN',
                      style: AppTypography.header.copyWith(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.of(context).surfaceInset,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isScanning ? AppColors.of(context).acidGreen : AppColors.of(context).evaPurple,
                      ),
                    ),
                    child: Text(
                      isScanning
                          ? 'ACTIVE'
                          : (selectedPaths.isEmpty
                              ? 'ALL ROOTS'
                              : '${selectedPaths.length} FOLDER'),
                      style: AppTypography.statusPill.copyWith(
                        color: isScanning ? AppColors.of(context).acidGreen : AppColors.of(context).evaPurple,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),

              if (isScanning) ...[
                // Monospace Terminal Box (Live Scan Telemetry)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).bg,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.of(context).border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '// PROTOCOL: DIRECT FILESYSTEM TRAVERSAL',
                        style: AppTypography.codeSnippet.copyWith(color: AppColors.of(context).acidGreen, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '// C++ FAST PROBER: AVFORMAT_FIND_STREAM_INFO',
                        style: AppTypography.codeSnippet.copyWith(color: AppColors.of(context).textMuted, fontSize: 10),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'STATUS: MEMINDAI DIREKTORI...',
                        style: AppTypography.codeSnippet.copyWith(
                          color: AppColors.of(context).acidGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'TREK DITEMUKAN: $count',
                        style: AppTypography.codeSnippet.copyWith(
                          color: AppColors.of(context).textPrimary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'PATH SAAT INI:',
                        style: AppTypography.codeSnippet.copyWith(color: AppColors.of(context).textMuted, fontSize: 10),
                      ),
                      Text(
                        currentDir.isNotEmpty ? currentDir : '---',
                        style: AppTypography.codeSnippet.copyWith(
                          color: AppColors.of(context).textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Hiby-style Folder Browser & Checkbox Selection
                Row(
                  children: [
                    if (_currentBrowsePath != null)
                      InkWell(
                        onTap: _navigateBack,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.of(context).surfaceInset,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.of(context).border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back, size: 14, color: AppColors.of(context).acidGreen),
                              const SizedBox(width: 4),
                              Text(
                                'KEMBALI',
                                style: AppTypography.statusPill.copyWith(
                                  color: AppColors.of(context).acidGreen,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_currentBrowsePath != null) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _currentBrowsePath ?? 'ROOT PENYIMPANAN (INTERNAL & SD CARD)',
                        style: AppTypography.codeSnippet.copyWith(
                          color: AppColors.of(context).textSecondary,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selectedPaths.isNotEmpty)
                      TextButton(
                        onPressed: _playerState.clearScanPaths,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'RESET',
                          style: AppTypography.statusPill.copyWith(
                            color: AppColors.of(context).evaPurple,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).bg,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.of(context).border),
                  ),
                  child: _isLoadingDirs
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.of(context).acidGreen,
                            strokeWidth: 2,
                          ),
                        )
                      : _currentEntries.isEmpty
                          ? Center(
                              child: Text(
                                'Tidak ada subfolder di direktori ini.',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.of(context).textMuted),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _currentEntries.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final entry = _currentEntries[index];
                                final name = entry['name'] as String? ?? 'Folder';
                                final path = entry['path'] as String? ?? '';
                                final isRemovable = entry['isRemovable'] as bool? ?? false;
                                final isSelected = selectedPaths.contains(path);

                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    _currentBrowsePath == null
                                        ? (isRemovable ? Icons.sd_card : Icons.phone_android)
                                        : Icons.folder,
                                    color: isSelected
                                        ? AppColors.of(context).acidGreen
                                        : AppColors.of(context).evaPurple,
                                    size: 20,
                                  ),
                                  title: Text(
                                    name,
                                    style: AppTypography.trackTitle.copyWith(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: _currentBrowsePath == null
                                      ? Text(
                                          path,
                                          style: AppTypography.codeSnippet.copyWith(
                                            color: AppColors.of(context).textMuted,
                                            fontSize: 10,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: isSelected,
                                        activeColor: AppColors.of(context).acidGreen,
                                        checkColor: AppColors.of(context).bg,
                                        side: BorderSide(color: AppColors.of(context).borderStrong),
                                        onChanged: (_) => _playerState.toggleScanPath(path),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: AppColors.of(context).textMuted,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                  onTap: () => _openDirectory(path),
                                );
                              },
                            ),
                ),

                if (selectedPaths.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Terpilih: ${selectedPaths.map((p) => p.split('/').last).join(', ')}',
                    style: AppTypography.codeSnippet.copyWith(
                      color: AppColors.of(context).acidGreen,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Centang folder tertentu untuk dipindai, atau klik PINDAI SEMUA.',
                    style: AppTypography.codeSnippet.copyWith(
                      color: AppColors.of(context).textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],

              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              Row(
                children: [
                  if (isScanning)
                    Expanded(
                      child: TactileButton(
                        label: 'BATALKAN',
                        icon: Icons.cancel,
                        onPressed: () {
                          _playerState.stopScan();
                          Navigator.of(context).pop();
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: TactileButton(
                        label: selectedPaths.isNotEmpty
                            ? 'PINDAI TERPILIH (${selectedPaths.length})'
                            : 'PINDAI SEMUA',
                        icon: Icons.radar,
                        isActive: true,
                        ledColor: AppColors.of(context).acidGreen,
                        onPressed: () {
                          _playerState.scanStorage(
                            rescan: true,
                            customPaths: selectedPaths.isNotEmpty ? selectedPaths : null,
                          );
                        },
                      ),
                    ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.of(context).evaPurple,
                        foregroundColor: AppColors.of(context).textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('TUTUP'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
