import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/native_audio_service.dart';
import 'eva_palette.dart';

/// Manages active EVA color palette selection and atomic local JSON persistence.
class ThemeController extends ChangeNotifier {
  static const String _fileName = 'theme_prefs.json';
  EvaPalette _palette = EvaPalette.eva01;
  String? _cachedDocDir;

  EvaPalette get palette => _palette;

  Future<String?> _getPrefsFilePath() async {
    if (_cachedDocDir != null) {
      return '$_cachedDocDir/$_fileName';
    }
    final docDir = await NativeAudioService.instance.getAppDocumentsPath();
    if (docDir == null || docDir.isEmpty) {
      return null;
    }
    _cachedDocDir = docDir;
    return '$_cachedDocDir/$_fileName';
  }

  Future<void> init() async {
    try {
      final path = await _getPrefsFilePath();
      if (path == null) return;
      final file = File(path);
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return;

      final Map<String, dynamic> data = jsonDecode(content) as Map<String, dynamic>;
      final savedId = data['paletteId'] as String?;
      if (savedId != null && savedId.isNotEmpty) {
        final resolved = EvaPalette.byId(savedId);
        if (resolved.id != _palette.id) {
          _palette = resolved;
          notifyListeners();
        }
      }
    } catch (_) {
      // Fallback to default EVA-01 silently on corrupt/unreadable prefs
    }
  }

  Future<void> setPalette(String paletteId) async {
    final next = EvaPalette.byId(paletteId);
    if (next.id == _palette.id) return;
    _palette = next;
    notifyListeners();
    await _persistPalette(next.id);
    await NativeAudioService.instance.setLauncherIcon(next.id);
  }

  Future<void> _persistPalette(String paletteId) async {
    try {
      final path = await _getPrefsFilePath();
      if (path == null) return;
      final tmpFile = File('$path.tmp');
      final targetFile = File(path);
      final payload = jsonEncode({'paletteId': paletteId});
      await tmpFile.writeAsString(payload, flush: true);
      await tmpFile.rename(targetFile.path);
    } catch (_) {
      // Ignore persistence write errors without blocking UI theme switch
    }
  }
}

/// InheritedNotifier exposing ThemeController to any descendant widget/sheet.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in widget tree');
    return scope!.notifier!;
  }

  static ThemeController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
  }
}
