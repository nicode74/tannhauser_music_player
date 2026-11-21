import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/native_audio_service.dart';
import '../models/peq_band.dart';

/// Central 64-bit Parametric EQ Controller & RBJ DSP Math Engine
class PeqState extends ChangeNotifier {
  final NativeAudioService _audioService;
  bool _isEnabled = false;
  double _preAmpDb = 0.0;
  int _selectedBandIndex = 0;

  PeqState({NativeAudioService? audioService})
      : _audioService = audioService ?? NativeAudioService();

  final List<PeqBand> _bands = [
    PeqBand(index: 0, fc: 31.0, type: PeqFilterType.lowShelf, q: 0.71),
    PeqBand(index: 1, fc: 62.0, type: PeqFilterType.peaking, q: 1.41),
    PeqBand(index: 2, fc: 125.0, type: PeqFilterType.peaking, q: 1.41),
    PeqBand(index: 3, fc: 250.0, type: PeqFilterType.peaking, q: 1.41),
    PeqBand(index: 4, fc: 500.0, type: PeqFilterType.peaking, q: 1.41),
    PeqBand(index: 5, fc: 1000.0, type: PeqFilterType.peaking, q: 1.41),
    PeqBand(index: 6, fc: 2000.0, type: PeqFilterType.peaking, q: 1.41),
    PeqBand(index: 7, fc: 4000.0, type: PeqFilterType.peaking, q: 1.41),
    PeqBand(index: 8, fc: 8000.0, type: PeqFilterType.peaking, q: 1.41),
    PeqBand(index: 9, fc: 16000.0, type: PeqFilterType.highShelf, q: 0.71),
  ];

  bool get isEnabled => _isEnabled;
  double get preAmpDb => _preAmpDb;
  int get selectedBandIndex => _selectedBandIndex;
  List<PeqBand> get bands => _bands;
  PeqBand get selectedBand => _bands[_selectedBandIndex];

  void toggleEnabled() {
    _isEnabled = !_isEnabled;
    _audioService.setPeqEnabled(_isEnabled);
    notifyListeners();
  }

  void setEnabled(bool val) {
    _isEnabled = val;
    _audioService.setPeqEnabled(_isEnabled);
    notifyListeners();
  }

  void setPreAmp(double db) {
    _preAmpDb = db.clamp(-12.0, 12.0);
    _audioService.setPeqPreamp(_preAmpDb);
    notifyListeners();
  }

  void selectBand(int index) {
    if (index >= 0 && index < _bands.length) {
      _selectedBandIndex = index;
      notifyListeners();
    }
  }

  void updateSelectedBand({
    bool? enabled,
    PeqFilterType? type,
    double? fc,
    double? gainDb,
    double? q,
  }) {
    final band = _bands[_selectedBandIndex];
    if (enabled != null) band.enabled = enabled;
    if (type != null) band.type = type;
    if (fc != null) band.fc = fc.clamp(20.0, 20000.0);
    if (gainDb != null) band.gainDb = gainDb.clamp(-12.0, 12.0);
    if (q != null) band.q = q.clamp(0.1, 10.0);
    _syncBandToNative(_selectedBandIndex);
    notifyListeners();
  }

  /// Automatically adjusts Pre-Amp to -(maxPositiveGain) to prevent 0.0 dBFS digital clipping
  void autoPreamp() {
    double maxGain = 0.0;
    for (final b in _bands) {
      if (b.enabled && b.gainDb > maxGain) {
        maxGain = b.gainDb;
      }
    }
    _preAmpDb = -maxGain;
    _audioService.setPeqPreamp(_preAmpDb);
    notifyListeners();
  }

  void _syncBandToNative(int index) {
    if (index >= 0 && index < _bands.length) {
      final b = _bands[index];
      _audioService.updatePeqBand(
        index: index,
        type: b.type.index,
        fc: b.fc,
        gainDb: b.gainDb,
        q: b.q,
        enabled: b.enabled,
      );
    }
  }

  void _syncAllToNative() {
    _audioService.setPeqEnabled(_isEnabled);
    _audioService.setPeqPreamp(_preAmpDb);
    for (int i = 0; i < _bands.length; i++) {
      _syncBandToNative(i);
    }
  }

  /// Evaluates frequency response across 120 logarithmic points (20Hz to 20kHz)
  /// Returns a list of (frequency, totalGainDb) tuples.
  List<Offset> computeResponseCurve({double sampleRate = 48000.0, int points = 120}) {
    final List<Offset> response = [];
    const minFreq = 20.0;
    const maxFreq = 20000.0;
    final logMin = math.log(minFreq);
    final logMax = math.log(maxFreq);

    for (int i = 0; i < points; i++) {
      final f = math.exp(logMin + (i / (points - 1)) * (logMax - logMin));
      double totalGainDb = _isEnabled ? _preAmpDb : 0.0;

      if (_isEnabled) {
        for (final band in _bands) {
          if (!band.enabled) continue;
          totalGainDb += _evaluateBiquadGainDb(band, f, sampleRate);
        }
      }

      response.add(Offset(f, totalGainDb.clamp(-18.0, 18.0)));
    }
    return response;
  }

