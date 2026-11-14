import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../theme/editorial_theme.dart';

/// Repeating Geometric Motif Families used across LocalBridge's Editorial Bento UI.
enum EditorialMotifVariant {
  /// Overlapping double-arch bridge silhouette & gentle curves
  archBridge,

  /// Layered editorial cards / stepped diagonal blocks
  steppedCards,

  /// Soft concentric organic pebbles / pill rings
  pebbleRings,

  /// Isometric parcel & document grid motif
  parcelGrid,

  /// Warm architectural sun/horizon arch
  horizonArch,
}

/// Decorative background motif painter with cached paths and shaders for 120Hz performance.
class EditorialMotifPainter extends CustomPainter {
  final EditorialMotifVariant variant;
  final Color primary;
  final Color secondary;
  final Color warm;
  final double opacity;

  const EditorialMotifPainter({
    required this.variant,
    required this.primary,
    required this.secondary,
    required this.warm,
    this.opacity = 0.14,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;

    switch (variant) {
      case EditorialMotifVariant.archBridge:
        // Soft architectural arches in top-right and bottom-right
        final archRect1 = Rect.fromCenter(
          center: Offset(w * 0.86, h * 0.92),
          width: w * 0.54,
          height: h * 1.15,
        );
        fillPaint.color = primary.withValues(alpha: opacity * 0.55);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            archRect1,
            topLeft: const Radius.circular(140),
            topRight: const Radius.circular(140),
          ),
          fillPaint,
        );

        final archRect2 = Rect.fromCenter(
          center: Offset(w * 0.94, h * 0.62),
          width: w * 0.36,
          height: h * 0.95,
        );
        fillPaint.color = secondary.withValues(alpha: opacity * 0.45);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            archRect2,
            topLeft: const Radius.circular(110),
            topRight: const Radius.circular(110),
          ),
          fillPaint,
        );

        strokePaint.color = warm.withValues(alpha: opacity * 0.95);
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(w * 0.85, h * 0.88),
            width: w * 0.42,
            height: h * 0.86,
          ),
          math.pi,
          math.pi,
          false,
          strokePaint,
        );
        break;

      case EditorialMotifVariant.steppedCards:
        // Layered tilted paper sheets motif
        canvas.save();
        canvas.translate(w * 0.82, h * 0.52);
        canvas.rotate(-0.14);
        fillPaint.color = secondary.withValues(alpha: opacity * 0.45);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: const Offset(-14, 10),
              width: w * 0.28,
              height: h * 0.68,
            ),
            const Radius.circular(18),
          ),
          fillPaint,
        );
        canvas.rotate(0.22);
        fillPaint.color = primary.withValues(alpha: opacity * 0.60);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: const Offset(8, -4),
              width: w * 0.28,
              height: h * 0.68,
            ),
            const Radius.circular(18),
          ),
          fillPaint,
        );
        strokePaint.color = warm.withValues(alpha: opacity * 0.90);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: const Offset(18, -12),
              width: w * 0.24,
              height: h * 0.58,
            ),
            const Radius.circular(16),
          ),
          strokePaint,
        );
        canvas.restore();
        break;

      case EditorialMotifVariant.pebbleRings:
        // Warm organic pill rings and offset circle
        final c = Offset(w * 0.88, h * 0.28);
        fillPaint.color = primary.withValues(alpha: opacity * 0.48);
        canvas.drawCircle(c, math.min(w, h) * 0.34, fillPaint);

        fillPaint.color = warm.withValues(alpha: opacity * 0.38);
        canvas.drawCircle(
          Offset(w * 0.76, h * 0.72),
          math.min(w, h) * 0.22,
          fillPaint,
        );

        strokePaint.color = secondary.withValues(alpha: opacity * 0.85);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(w * 0.84, h * 0.50),
              width: w * 0.32,
              height: h * 0.64,
            ),
            const Radius.circular(999),
          ),
          strokePaint,
        );
        break;

      case EditorialMotifVariant.parcelGrid:
        // Subtle editorial bento grid ticks and rounded blocks
        final blockW = math.min(w * 0.14, 48.0);
        final startX = w - blockW * 2.5 - 12;
        final startY = 14.0;
        for (int r = 0; r < 2; r++) {
          for (int cIdx = 0; cIdx < 2; cIdx++) {
            final rect = Rect.fromLTWH(
              startX + cIdx * (blockW + 8),
              startY + r * (blockW * 0.75 + 8),
              blockW,
              blockW * 0.75,
            );
            if ((r + cIdx) % 2 == 0) {
              fillPaint.color = primary.withValues(alpha: opacity * 0.52);
              canvas.drawRRect(
                RRect.fromRectAndRadius(rect, const Radius.circular(10)),
                fillPaint,
              );
            } else {
              strokePaint.color = secondary.withValues(alpha: opacity * 0.82);
              canvas.drawRRect(
                RRect.fromRectAndRadius(rect, const Radius.circular(10)),
                strokePaint,
              );
            }
          }
        }
        break;

      case EditorialMotifVariant.horizonArch:
        // Warm editorial sun disc + bridge horizon line
        final sunCenter = Offset(w * 0.84, h * 0.38);
        final radius = math.min(w, h) * 0.28;
        fillPaint.color = warm.withValues(alpha: opacity * 0.55);
        canvas.drawCircle(sunCenter, radius, fillPaint);

        final path = Path()
          ..moveTo(w * 0.54, h * 0.78)
          ..quadraticBezierTo(w * 0.76, h * 0.42, w * 0.98, h * 0.78);
        strokePaint
          ..color = primary.withValues(alpha: opacity * 0.95)
          ..strokeWidth = 2.0;
        canvas.drawPath(path, strokePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant EditorialMotifPainter oldDelegate) {
    return oldDelegate.variant != variant ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.warm != warm ||
        oldDelegate.opacity != opacity;
  }
}

