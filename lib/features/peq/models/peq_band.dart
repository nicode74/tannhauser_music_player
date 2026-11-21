/// Parametric EQ Filter Types matching RBJ Audio EQ Cookbook
enum PeqFilterType {
  peaking,
  lowShelf,
  highShelf,
  lowPass,
  highPass;

  String get label {
    switch (this) {
      case PeqFilterType.peaking:
        return 'Peaking (PK)';
      case PeqFilterType.lowShelf:
        return 'Low Shelf (LS)';
      case PeqFilterType.highShelf:
        return 'High Shelf (HS)';
      case PeqFilterType.lowPass:
        return 'Low Pass (LP)';
      case PeqFilterType.highPass:
        return 'High Pass (HP)';
    }
  }

  String get shortCode {
    switch (this) {
      case PeqFilterType.peaking:
        return 'PK';
      case PeqFilterType.lowShelf:
        return 'LS';
      case PeqFilterType.highShelf:
        return 'HS';
      case PeqFilterType.lowPass:
        return 'LP';
      case PeqFilterType.highPass:
        return 'HP';
    }
  }
}

/// Single Biquad Band Configuration
class PeqBand {
  final int index;
  bool enabled;
  PeqFilterType type;
  double fc; // 20.0 to 20000.0 Hz
  double gainDb; // -12.0 to +12.0 dB
  double q; // 0.1 to 10.0

  PeqBand({
    required this.index,
    this.enabled = true,
    this.type = PeqFilterType.peaking,
    required this.fc,
    this.gainDb = 0.0,
    this.q = 1.41,
  });

  PeqBand copyWith({
    bool? enabled,
    PeqFilterType? type,
    double? fc,
    double? gainDb,
    double? q,
  }) {
    return PeqBand(
      index: index,
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
      fc: fc ?? this.fc,
      gainDb: gainDb ?? this.gainDb,
      q: q ?? this.q,
    );
  }
}
