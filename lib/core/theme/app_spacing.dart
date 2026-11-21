import 'package:flutter/material.dart';

/// EVA-01 Spacing & Radius Tokens
abstract class AppSpacing {
  // Spacing Grid
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;

  // Insets
  static const EdgeInsets edgeXs = EdgeInsets.all(xs);
  static const EdgeInsets edgeSm = EdgeInsets.all(sm);
  static const EdgeInsets edgeMd = EdgeInsets.all(md);
  static const EdgeInsets edgeLg = EdgeInsets.all(lg);
  static const EdgeInsets edgeXl = EdgeInsets.all(xl);

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  // Radii
  static const double radiusBadge = 6.0;
  static const double radiusButton = 8.0;
  static const double radiusPanel = 12.0;

  static const BorderRadius borderBadge = BorderRadius.all(Radius.circular(radiusBadge));
  static const BorderRadius borderButton = BorderRadius.all(Radius.circular(radiusButton));
  static const BorderRadius borderPanel = BorderRadius.all(Radius.circular(radiusPanel));
}
