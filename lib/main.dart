import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/library/library_page.dart';
import 'features/player/controllers/player_state.dart';
import 'features/player/now_playing_page.dart';

void main() {
  runApp(const TannhauserApp());
}

class TannhauserApp extends StatefulWidget {
  const TannhauserApp({super.key});

  @override
  State<TannhauserApp> createState() => _TannhauserAppState();
}

class _TannhauserAppState extends State<TannhauserApp> {
  late final PlayerState _playerState;

  @override
  void initState() {
    super.initState();
    _playerState = PlayerState()..init();
  }

  @override
  void dispose() {
    _playerState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tannhäuser Audio Terminal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Builder(
        builder: (ctx) {
          return LibraryPage(
            playerState: _playerState,
            onOpenNowPlaying: () {
              Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => NowPlayingPage(
                    playerState: _playerState,
                    onOpenPeq: () {
                      // Wired in Step 4: PeqEditorSheet
                    },
                    onOpenQueue: () {
                      // Wired in Step 5: QueueSheet
                    },
                    onOpenSystemConsole: () {
                      // Wired in Step 6: SystemConsoleSheet
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
