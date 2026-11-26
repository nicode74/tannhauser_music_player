import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/album_artwork.dart';
import '../../core/widgets/hardware_panel.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/track_tile.dart';
import '../../services/native_audio_service.dart';
import '../player/controllers/player_state.dart';
import '../system/system_console_sheet.dart';
import 'collection_detail_page.dart';
import 'widgets/folder_tree_view.dart';
import 'widgets/mini_player_bar.dart';
import 'widgets/scan_terminal_sheet.dart';

/// Default Home Screen: LibraryPage
/// Features instant search, 3 segmented tabs (ALL TRACKS, FOLDERS, ALBUMS),
/// and docked MiniPlayerBar.
class LibraryPage extends StatefulWidget {
  final PlayerState playerState;
  final VoidCallback onOpenNowPlaying;
  final Function(String title, List<AudioTrack> tracks)? onOpenCollection;

  const LibraryPage({
    super.key,
    required this.playerState,
    required this.onOpenNowPlaying,
    this.onOpenCollection,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<AudioTrack> _filterTracks(List<AudioTrack> tracks) {
    if (_searchQuery.isEmpty) return tracks;
    final q = _searchQuery.toLowerCase();
    return tracks.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.playerState.libraryRevision,
      builder: (context, _, __) {
        final allTracks = _filterTracks(widget.playerState.tracks);
        final folders = widget.playerState.tracksByFolder;
        final albums = widget.playerState.tracksByAlbum;

        return Scaffold(
          appBar: AppBar(
            title: _isSearchOpen
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: AppTypography.body,
                    decoration: InputDecoration(
                      hintText: 'Cari judul, artis, atau album...',
                      hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.of(context).textMuted),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                  )
                : Text('TANNHÄUSER // ${AppColors.of(context).unitCode}'),
            actions: [
              IconButton(
                icon: Icon(Icons.radar, size: 20, color: AppColors.of(context).acidGreen),
                tooltip: 'Pindai Penyimpanan',
                onPressed: () {
                  ScanTerminalSheet.show(context, widget.playerState);
                },
              ),
              IconButton(
                icon: Icon(_isSearchOpen ? Icons.close : Icons.search, size: 20),
                tooltip: _isSearchOpen ? 'Tutup Pencarian' : 'Cari Musik',
                onPressed: () {
                  setState(() {
                    _isSearchOpen = !_isSearchOpen;
                    if (!_isSearchOpen) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Center(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: widget.playerState.usbConnectedNotifier,
                    builder: (context, isUsb, _) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => SystemConsoleSheet.show(context, widget.playerState),
                        child: StatusPill(
                          label: isUsb ? 'USB DAC' : 'NO DAC',
                          type: isUsb ? StatusPillType.bitPerfect : StatusPillType.noDac,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.of(context).border, width: 1.0),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.of(context).evaPurple,
                  indicatorWeight: 2.5,
                  labelColor: AppColors.of(context).evaPurple,
                  unselectedLabelColor: AppColors.of(context).textSecondary,
                  labelStyle: AppTypography.statusPill.copyWith(fontSize: 10),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  tabs: [
                    Tab(text: 'TRACKS (${allTracks.length})'),
                    Tab(text: 'FOLDERS (${folders.length})'),
                    Tab(text: 'ALBUMS (${albums.length})'),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // 1. All Tracks
              _buildTracksList(allTracks),

              // 2. Hierarchical Folder Tree
              FolderTreeView(
                playerState: widget.playerState,
                filteredTracks: _isSearchOpen && _searchQuery.isNotEmpty ? allTracks : null,
                onTriggerRescan: () => ScanTerminalSheet.show(context, widget.playerState),
              ),

              // 3. Albums Grouping
              _buildAlbumsList(albums),
            ],
          ),
          bottomNavigationBar: ListenableBuilder(
            listenable: widget.playerState,
            builder: (context, _) {
              return MiniPlayerBar(
                playerState: widget.playerState,
                onTap: widget.onOpenNowPlaying,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTracksList(List<AudioTrack> tracks) {
    if (widget.playerState.isScanning) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.of(context).evaPurple),
      );
    }

    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off, size: 48, color: AppColors.of(context).textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Tidak ada trek yang cocok dengan "$_searchQuery"'
                  : 'Tidak ada file musik ditemukan.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              icon: Icon(Icons.sync, color: AppColors.of(context).evaPurple, size: 18),
              label: Text('Pindai Ulang', style: TextStyle(color: AppColors.of(context).evaPurple)),
              onPressed: widget.playerState.scanLocalMusic,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isSelected = widget.playerState.selectedTrack?.path == track.path;

        return TrackTile(
          track: track,
          isSelected: isSelected,
          onTap: () {
            widget.playerState.setQueue(tracks, startIndex: index);
          },
        );
      },
    );
  }

  Widget _buildFoldersList(Map<String, List<AudioTrack>> folders) {
    if (folders.isEmpty) {
      return Center(
        child: Text('Tidak ada folder musik.', style: AppTypography.bodySmall),
      );
    }

    final folderEntries = folders.entries.toList();

    return ListView.separated(
      itemCount: folderEntries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = folderEntries[index];
        final folderPath = entry.key;
        final folderTracks = entry.value;
        final folderName = folderTracks.first.folderName;

        return ListTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.of(context).surfaceInset,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: Icon(Icons.folder, color: AppColors.of(context).evaPurple, size: 22),
          ),
          title: Text(
            folderName,
            style: AppTypography.trackTitle.copyWith(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            folderPath,
            style: AppTypography.bodySmall.copyWith(color: AppColors.of(context).textMuted),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.of(context).surfaceInset,
              borderRadius: AppSpacing.borderBadge,
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: Text(
              '${folderTracks.length} tracks',
              style: AppTypography.telemetrySmall,
            ),
          ),
          onTap: () {
            if (widget.onOpenCollection != null) {
              widget.onOpenCollection!(folderName, folderTracks);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CollectionDetailPage(
                    title: folderName,
                    subtitle: folderPath,
                    tracks: folderTracks,
                    isAlbum: false,
                    playerState: widget.playerState,
                    onOpenNowPlaying: widget.onOpenNowPlaying,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildAlbumsList(Map<String, List<AudioTrack>> albums) {
    if (albums.isEmpty) {
      return Center(
        child: Text('Tidak ada album musik.', style: AppTypography.bodySmall),
      );
    }

    final albumEntries = albums.entries.toList();

    return ListView.separated(
      itemCount: albumEntries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = albumEntries[index];
        final albumName = entry.key;
        final albumTracks = entry.value;
        final artist = albumTracks.first.artist;
        final coverPath = albumTracks
            .firstWhere((t) => t.artworkPath.isNotEmpty, orElse: () => albumTracks.first)
            .artworkPath;

        return ListTile(
          leading: AlbumArtwork(
            size: 42,
            imagePath: coverPath,
          ),
          title: Text(
            albumName,
            style: AppTypography.trackTitle.copyWith(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            artist,
            style: AppTypography.trackArtist,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.of(context).surfaceInset,
              borderRadius: AppSpacing.borderBadge,
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: Text(
              '${albumTracks.length} tracks',
              style: AppTypography.telemetrySmall,
            ),
          ),
          onTap: () {
            if (widget.onOpenCollection != null) {
              widget.onOpenCollection!(albumName, albumTracks);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CollectionDetailPage(
                    title: albumName,
                    subtitle: artist,
                    tracks: albumTracks,
                    isAlbum: true,
                    playerState: widget.playerState,
                    onOpenNowPlaying: widget.onOpenNowPlaying,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
