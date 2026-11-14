import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// LocalBridge Editorial Atelier & Tactile Bento Design System.
///
/// Provides a cohesive visual grammar across Dark (Warm Obsidian Atelier),
/// Light (Warm Alabaster Paper), and True AMOLED surfaces, paired with curated
/// architectural accents, typography tokens, corner radii, shadow elevations,
/// and a real-time 120Hz FrameTiming monitor.
@immutable
class EditorialPalette {
  final Brightness brightness;
  final bool isAmoled;
  final Color accent;
  final Color secondaryAccent;
  final Color warmHighlight;

  /// Primary background canvas
  final Color canvas;

  /// Secondary recessed or sidebar surface
  final Color surfaceRecessed;

  /// Primary card surface
  final Color card;

  /// Elevated or layered nested card surface
  final Color cardElevated;

  /// Subtle tinted decorative surface
  final Color cardTinted;

  /// Crisp editorial border color
  final Color border;

  /// Highlighted border color
  final Color borderStrong;

  /// Primary text color
  final Color ink;

  /// Secondary text color
  final Color inkSecondary;

  /// Muted caption/label text color
  final Color inkMuted;

  /// Status colors
  final Color success;
  final Color warning;
  final Color danger;

  const EditorialPalette({
    required this.brightness,
    required this.isAmoled,
    required this.accent,
    required this.secondaryAccent,
    required this.warmHighlight,
    required this.canvas,
    required this.surfaceRecessed,
    required this.card,
    required this.cardElevated,
    required this.cardTinted,
    required this.border,
    required this.borderStrong,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    this.success = const Color(0xFF1F9D6E),
    this.warning = const Color(0xFFD9822B),
    this.danger = const Color(0xFFD64545),
  });

  bool get isDark => brightness == Brightness.dark;

  /// Generates a complementary secondary studio accent from the primary accent.
  static Color deriveSecondaryAccent(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    final shiftedHue = (hsl.hue + 38.0) % 360.0;
    return hsl
        .withHue(shiftedHue)
        .withSaturation((hsl.saturation * 0.88).clamp(0.35, 0.90))
        .withLightness(hsl.lightness.clamp(0.48, 0.68))
        .toColor();
  }

  /// Generates a warm editorial highlight (terracotta / amber / sage harmony).
  static Color deriveWarmHighlight(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    final shiftedHue = (hsl.hue + 325.0) % 360.0;
    return hsl
        .withHue(shiftedHue)
        .withSaturation((hsl.saturation * 0.82).clamp(0.40, 0.85))
        .withLightness(0.62)
        .toColor();
  }

  factory EditorialPalette.fromSettings({
    required Brightness brightness,
    required Color accent,
    bool amoled = false,
  }) {
    final secondary = deriveSecondaryAccent(accent);
    final warm = deriveWarmHighlight(accent);

    if (brightness == Brightness.light) {
      return EditorialPalette(
        brightness: Brightness.light,
        isAmoled: false,
        accent: accent,
        secondaryAccent: secondary,
        warmHighlight: warm,
        canvas: const Color(0xFFF5F2EB),
        surfaceRecessed: const Color(0xFFECE7DF),
        card: const Color(0xFFFFFDF9),
        cardElevated: const Color(0xFFFFFFFF),
        cardTinted: Color.alphaBlend(
          accent.withValues(alpha: 0.06),
          const Color(0xFFFBF8F3),
        ),
        border: const Color(0xFFE0D9CE),
        borderStrong: const Color(0xFFCBBFB0),
        ink: const Color(0xFF191816),
        inkSecondary: const Color(0xFF57534C),
        inkMuted: const Color(0xFF8A8379),
        success: const Color(0xFF19875B),
        warning: const Color(0xFFC86D18),
        danger: const Color(0xFFC93838),
      );
    }

    if (amoled) {
      return EditorialPalette(
        brightness: Brightness.dark,
        isAmoled: true,
        accent: accent,
        secondaryAccent: secondary,
        warmHighlight: warm,
        canvas: const Color(0xFF000000),
        surfaceRecessed: const Color(0xFF09090B),
        card: const Color(0xFF111115),
        cardElevated: const Color(0xFF19191F),
        cardTinted: Color.alphaBlend(
          accent.withValues(alpha: 0.09),
          const Color(0xFF111115),
        ),
        border: const Color(0xFF24242C),
        borderStrong: const Color(0xFF353542),
        ink: const Color(0xFFF6F4F0),
        inkSecondary: const Color(0xFFB5B0A8),
        inkMuted: const Color(0xFF78746E),
        success: const Color(0xFF28B882),
        warning: const Color(0xFFECA13B),
        danger: const Color(0xFFEB5757),
      );
    }

    // Default Atelier Dark (Midnight Indigo-Slate matching the official LocalBridge logo)
    return EditorialPalette(
      brightness: Brightness.dark,
      isAmoled: false,
      accent: accent,
      secondaryAccent: secondary,
      warmHighlight: warm,
      canvas: const Color(0xFF070814),
      surfaceRecessed: const Color(0xFF0C0E1B),
      card: const Color(0xFF121524),
      cardElevated: const Color(0xFF181C2E),
      cardTinted: Color.alphaBlend(
        accent.withValues(alpha: 0.10),
        const Color(0xFF141828),
      ),
      border: const Color(0xFF22273B),
      borderStrong: const Color(0xFF313852),
      ink: const Color(0xFFF4F6FA),
      inkSecondary: const Color(0xFFA6B0C3),
      inkMuted: const Color(0xFF6E788E),
      success: const Color(0xFF28B882),
      warning: const Color(0xFFECA13B),
      danger: const Color(0xFFEB5757),
    );
  }

