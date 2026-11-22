import 'dart:convert';
import 'dart:io';
import '../../../services/native_audio_service.dart';

class LibraryCacheData {
  final List<AudioTrack> tracks;
  final List<String> excludedFolders;
  final int timestamp;

  LibraryCacheData({
    required this.tracks,
    required this.excludedFolders,
    required this.timestamp,
  });
}

class LibraryCacheService {
  static const String _fileName = 'library_cache.json';
  static String? _cachedDocDir;

  static Future<String> _getCacheFilePath() async {
    if (_cachedDocDir != null) {
      return '$_cachedDocDir/$_fileName';
    }
    final docDir = await NativeAudioService.instance.getAppDocumentsPath();
    _cachedDocDir = docDir ?? '/data/user/0/com.example.tannhauser_music_player/files';
    return '$_cachedDocDir/$_fileName';
  }

  static Future<LibraryCacheData?> loadCache() async {
    try {
      final path = await _getCacheFilePath();
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;

      final Map<String, dynamic> data = jsonDecode(content) as Map<String, dynamic>;
      final rawTracks = data['tracks'] as List<dynamic>? ?? [];
      final rawExcluded = data['excludedFolders'] as List<dynamic>? ?? [];
      final timestamp = (data['timestamp'] as num?)?.toInt() ?? 0;

      final tracks = rawTracks
          .map((item) => AudioTrack.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      final excluded = rawExcluded.map((e) => e.toString()).toList();

      return LibraryCacheData(
        tracks: tracks,
        excludedFolders: excluded,
        timestamp: timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> saveCache({
    required List<AudioTrack> tracks,
    required List<String> excludedFolders,
  }) async {
    try {
      final path = await _getCacheFilePath();
      final tempFile = File('$path.tmp');
      final targetFile = File(path);

      final payload = {
        'version': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'excludedFolders': excludedFolders,
        'tracks': tracks.map((t) => t.toMap()).toList(),
      };

      final jsonString = jsonEncode(payload);

      // Atomic file write to avoid corruption during unexpected exits
      await tempFile.parent.create(recursive: true);
      await tempFile.writeAsString(jsonString, flush: true);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clearCache() async {
    try {
      final path = await _getCacheFilePath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
