import 'dart:async';
import 'package:flutter/services.dart';

enum PlaybackState {
  stopped,
  playing,
  paused,
}

class AudioTrack {
  final String path;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int sizeBytes;
  final int sampleRate;
  final int bitDepth;
  final int bitRate;
  final int trackNumber;
  final String codec;
  final String artworkPath;

  AudioTrack({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.sizeBytes = 0,
    this.sampleRate = 44100,
    this.bitDepth = 16,
    this.bitRate = 0,
    this.trackNumber = 0,
    this.codec = '',
    this.artworkPath = '',
  });

  AudioTrack copyWith({String? artworkPath}) {
    return AudioTrack(
      path: path,
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
      sizeBytes: sizeBytes,
      sampleRate: sampleRate,
      bitDepth: bitDepth,
      bitRate: bitRate,
      trackNumber: trackNumber,
      codec: codec,
      artworkPath: artworkPath ?? this.artworkPath,
    );
  }

  factory AudioTrack.fromMap(Map<dynamic, dynamic> map) {
    return AudioTrack(
      path: map['path'] as String? ?? '',
      title: map['title'] as String? ?? 'Unknown Title',
      artist: map['artist'] as String? ?? 'Unknown Artist',
      album: map['album'] as String? ?? 'Unknown Album',
      durationMs: (map['duration'] as num?)?.toInt() ?? 0,
      sizeBytes: (map['size'] as num?)?.toInt() ?? 0,
      sampleRate: (map['sampleRate'] as num?)?.toInt() ?? 44100,
      bitDepth: (map['bitDepth'] as num?)?.toInt() ?? 16,
      bitRate: (map['bitRate'] as num?)?.toInt() ?? 0,
      trackNumber: (map['trackNumber'] as num?)?.toInt() ?? 0,
      codec: map['codec'] as String? ?? '',
      artworkPath: map['artworkPath'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': durationMs,
      'size': sizeBytes,
      'sampleRate': sampleRate,
      'bitDepth': bitDepth,
      'bitRate': bitRate,
      'trackNumber': trackNumber,
      'codec': codec,
      'artworkPath': artworkPath,
    };
  }

  String get folderPath {
    final lastSlash = path.lastIndexOf('/');
    return lastSlash != -1 ? path.substring(0, lastSlash) : '';
  }

  String get folderName {
    final cleanPath = folderPath;
    if (cleanPath.isEmpty) return 'Unknown';
    final lastSlash = cleanPath.lastIndexOf('/');
    return lastSlash != -1 ? cleanPath.substring(lastSlash + 1) : cleanPath;
  }

  String get extension {
    final dot = path.lastIndexOf('.');
    return dot != -1 && dot + 1 < path.length ? path.substring(dot + 1).toUpperCase() : 'PCM';
  }

  bool get isLossless {
    final ext = extension.toUpperCase();
    return ext == 'FLAC' || ext == 'WAV' || ext == 'ALAC' || ext == 'AIFF';
  }

  bool get isDsd {
    final ext = extension.toUpperCase();
    return ext == 'DSF' || ext == 'DFF' || ext == 'ISO';
  }

  String get formattedSize {
    if (sizeBytes <= 0) return '';
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1000) {
      final gb = mb / 1024;
      return '${gb.toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class PlaybackInfo {
  final PlaybackState state;
  final int sampleRate;
  final int channels;
  final int bitDepth;
  final int durationMs;
  final int positionMs;
  final bool isUsbConnected;

  int get totalDurationMs => durationMs;

  PlaybackInfo({
    required this.state,
    required this.sampleRate,
    required this.channels,
    required this.bitDepth,
    required this.durationMs,
    required this.positionMs,
    required this.isUsbConnected,
  });

  factory PlaybackInfo.fromMap(Map<dynamic, dynamic> map) {
    PlaybackState state = PlaybackState.stopped;
    final stateInt = map['state'] as int? ?? 0;
    if (stateInt == 1) {
      state = PlaybackState.playing;
    } else if (stateInt == 2) {
      state = PlaybackState.paused;
    }

    return PlaybackInfo(
      state: state,
      sampleRate: map['sampleRate'] as int? ?? 0,
      channels: map['channels'] as int? ?? 0,
      bitDepth: map['bitDepth'] as int? ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
      isUsbConnected: map['isUsbConnected'] as bool? ?? false,
    );
  }
}

class NativeAudioService {
  static const MethodChannel _commandChannel =
      MethodChannel('com.example.tannhauser_music_player/audio');
  static const EventChannel _usbEventChannel =
      EventChannel('com.example.tannhauser_music_player/usb_events');
  static const EventChannel _scanProgressChannel =
      EventChannel('com.example.tannhauser_music_player/scan_progress');

  static final NativeAudioService instance = NativeAudioService._internal();
  factory NativeAudioService() => instance;
  NativeAudioService._internal() {
    _commandChannel.setMethodCallHandler((call) async {
      if (call.method == 'onVolumeChanged') {
        final vol = (call.arguments?['volume'] as num?)?.toDouble();
        if (vol != null) {
          _volumeStreamController.add(vol);
        }
      }
    });
  }

  final StreamController<double> _volumeStreamController =
      StreamController<double>.broadcast();
  Stream<double> get volumeEvents => _volumeStreamController.stream;

  Stream<Map<String, dynamic>>? _usbStream;
  Stream<Map<String, dynamic>>? _scanStream;

  Stream<Map<String, dynamic>> get usbEvents {
    _usbStream ??= _usbEventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _usbStream!;
  }

  Stream<Map<String, dynamic>> get scanProgressEvents {
    _scanStream ??= _scanProgressChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _scanStream!;
  }

  Future<String?> getAppDocumentsPath() async {
    try {
      return await _commandChannel.invokeMethod<String>('getAppDocumentsPath');
    } catch (_) {
      return null;
    }
  }

  Future<bool> checkAllFilesPermission() async {
    try {
      final bool? granted = await _commandChannel.invokeMethod<bool>('checkAllFilesPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestAllFilesPermission() async {
    try {
      final bool? granted = await _commandChannel.invokeMethod<bool>('requestAllFilesPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getStorageRoots() async {
    try {
      final List<dynamic>? list =
          await _commandChannel.invokeMethod<List<dynamic>>('getStorageRoots');
      if (list != null) {
        return list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> listSubdirectories(String path) async {
    try {
      final List<dynamic>? list = await _commandChannel.invokeMethod<List<dynamic>>(
        'listSubdirectories',
        {'path': path},
      );
      if (list != null) {
        return list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<AudioTrack>> startStorageScan({
    List<String>? customPaths,
    int minDurationMs = 30000,
    int minSizeBytes = 524288,
    List<String>? excludedFolders,
  }) async {
    try {
      final List<dynamic>? list = await _commandChannel.invokeMethod<List<dynamic>>('startStorageScan', {
        if (customPaths != null) 'customPaths': customPaths,
        'minDurationMs': minDurationMs,
        'minSizeBytes': minSizeBytes,
        if (excludedFolders != null) 'excludedFolders': excludedFolders,
      });
      if (list != null) {
        return list
            .map((item) => AudioTrack.fromMap(Map<dynamic, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<String> extractTrackArtwork(
    String filePath, {
    String album = '',
    String artist = '',
  }) async {
    try {
      final String? path = await _commandChannel.invokeMethod<String>(
        'extractTrackArtwork',
        {
          'filePath': filePath,
          'album': album,
          'artist': artist,
        },
      );
      return path ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<bool> stopStorageScan() async {
    try {
      final bool? res = await _commandChannel.invokeMethod<bool>('stopStorageScan');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkPermissions() async {
    try {
      final bool? granted =
          await _commandChannel.invokeMethod<bool>('checkPermissions');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final bool? granted =
          await _commandChannel.invokeMethod<bool>('requestPermissions');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<List<AudioTrack>> scanAudioFiles() async {
    try {
      final List<dynamic>? list =
          await _commandChannel.invokeMethod<List<dynamic>>('scanAudioFiles');
      if (list != null) {
        return list
            .map((item) =>
                AudioTrack.fromMap(Map<dynamic, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> scanUsb() async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('scanUsb');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> loadFile(String filePath, {String? title, String? artist}) async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('loadFile', {
        'filePath': filePath,
        if (title != null) 'title': title,
        if (artist != null) 'artist': artist,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> play() async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('play');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pause() async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('pause');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resume() async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('resume');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stop() async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('stop');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> seek(int positionMs) async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('seek', {
        'positionMs': positionMs,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<PlaybackInfo?> getPlaybackInfo() async {
    try {
      final map = await _commandChannel
          .invokeMethod<Map<dynamic, dynamic>>('getPlaybackInfo');
      if (map != null) {
        return PlaybackInfo.fromMap(map);
      }
    } catch (_) {}
    return null;
  }

  // 64-Bit Parametric EQ NDK Commands
  Future<bool> setPeqEnabled(bool enabled) async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('setPeqEnabled', {
        'enabled': enabled,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setPeqPreamp(double preampDb) async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('setPeqPreamp', {
        'preampDb': preampDb,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updatePeqBand({
    required int index,
    required int type,
    required double fc,
    required double gainDb,
    required double q,
    required bool enabled,
  }) async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('updatePeqBand', {
        'index': index,
        'type': type,
        'fc': fc,
        'gainDb': gainDb,
        'q': q,
        'enabled': enabled,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resetPeqStates() async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('resetPeqStates');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // Master Digital Volume Control
  Future<bool> setVolume(double volume) async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('setVolume', {
        'volume': volume.clamp(0.0, 1.0),
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<double> getVolume() async {
    try {
      final double? result =
          await _commandChannel.invokeMethod<double>('getVolume');
      return result ?? 1.0;
    } catch (_) {
      return 1.0;
    }
  }

  Future<bool> setLauncherIcon(String paletteId) async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('setLauncherIcon', {
        'paletteId': paletteId,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