/// Ambient Studio Canvas Background Painter.
///
/// Renders soft, warm architectural shapes and subtle editorial grid lines
/// with cached shaders so `paint` performs zero heap allocations when static.
class StudioCanvasBackgroundPainter extends CustomPainter {
  final EditorialPalette palette;

  StudioCanvasBackgroundPainter({required this.palette});

  Size? _cachedSize;
  Color? _cachedAccent;
  Brightness? _cachedBrightness;
  Shader? _topGlowShader;
  Shader? _bottomWarmShader;

  void _ensureShaders(Size size) {
    if (_cachedSize == size &&
        _cachedAccent == palette.accent &&
        _cachedBrightness == palette.brightness &&
        _topGlowShader != null &&
        _bottomWarmShader != null) {
      return;
    }
    _cachedSize = size;
    _cachedAccent = palette.accent;
    _cachedBrightness = palette.brightness;

    final topCenter = Offset(size.width * 0.78, size.height * 0.12);
    final topRadius = size.shortestSide * 0.72;
    _topGlowShader = RadialGradient(
      colors: [
        palette.accent.withValues(alpha: palette.isDark ? 0.11 : 0.08),
        palette.secondaryAccent.withValues(alpha: palette.isDark ? 0.04 : 0.03),
        Colors.transparent,
      ],
      stops: const [0.0, 0.52, 1.0],
    ).createShader(Rect.fromCircle(center: topCenter, radius: topRadius));

    final bottomCenter = Offset(size.width * 0.18, size.height * 0.88);
    final bottomRadius = size.shortestSide * 0.68;
    _bottomWarmShader = RadialGradient(
      colors: [
        palette.warmHighlight.withValues(alpha: palette.isDark ? 0.08 : 0.06),
        palette.secondaryAccent.withValues(alpha: palette.isDark ? 0.03 : 0.02),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: bottomCenter, radius: bottomRadius));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _ensureShaders(size);

    final glowPaint = Paint()..shader = _topGlowShader;
    canvas.drawRect(Offset.zero & size, glowPaint);

    glowPaint.shader = _bottomWarmShader;
    canvas.drawRect(Offset.zero & size, glowPaint);

    // Subtle architectural framing arcs in corners
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = palette.border.withValues(alpha: palette.isDark ? 0.32 : 0.48);

    final archRadius = math.min(size.width, size.height) * 0.42;
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.08),
      archRadius,
      linePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.08),
      archRadius * 0.68,
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant StudioCanvasBackgroundPainter oldDelegate) {
    return oldDelegate.palette != palette;
  }
}

/// Static range rings, compass ticks, and connections on the discovery radar.
class AtelierBridgeCanvasPainter extends CustomPainter {
  final Color accent;
  final Color secondaryAccent;
  final Color warmHighlight;
  final Color borderColor;
  final bool isDark;
  final bool isOnline;
  final List<Offset> devicePositions;
  final Offset? selectedPosition;

