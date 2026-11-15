import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'services/native_audio_service.dart';

void main() {
  runApp(const TannhauserApp());
}

class TannhauserApp extends StatelessWidget {
  const TannhauserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tannhäuser Audio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0E15),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
          surface: Color(0xFF161824),
        ),
        useMaterial3: true,
      ),
      home: const BitPerfectPlayerScreen(),
    );
  }
}

class BitPerfectPlayerScreen extends StatefulWidget {
  const BitPerfectPlayerScreen({super.key});

  @override
  State<BitPerfectPlayerScreen> createState() => _BitPerfectPlayerScreenState();
}

class _BitPerfectPlayerScreenState extends State<BitPerfectPlayerScreen> {
  final NativeAudioService _audioService = NativeAudioService.instance;
  final TextEditingController _pathController = TextEditingController(
    text: '/sdcard/Music/test.flac',
  );

  bool _isUsbConnected = false;
  String _usbDeviceName = 'No USB DAC Detected';
  PlaybackInfo? _playbackInfo;
  Timer? _pollingTimer;
  StreamSubscription? _usbSubscription;

  @override
  void initState() {
    super.initState();
    _initUsbListener();
    _startPollingPlaybackInfo();
  }

  void _initUsbListener() {
    _usbSubscription = _audioService.usbEvents.listen((event) {
      setState(() {
        _isUsbConnected = event['connected'] as bool? ?? false;
        _usbDeviceName = (event['deviceName'] as String?) ??
            (_isUsbConnected ? 'USB Audio Device' : 'No USB DAC Detected');
      });
    });

    // Inisialisasi scan pertama kali
    _audioService.scanUsb();
  }

  void _startPollingPlaybackInfo() {
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final info = await _audioService.getPlaybackInfo();
      if (mounted && info != null) {
        setState(() {
          _playbackInfo = info;
          _isUsbConnected = info.isUsbConnected;
        });
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _usbSubscription?.cancel();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;

    final success = await _audioService.loadFile(path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'File loaded successfully' : 'Failed to load file',
          ),
          backgroundColor: success ? Colors.green[800] : Colors.red[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playbackInfo?.state == PlaybackState.playing;
    final sampleRate = _playbackInfo?.sampleRate ?? 0;
    final bitDepth = _playbackInfo?.bitDepth ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tannhäuser Bit-Perfect Player',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.usb),
            tooltip: 'Rescan USB DAC',
            onPressed: () => _audioService.scanUsb(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // USB DAC Status Banner
              _buildUsbStatusBanner(),
              const SizedBox(height: 16),

              // Audio Format & Bit-Perfect Badges
              _buildBitPerfectIndicator(sampleRate, bitDepth),
              const SizedBox(height: 24),

              // File Path Input
              _buildFileSelector(),
              const SizedBox(height: 24),

              // Player Visualizer / Disc Mock
              _buildPlayerDisc(isPlaying),
              const SizedBox(height: 24),

              // Playback Slider
              _buildPlaybackSlider(),
              const SizedBox(height: 16),

              // Controls
              _buildPlaybackControls(isPlaying),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsbStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isUsbConnected
            ? const Color(0xFF00382B)
            : const Color(0xFF231C18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isUsbConnected
              ? const Color(0xFF00E676)
              : const Color(0xFFFF9100),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isUsbConnected ? Icons.usb : Icons.usb_off,
            color: _isUsbConnected
                ? const Color(0xFF00E676)
                : const Color(0xFFFF9100),
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isUsbConnected ? 'USB DAC CONNECTED' : 'NO DAC DETECTED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: _isUsbConnected
                        ? const Color(0xFF00E676)
                        : const Color(0xFFFF9100),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _usbDeviceName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBitPerfectIndicator(int sampleRate, int bitDepth) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isUsbConnected
                ? const Color(0xFF00E676).withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isUsbConnected ? const Color(0xFF00E676) : Colors.grey,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 14,
                color: _isUsbConnected ? const Color(0xFF00E676) : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                _isUsbConnected
                    ? 'Bit-Perfect Mode: ON'
                    : 'Bit-Perfect Mode: Standby',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color:
                      _isUsbConnected ? const Color(0xFF00E676) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (sampleRate > 0)
          Text(
            '${(sampleRate / 1000).toStringAsFixed(1)} kHz / $bitDepth-bit',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF00E5FF),
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildFileSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AUDIO FILE PATH',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            color: Colors.white54,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pathController,
                decoration: InputDecoration(
                  hintText: 'Input .flac / .alac / .wav path',
                  filled: true,
                  fillColor: const Color(0xFF161824),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _loadFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Load'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerDisc(bool isPlaying) {
    return Center(
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFF161824),
              const Color(0xFF0D0E15),
              _isUsbConnected
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.1),
            ],
          ),
          border: Border.all(
            color: isPlaying
                ? const Color(0xFF00E5FF)
                : Colors.white24,
            width: 2,
          ),
        ),
        child: Icon(
          Icons.album,
          size: 100,
          color: isPlaying
              ? const Color(0xFF00E5FF)
              : Colors.white24,
        ),
      ),
    );
  }

  Widget _buildPlaybackSlider() {
    final position = (_playbackInfo?.positionMs ?? 0).toDouble();
    final duration = (_playbackInfo?.totalDurationMs ?? 0).toDouble();
    final max = duration > 0 ? duration : 1.0;
    final clampedPos = position.clamp(0.0, max);

    return Column(
      children: [
        Slider(
          value: clampedPos,
          max: max,
          activeColor: const Color(0xFF00E5FF),
          inactiveColor: Colors.white12,
          onChanged: (val) {
            _audioService.seek(val.toInt());
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(clampedPos.toInt()),
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              Text(
                _formatTime(duration.toInt()),
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls(bool isPlaying) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.stop),
          iconSize: 36,
          color: Colors.white70,
          onPressed: () => _audioService.stop(),
        ),
        const SizedBox(width: 24),
        IconButton(
          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
          iconSize: 64,
          color: const Color(0xFF00E5FF),
          onPressed: () {
            if (isPlaying) {
              _audioService.pause();
            } else {
              _audioService.play();
            }
          },
        ),
      ],
    );
  }

  String _formatTime(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
