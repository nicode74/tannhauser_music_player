import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/library/library_page.dart';
import 'features/peq/controllers/peq_state.dart';
import 'features/player/controllers/player_state.dart';
import 'features/player/now_playing_page.dart';
import 'features/splash/eva_splash_screen.dart';

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
  late final PeqState _peqState;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _playerState = PlayerState()..init();
    _peqState = PeqState();
  }

  @override
  void dispose() {
    _playerState.dispose();
    _peqState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tannhäuser Audio Terminal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _showSplash
            ? EvaSplashScreen(
                key: const ValueKey('splash_screen'),
                onComplete: () {
                  setState(() {
                    _showSplash = false;
                  });
                },
              )
            : Builder(
                key: const ValueKey('library_screen'),
                builder: (ctx) {
                  return LibraryPage(
                    playerState: _playerState,
                    onOpenNowPlaying: () {
                      Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) => NowPlayingPage(
                            playerState: _playerState,
                            peqState: _peqState,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