  const AtelierBridgeCanvasPainter({
    required this.accent,
    required this.secondaryAccent,
    required this.warmHighlight,
    required this.borderColor,
    required this.isDark,
    required this.isOnline,
    required this.devicePositions,
    this.selectedPosition,
  });

  static final List<Offset> _unitTicks = List<Offset>.generate(
    24,
    (t) {
      final ang = t * (math.pi * 2 / 24);
      return Offset(math.cos(ang), math.sin(ang));
    },
    growable: false,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide * 0.44;
    final mat = Rect.fromCircle(center: center, radius: maxR * 1.12);
    final matPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: isOnline ? (isDark ? 0.20 : 0.14) : 0.06),
          secondaryAccent.withValues(
            alpha: isOnline ? (isDark ? 0.08 : 0.05) : 0.02,
          ),
          Colors.transparent,
        ],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(mat);
    canvas.drawCircle(center, mat.width / 2, matPaint);

    // 2. Concentric radar range rings (3 rings) + outer compass ticks
    final ringStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;

    for (int i = 3; i >= 1; i--) {
      final factor = i / 3.0;
      final r = maxR * factor;
      ringStroke.color = i == 3
          ? accent.withValues(alpha: isOnline ? (isDark ? 0.34 : 0.28) : 0.18)
          : borderColor.withValues(alpha: isDark ? 0.55 : 0.70);
      canvas.drawCircle(center, r, ringStroke);
    }

    // Crosshair axis ticks (subtle studio precision guides)
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = borderColor.withValues(alpha: isDark ? 0.35 : 0.45);
    canvas.drawLine(
      Offset(center.dx - maxR, center.dy),
      Offset(center.dx + maxR, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxR),
      Offset(center.dx, center.dy + maxR),
      axisPaint,
    );

    // 24 outer degree ticks around perimeter ring (precomputed unit vectors)
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final majorColor = accent.withValues(alpha: isOnline ? 0.45 : 0.22);
    final minorColor = borderColor.withValues(alpha: isDark ? 0.45 : 0.55);
    for (int t = 0; t < 24; t++) {
      final u = _unitTicks[t];
      final isMajor = t % 6 == 0;
      final inner = maxR - (isMajor ? 7.0 : 4.0);
      tickPaint.color = isMajor ? majorColor : minorColor;
      canvas.drawLine(
        center + u * inner,
        center + u * maxR,
        tickPaint,
      );
    }

    // 3. Subtle architectural bridge silhouette in background
    final archPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: isOnline ? 0.22 : 0.14);
    final spanW = maxR * 1.40;
    final archPath = Path()
      ..moveTo(center.dx - spanW * 0.5, center.dy + 16)
      ..quadraticBezierTo(
        center.dx,
        center.dy - maxR * 0.42,
        center.dx + spanW * 0.5,
        center.dy + 16,
      );
    canvas.drawPath(archPath, archPaint);

    if (isOnline) {
      final beam = Paint();
      for (final pos in devicePositions) {
        final selected = pos == selectedPosition;
        beam
          ..strokeWidth = selected ? 2.2 : 1.4
          ..color = selected
              ? accent.withAlpha(191)
              : warmHighlight.withAlpha(107);
        canvas.drawLine(center, pos, beam);
      }
    }
  }

  @override
  bool shouldRepaint(covariant AtelierBridgeCanvasPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.secondaryAccent != secondaryAccent ||
      oldDelegate.warmHighlight != warmHighlight ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.isDark != isDark ||
      oldDelegate.isOnline != isOnline ||
      oldDelegate.selectedPosition != selectedPosition ||
      !listEquals(oldDelegate.devicePositions, devicePositions);
}

/// Animated sweep, sonar rings, and packets drawn only during discovery.
class RadarSweepPainter extends CustomPainter {
  final Animation<double> phase;
  final Color accent;
  final Color warmHighlight;
  final List<Offset> devicePositions;
  final Offset? selectedPosition;

  RadarSweepPainter({
    required this.phase,
    required this.accent,
    required this.warmHighlight,
    required this.devicePositions,
    this.selectedPosition,
  }) : super(repaint: phase);

