import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../../core/widgets/track_tile.dart';
import '../../../services/native_audio_service.dart';
import '../../player/controllers/player_state.dart';

/// In-memory node representation for hierarchical directory trees
class FolderNode {
  final String path;
  final String name;
  final Map<String, FolderNode> subfolders;
  final List<AudioTrack> tracks;

  FolderNode({
    required this.path,
    required this.name,
    Map<String, FolderNode>? subfolders,
    List<AudioTrack>? tracks,
  })  : subfolders = subfolders ?? {},
        tracks = tracks ?? [];

  int get totalTracksCount {
    int count = tracks.length;
    for (final sub in subfolders.values) {
      count += sub.totalTracksCount;
    }
    return count;
  }

  List<AudioTrack> getAllTracksRecursively() {
    final list = <AudioTrack>[...tracks];
    for (final sub in subfolders.values) {
      list.addAll(sub.getAllTracksRecursively());
    }
    return list;
  }

  static FolderNode buildTree(List<AudioTrack> tracks) {
    final root = FolderNode(path: '/', name: 'ROOT');
    for (final track in tracks) {
      final p = track.path;
      final segments = p.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) continue;

      // Drop filename segment to obtain folder segments
      final folderSegments = segments.sublist(0, segments.length - 1);
      FolderNode current = root;
      String currentPath = '';

      for (final seg in folderSegments) {
        currentPath += '/$seg';
        current = current.subfolders.putIfAbsent(
          seg,
          () => FolderNode(path: currentPath, name: seg),
        );
      }
      current.tracks.add(track);
    }
    return root;
  }

  static FolderNode findSmartRoot(FolderNode root) {
    FolderNode cur = root;
    while (cur.tracks.isEmpty && cur.subfolders.length == 1) {
      cur = cur.subfolders.values.first;
    }
    return cur;
  }

  FolderNode? findByPath(String targetPath) {
    if (path == targetPath) return this;
    for (final sub in subfolders.values) {
      final res = sub.findByPath(targetPath);
      if (res != null) return res;
    }
    return null;
  }
}

/// Hierarchical Directory Tree View with Monospace Breadcrumbs & Instant Actions
class FolderTreeView extends StatefulWidget {
  final PlayerState playerState;
  final List<AudioTrack>? filteredTracks;
  final VoidCallback? onTriggerRescan;

  const FolderTreeView({
    super.key,
    required this.playerState,
    this.filteredTracks,
    this.onTriggerRescan,
  });

  @override
  State<FolderTreeView> createState() => _FolderTreeViewState();
}

class _FolderTreeViewState extends State<FolderTreeView> {
  PlayerState get _state => widget.playerState;

