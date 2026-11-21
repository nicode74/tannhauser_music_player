import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../services/native_audio_service.dart';

enum PlaybackRepeatMode { off, all, one }

/// Central Player State Controller using standard Flutter ChangeNotifier.
/// Zero third-party dependencies, ultra-lightweight, and thread-safe.
class PlayerState extends ChangeNotifier {
  final NativeAudioService _audioService = NativeAudioService.instance;

  List<AudioTrack> _tracks = [];
  List<AudioTrack> _queue = [];
  List<AudioTrack> _originalQueue = [];
  AudioTrack? _selectedTrack;
  PlaybackInfo? _playbackInfo;

  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.off;
  bool _isShuffle = false;

  bool _isUsbConnected = false;
  String _usbDeviceName = 'No USB DAC Detected';
  bool _isScanning = false;
  bool _isLoadingFile = false;

  Timer? _pollingTimer;
  StreamSubscription? _usbSubscription;

  // Getters
  List<AudioTrack> get tracks => _tracks;
  List<AudioTrack> get queue => _queue;
  PlaybackRepeatMode get repeatMode => _repeatMode;
  bool get isShuffle => _isShuffle;
  AudioTrack? get selectedTrack => _selectedTrack;
  PlaybackInfo? get playbackInfo => _playbackInfo;
  bool get isUsbConnected => _isUsbConnected;
  String get usbDeviceName => _usbDeviceName;
  bool get isScanning => _isScanning;
  bool get isLoadingFile => _isLoadingFile;
  bool get isPlaying => _playbackInfo?.state == PlaybackState.playing;

  void setQueue(List<AudioTrack> newTracks, {int startIndex = 0}) {
    _originalQueue = List.from(newTracks);
    _queue = List.from(newTracks);
    if (_isShuffle) {
      _applyShuffle();
    }
    if (startIndex >= 0 && startIndex < _queue.length) {
      loadFile(_queue[startIndex]).then((_) => play());
    }
    notifyListeners();
  }

  void toggleRepeatMode() {
    switch (_repeatMode) {
      case PlaybackRepeatMode.off:
        _repeatMode = PlaybackRepeatMode.all;
        break;
      case PlaybackRepeatMode.all:
        _repeatMode = PlaybackRepeatMode.one;
        break;
      case PlaybackRepeatMode.one:
        _repeatMode = PlaybackRepeatMode.off;
        break;
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle) {
      _applyShuffle();
    } else {
      _queue = List.from(_originalQueue);
    }
    notifyListeners();
  }

  void _applyShuffle() {
    final current = _selectedTrack;
    final other = _queue.where((t) => t.path != current?.path).toList()..shuffle();
    if (current != null) {
      _queue = [current, ...other];
    } else {
      _queue = other;
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      notifyListeners();
    }
  }

  void clearQueue() {
    _queue.clear();
    notifyListeners();
  }

  Map<String, List<AudioTrack>> get tracksByFolder {
    final Map<String, List<AudioTrack>> map = {};
    for (final track in _tracks) {
      final key = track.folderPath.isNotEmpty ? track.folderPath : 'Unknown Folder';
      map.putIfAbsent(key, () => []).add(track);
    }
    return map;
  }

  Map<String, List<AudioTrack>> get tracksByAlbum {
    final Map<String, List<AudioTrack>> map = {};
    for (final track in _tracks) {
      final key = track.album.isNotEmpty ? track.album : 'Unknown Album';
      map.putIfAbsent(key, () => []).add(track);
    }
    return map;
  }

  void init() {
    _initUsbListener();
    _startPollingPlaybackInfo();
    scanLocalMusic();
  }

  void _initUsbListener() {
    _usbSubscription = _audioService.usbEvents.listen((event) {
      _isUsbConnected = event['connected'] as bool? ?? false;
      _usbDeviceName = (event['deviceName'] as String?) ??
          (_isUsbConnected ? 'USB Audio Device' : 'No USB DAC Detected');
      notifyListeners();
    });

    _audioService.scanUsb();
  }