  /// Robert Bristow-Johnson (RBJ) Cookbook complex magnitude calculation
  double _evaluateBiquadGainDb(PeqBand band, double f, double fs) {
    if (f >= fs / 2) return 0.0;

    final omega0 = 2 * math.pi * band.fc / fs;
    final alpha = math.sin(omega0) / (2 * math.max(band.q, 0.05));
    final cosW = math.cos(omega0);
    final A = math.pow(10.0, band.gainDb / 40.0) as double;

    double b0 = 1.0, b1 = 0.0, b2 = 0.0;
    double a0 = 1.0, a1 = 0.0, a2 = 0.0;

    switch (band.type) {
      case PeqFilterType.peaking:
        b0 = 1 + alpha * A;
        b1 = -2 * cosW;
        b2 = 1 - alpha * A;
        a0 = 1 + alpha / A;
        a1 = -2 * cosW;
        a2 = 1 - alpha / A;
        break;
      case PeqFilterType.lowShelf:
        final twoSqrtAAlpha = 2 * math.sqrt(A) * alpha;
        b0 = A * ((A + 1) - (A - 1) * cosW + twoSqrtAAlpha);
        b1 = 2 * A * ((A - 1) - (A + 1) * cosW);
        b2 = A * ((A + 1) - (A - 1) * cosW - twoSqrtAAlpha);
        a0 = (A + 1) + (A - 1) * cosW + twoSqrtAAlpha;
        a1 = -2 * ((A - 1) + (A + 1) * cosW);
        a2 = (A + 1) + (A - 1) * cosW - twoSqrtAAlpha;
        break;
      case PeqFilterType.highShelf:
        final twoSqrtAAlpha = 2 * math.sqrt(A) * alpha;
        b0 = A * ((A + 1) + (A - 1) * cosW + twoSqrtAAlpha);
        b1 = -2 * A * ((A - 1) + (A + 1) * cosW);
        b2 = A * ((A + 1) + (A - 1) * cosW - twoSqrtAAlpha);
        a0 = (A + 1) - (A - 1) * cosW + twoSqrtAAlpha;
        a1 = 2 * ((A - 1) - (A + 1) * cosW);
        a2 = (A + 1) - (A - 1) * cosW - twoSqrtAAlpha;
        break;
      case PeqFilterType.lowPass:
        b0 = (1 - cosW) / 2;
        b1 = 1 - cosW;
        b2 = (1 - cosW) / 2;
        a0 = 1 + alpha;
        a1 = -2 * cosW;
        a2 = 1 - alpha;
        break;
      case PeqFilterType.highPass:
        b0 = (1 + cosW) / 2;
        b1 = -(1 + cosW);
        b2 = (1 + cosW) / 2;
        a0 = 1 + alpha;
        a1 = -2 * cosW;
        a2 = 1 - alpha;
        break;
    }

    // Normalize by a0
    b0 /= a0;
    b1 /= a0;
    b2 /= a0;
    a1 /= a0;
    a2 /= a0;

    // Evaluate complex frequency response at frequency f
    final phi = 2 * math.pi * f / fs;
    final cosPhi = math.cos(phi);
    final sinPhi = math.sin(phi);
    final cos2Phi = math.cos(2 * phi);
    final sin2Phi = math.sin(2 * phi);

    final numReal = b0 + b1 * cosPhi + b2 * cos2Phi;
    final numImag = -b1 * sinPhi - b2 * sin2Phi;
    final denReal = 1.0 + a1 * cosPhi + a2 * cos2Phi;
    final denImag = -a1 * sinPhi - a2 * sin2Phi;

    final magSq = (numReal * numReal + numImag * numImag) /
        math.max(denReal * denReal + denImag * denImag, 1e-12);

    return 10.0 * (math.log(magSq) / math.ln10);
  }

  /// Parses AutoEq / EqualizerAPO formatted profile text
  bool parseAutoEq(String text) {
    try {
      final lines = text.split('\n');
      int bandIdx = 0;

      for (final line in lines) {
        final clean = line.trim();
        if (clean.startsWith('Preamp:')) {
          final parts = clean.split(' ');
          for (final p in parts) {
            final val = double.tryParse(p);
            if (val != null) {
              _preAmpDb = val.clamp(-12.0, 12.0);
              break;
            }
          }
        } else if (clean.startsWith('Filter') && bandIdx < _bands.length) {
          // Format: Filter X: ON/OFF PK/LS/HS Fc 62 Hz Gain -1.5 dB Q 1.41
          final isEnabled = clean.contains('ON');
          PeqFilterType type = PeqFilterType.peaking;
          if (clean.contains('LS')) type = PeqFilterType.lowShelf;
          if (clean.contains('HS')) type = PeqFilterType.highShelf;
          if (clean.contains('LP')) type = PeqFilterType.lowPass;
          if (clean.contains('HP')) type = PeqFilterType.highPass;

          double fc = _bands[bandIdx].fc;
          double gain = _bands[bandIdx].gainDb;
          double q = _bands[bandIdx].q;

          final fcMatch = RegExp(r'Fc\s+([\d\.]+)').firstMatch(clean);
          if (fcMatch != null) fc = double.tryParse(fcMatch.group(1) ?? '') ?? fc;

          final gainMatch = RegExp(r'Gain\s+([-\d\.]+)').firstMatch(clean);
          if (gainMatch != null) gain = double.tryParse(gainMatch.group(1) ?? '') ?? gain;

          final qMatch = RegExp(r'Q\s+([\d\.]+)').firstMatch(clean);
          if (qMatch != null) q = double.tryParse(qMatch.group(1) ?? '') ?? q;

          _bands[bandIdx].enabled = isEnabled;
          _bands[bandIdx].type = type;
          _bands[bandIdx].fc = fc.clamp(20.0, 20000.0);
          _bands[bandIdx].gainDb = gain.clamp(-12.0, 12.0);
          _bands[bandIdx].q = q.clamp(0.1, 10.0);

          bandIdx++;
        }
      }

      _isEnabled = true;
      _syncAllToNative();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