  FolderNode? _treeRoot;
  FolderNode? _smartRoot;
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    _rebuildTree();
  }

  @override
  void didUpdateWidget(covariant FolderTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerState.tracks.length != widget.playerState.tracks.length ||
        oldWidget.filteredTracks?.length != widget.filteredTracks?.length) {
      _rebuildTree();
    }
  }

  void _rebuildTree() {
    final tracks = widget.filteredTracks ?? _state.tracks;
    if (tracks.isEmpty) {
      _treeRoot = null;
      _smartRoot = null;
      _currentPath = '';
      return;
    }

    _treeRoot = FolderNode.buildTree(tracks);
    _smartRoot = FolderNode.findSmartRoot(_treeRoot!);

    // Retain path if still valid in tree, otherwise reset to smart root
    if (_currentPath.isEmpty || _treeRoot?.findByPath(_currentPath) == null) {
      _currentPath = _smartRoot!.path;
    }
  }

  void _navigateTo(String path) {
    setState(() {
      _currentPath = path;
    });
  }

  void _navigateUp(FolderNode currentNode) {
    if (_smartRoot != null && currentNode.path == _smartRoot!.path) {
      return;
    }
    final lastSlash = currentNode.path.lastIndexOf('/');
    if (lastSlash > 0) {
      final parentPath = currentNode.path.substring(0, lastSlash);
      _navigateTo(parentPath);
    } else {
      _navigateTo('/');
    }
  }

  void _showExcludeDialog(BuildContext context, String folderPath, String folderName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.of(context).surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPanel),
          side: BorderSide(color: AppColors.of(context).borderStrong),
        ),
        title: Row(
          children: [
            Icon(Icons.folder_off, color: AppColors.of(context).hazardOrange, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'KELUARKAN FOLDER',
                style: AppTypography.header.copyWith(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Folder "$folderName" akan dikeluarkan dari library musik.',
              style: AppTypography.body,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Path: $folderPath',
              style: AppTypography.codeSnippet.copyWith(fontSize: 11, color: AppColors.of(context).textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Trek di dalam folder ini akan langsung dihapus dari antrean dan cache tanpa pemindaian ulang. Anda dapat memulihkannya nanti di Konsol Sistem.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.of(context).textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('BATAL', style: AppTypography.bodySmall.copyWith(color: AppColors.of(context).textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).hazardOrange,
              foregroundColor: AppColors.of(context).bg,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _state.excludeFolder(folderPath);
              _rebuildTree();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Folder $folderName berhasil dikeluarkan dari library.'),
                  backgroundColor: AppColors.of(context).surface,
                ),
              );
            },
            child: const Text('KELUARKAN FOLDER'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_state.tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: AppColors.of(context).textMuted),
            const SizedBox(height: AppSpacing.md),
            Text('Library kosong. Mulai pemindaian penyimpanan.', style: AppTypography.body),
            const SizedBox(height: AppSpacing.md),
            TactileButton(
              label: 'PINDAI PENYIMPANAN',
              icon: Icons.search,
              onPressed: () => _state.scanStorage(),
            ),
          ],
        ),
      );
    }

    if (_treeRoot == null) {
      _rebuildTree();
    }

    final currentNode = _treeRoot?.findByPath(_currentPath) ?? _smartRoot ?? _treeRoot;
    if (currentNode == null) {
      return const SizedBox.shrink();
    }

    final isAtRoot = _smartRoot != null && currentNode.path == _smartRoot!.path;
    final subfolders = currentNode.subfolders.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final tracks = currentNode.tracks
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    // Construct breadcrumb path segments
    final relativePath = _smartRoot != null && currentNode.path.startsWith(_smartRoot!.path)
        ? currentNode.path.substring(_smartRoot!.path.length)
        : currentNode.path;
    final breadcrumbSegments = relativePath.split('/').where((s) => s.isNotEmpty).toList();

    return Column(
      children: [
        // 1. Monospace Breadcrumb Navigation Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.of(context).surfaceInset,
            border: Border(bottom: BorderSide(color: AppColors.of(context).border, width: 1.0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                InkWell(
                  onTap: () => _navigateTo(_smartRoot?.path ?? '/'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Text(
                      _smartRoot?.name.toUpperCase() ?? 'ROOT',
                      style: AppTypography.statusPill.copyWith(
                        color: isAtRoot ? AppColors.of(context).acidGreen : AppColors.of(context).evaPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                for (int i = 0; i < breadcrumbSegments.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('//', style: TextStyle(color: AppColors.of(context).textMuted, fontSize: 11)),
                  ),
                  Builder(builder: (context) {
                    final segmentName = breadcrumbSegments[i];
                    final isLast = i == breadcrumbSegments.length - 1;
                    // Reconstruct path up to this segment
                    final segmentSubpath = _smartRoot!.path +
                        '/' +
                        breadcrumbSegments.sublist(0, i + 1).join('/');

                    return InkWell(
                      onTap: isLast ? null : () => _navigateTo(segmentSubpath),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Text(
                          segmentName.toUpperCase(),
                          style: AppTypography.statusPill.copyWith(
                            color: isLast ? AppColors.of(context).acidGreen : AppColors.of(context).evaPurple,
                            fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),

        // 2. Action Deck (Folder Telemetry & PLAY FOLDER Button)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            border: Border(bottom: BorderSide(color: AppColors.of(context).border, width: 1.0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${subfolders.length} FOLDER // ${currentNode.totalTracksCount} TREK',
                  style: AppTypography.codeSnippet.copyWith(
                    color: AppColors.of(context).textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              TactileButton(
                label: 'PUTAR FOLDER',
                icon: Icons.play_arrow,
                height: 34,
                onPressed: () {
                  final allFolderTracks = currentNode.getAllTracksRecursively();
                  if (allFolderTracks.isNotEmpty) {
                    _state.setQueue(allFolderTracks);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Memutar folder: ${currentNode.name} (${allFolderTracks.length} trek)'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppColors.of(context).surface,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),

        // 3. Hierarchical Directory List
        Expanded(
          child: ListView.separated(
            itemCount: (isAtRoot ? 0 : 1) + subfolders.length + tracks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              // Row 0: Parent Navigation '..' if not at root
              if (!isAtRoot && index == 0) {
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.of(context).surfaceInset,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: AppColors.of(context).border),
                    ),
                    child: Icon(Icons.arrow_upward, color: AppColors.of(context).acidGreen, size: 20),
                  ),
                  title: Text(
                    '.. [ DIREKTORI SEBELUMNYA ]',
                    style: AppTypography.statusPill.copyWith(
                      color: AppColors.of(context).acidGreen,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => _navigateUp(currentNode),
                );
              }

              final adjustedIndex = isAtRoot ? index : index - 1;

              // Subfolder Items
              if (adjustedIndex < subfolders.length) {
                final sub = subfolders[adjustedIndex];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.of(context).surfaceInset,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: AppColors.of(context).border),
                    ),
                    child: Icon(Icons.folder, color: AppColors.of(context).evaPurple, size: 22),
                  ),
                  title: Text(
                    sub.name,
                    style: AppTypography.trackTitle.copyWith(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${sub.subfolders.length} subfolder • ${sub.totalTracksCount} trek',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.play_circle_outline, color: AppColors.of(context).acidGreen, size: 24),
                        tooltip: 'Putar folder ini',
                        onPressed: () {
                          final fTracks = sub.getAllTracksRecursively();
                          if (fTracks.isNotEmpty) {
                            _state.setQueue(fTracks, startIndex: 0);
                          }
                        },
                      ),
                      Icon(Icons.chevron_right, color: AppColors.of(context).textMuted, size: 18),
                    ],
                  ),
                  onTap: () => _navigateTo(sub.path),
                  onLongPress: () => _showExcludeDialog(context, sub.path, sub.name),
                );
              }

              // Direct Track Items
              final trackIndex = adjustedIndex - subfolders.length;
              final track = tracks[trackIndex];
              final isSelected = _state.selectedTrack?.path == track.path;

              return TrackTile(
                track: track,
                isSelected: isSelected,
                onTap: () {
                  _state.setQueue(tracks, startIndex: trackIndex);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