  List<BoxShadow> get cardShadow => isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: isAmoled ? 0.45 : 0.26),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF2A241D).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF2A241D).withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ];

  List<BoxShadow> accentGlow([double opacity = 0.20]) => [
        BoxShadow(
          color: accent.withValues(alpha: isDark ? opacity : opacity * 0.75),
          blurRadius: 24,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
      ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorialPalette &&
          other.brightness == brightness &&
          other.isAmoled == isAmoled &&
          other.accent == accent &&
          other.canvas == canvas &&
          other.card == card &&
          other.ink == ink;

  @override
  int get hashCode =>
      Object.hash(brightness, isAmoled, accent, canvas, card, ink);
}

/// Inherited theme carrier so any widget can read LocalBridge's EditorialPalette.
class EditorialTheme extends InheritedWidget {
  final EditorialPalette palette;

  const EditorialTheme({
    super.key,
    required this.palette,
    required super.child,
  });

  static EditorialPalette of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<EditorialTheme>();
    if (inherited != null) return inherited.palette;
    final theme = Theme.of(context);
    return EditorialPalette.fromSettings(
      brightness: theme.brightness,
      accent: theme.colorScheme.primary,
    );
  }

  @override
  bool updateShouldNotify(EditorialTheme oldWidget) =>
      oldWidget.palette != palette;
}

/// Real-time 120Hz FrameTiming Telemetry Collector.
///
/// Tracks UI build time and Raster thread time using Flutter's native
/// `SchedulerBinding.instance.addTimingsCallback` with zero allocation overhead
/// when idle.
class FrameTimingSnapshot {
  final double avgUiMs;
  final double avgRasterMs;
  final double p95TotalMs;
  final double hz120BudgetPassRate;
  final int sampleCount;

  const FrameTimingSnapshot({
    this.avgUiMs = 1.2,
    this.avgRasterMs = 1.6,
    this.p95TotalMs = 3.4,
    this.hz120BudgetPassRate = 100.0,
    this.sampleCount = 0,
  });

  double get avgTotalMs => avgUiMs + avgRasterMs;
  bool get is120HzReady => avgTotalMs <= 8.33;
}

class FrameTimingMonitor {
  FrameTimingMonitor._();
  static final FrameTimingMonitor instance = FrameTimingMonitor._();

  static const int _maxSamples = 120;
  static const double budget120HzMs = 8.33;

  final ListQueue<FrameTiming> _samples = ListQueue<FrameTiming>(_maxSamples);
  final ValueNotifier<FrameTimingSnapshot> snapshot =
      ValueNotifier<FrameTimingSnapshot>(const FrameTimingSnapshot());

  bool _attached = false;
  int _throttleCounter = 0;

  void attach() {
    if (_attached) return;
    _attached = true;
    try {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    } catch (_) {
      // Safe fallback in headless tests if binding is not initialized
      _attached = false;
    }
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    try {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    } catch (_) {}
  }

  @visibleForTesting
  void ingestTimingsForTest(List<FrameTiming> timings) {
    _onTimings(timings, forceUpdate: true);
  }

  void _onTimings(List<FrameTiming> timings, {bool forceUpdate = false}) {
    if (timings.isEmpty) return;
    for (final t in timings) {
      if (_samples.length >= _maxSamples) {
        _samples.removeFirst();
      }
      _samples.addLast(t);
    }
    _throttleCounter++;
    if (!forceUpdate && _throttleCounter % 6 != 0 && _samples.length > 6) {
      return;
    }

    final count = _samples.length;
    if (count == 0) return;

    double sumUi = 0;
    double sumRaster = 0;
    int within120Hz = 0;
    final totals = <double>[];

    for (final s in _samples) {
      final uiMs = s.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = s.rasterDuration.inMicroseconds / 1000.0;
      final totalMs = uiMs + rasterMs;
      sumUi += uiMs;
      sumRaster += rasterMs;
      totals.add(totalMs);
      if (totalMs <= budget120HzMs) {
        within120Hz++;
      }
    }

    totals.sort();
    final p95Index = ((count - 1) * 0.95).round().clamp(0, count - 1);

    snapshot.value = FrameTimingSnapshot(
      avgUiMs: sumUi / count,
      avgRasterMs: sumRaster / count,
      p95TotalMs: totals[p95Index],
      hz120BudgetPassRate: (within120Hz / count) * 100.0,
      sampleCount: count,
    );
  }
}
