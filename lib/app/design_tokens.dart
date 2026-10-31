/// Spacing steps: use these instead of ad-hoc numbers so screens stay calm
/// and consistent.
abstract final class AppSpacing {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner radii.
abstract final class AppRadius {
  /// Cards: soft, rounded.
  static const double card = 16;

  /// Buttons and text fields.
  static const double control = 12;
}

/// Minimum touch target sizes (see the Design section in CLAUDE.md).
abstract final class AppTapTarget {
  /// Any tappable element.
  static const double min = 48;

  /// Main buttons (filled / outlined).
  static const double mainButton = 52;
}