  void _startPollingPlaybackInfo() {
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final info = await _audioService.getPlaybackInfo();
      if (info != null) {
        _playbackInfo = info;
        _isUsbConnected = info.isUsbConnected;
        notifyListeners();
      }
    });
  }

  Future<bool> scanLocalMusic() async {
    if (_isScanning) return false;
    _isScanning = true;
    notifyListeners();

    try {
      final granted = await _audioService.requestPermissions();
      if (!granted) {
        _isScanning = false;
        notifyListeners();
        return false;
      }

      final scannedTracks = await _audioService.scanAudioFiles();
      _tracks = scannedTracks;
      if (_queue.isEmpty) {
        _queue = List.from(scannedTracks);
        _originalQueue = List.from(scannedTracks);
      }
      if (_selectedTrack == null && scannedTracks.isNotEmpty) {
        _selectedTrack = scannedTracks.first;
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<bool> loadFile(AudioTrack track) async {
    _selectedTrack = track;
    _isLoadingFile = true;
    notifyListeners();

    try {
      final success = await _audioService.loadFile(
        track.path,
        title: track.title,
        artist: track.artist,
      );
      return success;
    } finally {
      _isLoadingFile = false;
      notifyListeners();
    }
  }

  Future<bool> loadCustomPath(String path) async {
    final cleanPath = path.trim();
    if (cleanPath.isEmpty) return false;

    _isLoadingFile = true;
    notifyListeners();

    try {
      final fileName = cleanPath.split('/').last;
      final success = await _audioService.loadFile(
        cleanPath,
        title: fileName,
        artist: 'Manual File',
      );
      if (success) {
        _selectedTrack = AudioTrack(
          path: cleanPath,
          title: fileName,
          artist: 'Manual File',
          album: 'Local Storage',
          durationMs: 0,
        );
      }
      return success;
    } finally {
      _isLoadingFile = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_selectedTrack != null &&
        (_playbackInfo?.state == PlaybackState.stopped || _playbackInfo == null)) {
      await loadFile(_selectedTrack!);
      await _audioService.play();
    } else if (isPlaying) {
      await _audioService.pause();
    } else {
      await _audioService.play();
    }
  }

  Future<void> play() => _audioService.play();
  Future<void> pause() => _audioService.pause();
  Future<void> resume() => _audioService.resume();
  Future<void> stop() => _audioService.stop();
  Future<void> seek(int positionMs) => _audioService.seek(positionMs);
  Future<void> scanUsb() => _audioService.scanUsb();

  void next() {
    final activeList = _queue.isNotEmpty ? _queue : _tracks;
    if (activeList.isEmpty || _selectedTrack == null) return;
    if (_repeatMode == PlaybackRepeatMode.one) {
      seek(0).then((_) => play());
      return;
    }
    final currentIndex = activeList.indexWhere((t) => t.path == _selectedTrack!.path);
    if (currentIndex != -1 && currentIndex + 1 < activeList.length) {
      final nextTrack = activeList[currentIndex + 1];
      loadFile(nextTrack).then((_) => play());
    } else if (_repeatMode == PlaybackRepeatMode.all && activeList.isNotEmpty) {
      loadFile(activeList.first).then((_) => play());
    }
  }

  void previous() {
    final activeList = _queue.isNotEmpty ? _queue : _tracks;
    if (activeList.isEmpty || _selectedTrack == null) return;
    final pos = _playbackInfo?.positionMs ?? 0;
    if (pos > 3000) {
      seek(0);
      return;
    }
    final currentIndex = activeList.indexWhere((t) => t.path == _selectedTrack!.path);
    if (currentIndex > 0) {
      final prevTrack = activeList[currentIndex - 1];
      loadFile(prevTrack).then((_) => play());
    } else if (_repeatMode == PlaybackRepeatMode.all && activeList.isNotEmpty) {
      loadFile(activeList.last).then((_) => play());
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _usbSubscription?.cancel();
    super.dispose();
  }
}
