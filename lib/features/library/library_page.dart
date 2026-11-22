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
import 'widgets/mini_player_bar.dart';

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
    return ListenableBuilder(
      listenable: widget.playerState,
      builder: (context, _) {
        final allTracks = _filterTracks(widget.playerState.tracks);
        final folders = widget.playerState.tracksByFolder;
        final albums = widget.playerState.tracksByAlbum;
        final isUsb = widget.playerState.isUsbConnected;

        return Scaffold(
          appBar: AppBar(
            title: _isSearchOpen
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: AppTypography.body,
                    decoration: InputDecoration(
                      hintText: 'Cari judul, artis, atau album...',
                      hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                  )
                : const Text('TANNHÄUSER // UNIT-01'),
            actions: [
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
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => SystemConsoleSheet.show(context, widget.playerState),
                    child: StatusPill(
                      label: isUsb ? 'USB DAC' : 'NO DAC',
                      type: isUsb ? StatusPillType.bitPerfect : StatusPillType.noDac,
                    ),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1.0),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.evaPurple,
                  indicatorWeight: 2.5,
                  labelColor: AppColors.evaPurple,
                  unselectedLabelColor: AppColors.textSecondary,
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

              // 2. Folders Grouping
              _buildFoldersList(folders),

              // 3. Albums Grouping
              _buildAlbumsList(albums),
            ],
          ),
          bottomNavigationBar: MiniPlayerBar(
            playerState: widget.playerState,
            onTap: widget.onOpenNowPlaying,
          ),
        );
      },
    );
  }

  Widget _buildTracksList(List<AudioTrack> tracks) {
    if (widget.playerState.isScanning) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.evaPurple),
      );
    }

    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Tidak ada trek yang cocok dengan "$_searchQuery"'
                  : 'Tidak ada file musik ditemukan.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              icon: const Icon(Icons.sync, color: AppColors.evaPurple, size: 18),
              label: const Text('Pindai Ulang', style: TextStyle(color: AppColors.evaPurple)),
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
            widget.playerState.loadFile(track).then((_) {
              widget.playerState.play();
            });
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
              color: AppColors.surfaceInset,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.folder, color: AppColors.evaPurple, size: 22),
          ),
          title: Text(
            folderName,
            style: AppTypography.trackTitle.copyWith(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            folderPath,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceInset,
              borderRadius: AppSpacing.borderBadge,
              border: Border.all(color: AppColors.border),
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

        return ListTile(
          leading: const AlbumArtwork(size: 42),
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
              color: AppColors.surfaceInset,
              borderRadius: AppSpacing.borderBadge,
              border: Border.all(color: AppColors.border),
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