  static const _sectorSpan = math.pi * 0.42;
  final _wave = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final _sector = Paint();
  late final _arm = Paint()
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..color = accent.withAlpha(184);
  late final _tip = Paint()..color = accent;
  late final _beacon = Paint()..color = accent.withAlpha(61);
  late final _selectedPacket = Paint()..color = accent.withAlpha(230);
  late final _packet = Paint()..color = warmHighlight.withAlpha(230);
  double? _radius;
  Rect _sectorBounds = Rect.zero;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.44;
    if (radius != _radius) {
      _radius = radius;
      _sectorBounds = Rect.fromCircle(center: Offset.zero, radius: radius);
      _sector.shader = SweepGradient(
        endAngle: _sectorSpan,
        colors: [
          accent.withAlpha(0),
          warmHighlight.withAlpha(36),
          accent.withAlpha(82),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(_sectorBounds);
    }

    final progress = phase.value;
    for (var i = 0; i < 2; i++) {
      final wave = (progress + i * 0.5) % 1.0;
      _wave.color = accent.withValues(alpha: (1.0 - wave) * 0.46);
      canvas.drawCircle(center, radius * (0.18 + wave * 0.82), _wave);
    }

    final angle = progress * 2 * math.pi - math.pi / 2;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle - _sectorSpan);
    canvas.drawArc(_sectorBounds, 0, _sectorSpan, true, _sector);
    canvas.restore();

    final tip = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawLine(center, tip, _arm);
    canvas.drawCircle(tip, 6.5, _beacon);
    canvas.drawCircle(tip, 2.8, _tip);

    for (final pos in devicePositions) {
      final selected = pos == selectedPosition;
      canvas.drawCircle(
        center + (pos - center) * progress,
        selected ? 3.2 : 2.4,
        selected ? _selectedPacket : _packet,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadarSweepPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.accent != accent ||
      oldDelegate.warmHighlight != warmHighlight ||
      oldDelegate.selectedPosition != selectedPosition ||
      !listEquals(oldDelegate.devicePositions, devicePositions);
}

/// Custom-drawn layered file category badge & illustration.
enum EditorialFileKind {
  image,
  video,
  audio,
  archive,
  document,
  code,
  generic,
}

EditorialFileKind classifyEditorialFile(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot != -1 ? fileName.substring(dot + 1).toLowerCase() : '';
  if (const {'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp', 'heic'}
      .contains(ext)) {
    return EditorialFileKind.image;
  }
  if (const {'mp4', 'mkv', 'mov', 'avi', 'webm', 'm4v'}.contains(ext)) {
    return EditorialFileKind.video;
  }
  if (const {'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'}.contains(ext)) {
    return EditorialFileKind.audio;
  }
  if (const {'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'iso'}.contains(ext)) {
    return EditorialFileKind.archive;
  }
  if (const {'pdf', 'doc', 'docx', 'txt', 'md', 'rtf', 'xls', 'xlsx', 'ppt', 'pptx'}
      .contains(ext)) {
    return EditorialFileKind.document;
  }
  if (const {'dart', 'py', 'js', 'ts', 'json', 'html', 'css', 'cpp', 'c', 'rs', 'go'}
      .contains(ext)) {
    return EditorialFileKind.code;
  }
  return EditorialFileKind.generic;
}

class EditorialFileIllustration extends StatelessWidget {
  final String fileName;
  final double size;

  const EditorialFileIllustration({
    super.key,
    required this.fileName,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final kind = classifyEditorialFile(fileName);
    final palette = EditorialTheme.of(context);
    final (Color primary, Color secondary, IconData glyph) = switch (kind) {
      EditorialFileKind.image => (
          const Color(0xFFE06D53),
          const Color(0xFFF3A871),
          Icons.palette_rounded
        ),
      EditorialFileKind.video => (
          const Color(0xFF8B6CEF),
          const Color(0xFFC19BF5),
          Icons.movie_filter_rounded
        ),
      EditorialFileKind.audio => (
          const Color(0xFFD9822B),
          const Color(0xFFF2B866),
          Icons.graphic_eq_rounded
        ),
      EditorialFileKind.archive => (
          const Color(0xFF289D8F),
          const Color(0xFF68C7BB),
          Icons.inventory_2_rounded
        ),
      EditorialFileKind.document => (
          palette.accent,
          palette.secondaryAccent,
          Icons.description_rounded
        ),
      EditorialFileKind.code => (
          const Color(0xFF3A86FF),
          const Color(0xFF72A8FF),
          Icons.terminal_rounded
        ),
      EditorialFileKind.generic => (
          palette.accent,
          palette.warmHighlight,
          Icons.insert_drive_file_rounded
        ),
    };

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Back tilted sheet
            Transform.rotate(
              angle: -0.10,
              child: Container(
                width: size * 0.78,
                height: size * 0.86,
                decoration: BoxDecoration(
                  color: secondary.withValues(alpha: palette.isDark ? 0.20 : 0.24),
                  borderRadius: BorderRadius.circular(size * 0.24),
                ),
              ),
            ),
            // Front crisp card with dog-ear accent
            Container(
              width: size * 0.84,
              height: size * 0.88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary.withValues(alpha: palette.isDark ? 0.26 : 0.18),
                    primary.withValues(alpha: palette.isDark ? 0.12 : 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(size * 0.25),
                border: Border.all(
                  color: primary.withValues(alpha: 0.38),
                  width: 1.1,
                ),
              ),
              child: Icon(
                glyph,
                size: size * 0.44,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decorative Editorial Surface Card with optional geometric motif overlay,
/// layered border, and crisp studio elevation.
class EditorialSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final EditorialMotifVariant? motif;
  final double motifOpacity;
  final Color? backgroundColor;
  final Color? borderColor;
  final Gradient? gradient;
  final bool elevated;

  const EditorialSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.motif,
    this.motifOpacity = 0.12,
    this.backgroundColor,
    this.borderColor,
    this.gradient,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final bg = backgroundColor ?? (elevated ? p.cardElevated : p.card);
    final bColor = borderColor ?? p.border;

    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: bColor, width: 1.0),
        boxShadow: elevated ? p.cardShadow : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: Stack(
          children: [
            if (motif != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: EditorialMotifPainter(
                        variant: motif!,
                        primary: p.accent,
                        secondary: p.secondaryAccent,
                        warm: p.warmHighlight,
                        opacity: motifOpacity,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Editorial Section Pill Tag (used above bento headers for strong typographic hierarchy).
class EditorialKickerPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;

  const EditorialKickerPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final c = color ?? p.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: p.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom-drawn abstract parcel & bridge illustration for Empty States & Launchpads.
class EditorialLaunchpadIllustration extends StatelessWidget {
  final Color accent;
  final Color secondary;
  final Color warm;
  final double size;

  const EditorialLaunchpadIllustration({
    super.key,
    required this.accent,
    required this.secondary,
    required this.warm,
    this.size = 84,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _LaunchpadIllustrationPainter(
          accent: accent,
          secondary: secondary,
          warm: warm,
        ),
      ),
    );
  }
}

class _LaunchpadIllustrationPainter extends CustomPainter {
  final Color accent;
  final Color secondary;
  final Color warm;

  const _LaunchpadIllustrationPainter({
    required this.accent,
    required this.secondary,
    required this.warm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Warm sun disc
    fill.color = warm.withValues(alpha: 0.22);
    canvas.drawCircle(Offset(w * 0.70, h * 0.28), w * 0.22, fill);

    // Back tilted card
    canvas.save();
    canvas.translate(w * 0.42, h * 0.52);
    canvas.rotate(-0.18);
    fill.color = secondary.withValues(alpha: 0.24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.48, height: h * 0.56),
        const Radius.circular(14),
      ),
      fill,
    );
    canvas.restore();

    // Front main editorial parcel card
    final cardRect = Rect.fromCenter(
      center: Offset(w * 0.52, h * 0.56),
      width: w * 0.54,
      height: h * 0.58,
    );
    fill.color = accent.withValues(alpha: 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, const Radius.circular(16)),
      fill,
    );
    stroke.color = accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, const Radius.circular(16)),
      stroke,
    );

    // Bridge arch inside the card
    final archPath = Path()
      ..moveTo(w * 0.35, h * 0.66)
      ..quadraticBezierTo(w * 0.52, h * 0.40, w * 0.69, h * 0.66);
    stroke.color = warm;
    canvas.drawPath(archPath, stroke);

    // Upward dispatch arrow
    stroke.color = accent;
    canvas.drawLine(
      Offset(w * 0.52, h * 0.62),
      Offset(w * 0.52, h * 0.38),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.44, h * 0.46),
      Offset(w * 0.52, h * 0.38),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.60, h * 0.46),
      Offset(w * 0.52, h * 0.38),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LaunchpadIllustrationPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary ||
        oldDelegate.warm != warm;
  }
}
