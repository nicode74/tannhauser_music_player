import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
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
  late final ThemeController _themeController;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _playerState = PlayerState()..init();
    _peqState = PeqState();
    _themeController = ThemeController()..init();
  }

  @override
  void dispose() {
    _playerState.dispose();
    _peqState.dispose();
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _themeController,
      child: ListenableBuilder(
        listenable: _themeController,
        builder: (context, _) {
          return MaterialApp(
            title: 'Tannhauser',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.buildTheme(_themeController.palette),
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
        },
      ),
    );
  }
}
