import 'package:flutter/material.dart';
import 'eva_palette.dart';

/// Theme Color Accessor (ThemeExtension bridge)
/// Use `AppColors.of(context)` or `context.eva` to access active EVA palette colors.
abstract class AppColors {
  static EvaPalette of(BuildContext context) {
    return Theme.of(context).extension<EvaPalette>() ?? EvaPalette.eva01;
  }
}
