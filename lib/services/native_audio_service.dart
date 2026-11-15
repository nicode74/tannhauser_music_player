import 'dart:async';
import 'package:flutter/services.dart';

enum PlaybackState {
  stopped,
  playing,
  paused,
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

  static final NativeAudioService instance = NativeAudioService._internal();
  NativeAudioService._internal();

  Stream<Map<String, dynamic>>? _usbStream;

  Stream<Map<String, dynamic>> get usbEvents {
    _usbStream ??= _usbEventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _usbStream!;
  }

  Future<bool> scanUsb() async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('scanUsb');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> loadFile(String filePath) async {
    try {
      final bool? result = await _commandChannel.invokeMethod<bool>('loadFile', {
        'filePath': filePath,
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
      final map = await _commandChannel.invokeMethod<Map<dynamic, dynamic>>('getPlaybackInfo');
      if (map != null) {
        return PlaybackInfo.fromMap(map);
      }
    } catch (_) {}
    return null;
  }
}
