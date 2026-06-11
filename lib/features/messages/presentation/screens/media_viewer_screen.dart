import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../yapp_design.dart';

enum _ViewerKind { image, video, location }

class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen._({
    required _ViewerKind kind,
    this.bytes,
    this.caption,
    this.mime,
    this.fileName,
    this.metaLabel,
    this.lat,
    this.lng,
  }) : _kind = kind;

  factory MediaViewerScreen.image({
    required Uint8List bytes,
    String? caption,
    String? mime,
    String? fileName,
  }) => MediaViewerScreen._(
    kind: _ViewerKind.image,
    bytes: bytes,
    caption: caption,
    mime: mime,
    fileName: fileName,
  );

  factory MediaViewerScreen.video({
    required Uint8List bytes,
    String? caption,
    String? mime,
    String? fileName,
    String? metaLabel,
  }) => MediaViewerScreen._(
    kind: _ViewerKind.video,
    bytes: bytes,
    caption: caption,
    mime: mime,
    fileName: fileName,
    metaLabel: metaLabel,
  );

  factory MediaViewerScreen.location({
    required double lat,
    required double lng,
    String? caption,
  }) => MediaViewerScreen._(
    kind: _ViewerKind.location,
    lat: lat,
    lng: lng,
    caption: caption,
  );

  final _ViewerKind _kind;
  final Uint8List? bytes;
  final String? caption;
  final String? mime;
  final String? fileName;
  final String? metaLabel;
  final double? lat;
  final double? lng;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen>
    with SingleTickerProviderStateMixin {
  static const Color _paper = Color(0xFFFFFFFF);
  static const Color _ink = Color(0xFF0A0A0A);

  static const Color _alert = Color(0xFFFF3B30);

  static const double _dismissThreshold = 130;

  bool _busy = false;
  bool _chrome = true;

  double _drag = 0;
  final TransformationController _zoom = TransformationController();
  bool _zoomed = false;

  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  Animation<double>? _springAnim;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoomChanged);
  }

  void _onZoomChanged() {
    final scale = _zoom.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.02;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  @override
  void dispose() {
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    _spring.dispose();
    super.dispose();
  }

  bool get _dragEnabled => !_zoomed;

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dragEnabled) return;
    setState(() {
      _drag += d.delta.dy;
      if (_drag < 0) _drag *= 0.4;
      if (_chrome && _drag.abs() > 6) _chrome = false;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_dragEnabled) return;
    final v = d.velocity.pixelsPerSecond.dy;
    if (_drag > _dismissThreshold || v > 700) {
      Navigator.of(context).maybePop();
      return;
    }
    _springBack();
  }

  void _springBack() {
    _springAnim = Tween<double>(begin: _drag, end: 0).animate(
      CurvedAnimation(parent: _spring, curve: Curves.easeOutBack),
    )..addListener(() => setState(() => _drag = _springAnim!.value));
    _spring.forward(from: 0);
  }

  void _toggleChrome() {
    HapticFeedback.selectionClick();
    setState(() => _chrome = !_chrome);
  }

  double get _dragProgress => (_drag.abs() / 320).clamp(0.0, 1.0);

  Future<File> _writeTemp(String suffix, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final safe = suffix.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/yapp_view_$safe');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _shareOrOpen() async {
    final bytes = widget.bytes;
    if (bytes == null || _busy) return;
    setState(() => _busy = true);
    try {
      final name =
          widget.fileName ??
          (widget._kind == _ViewerKind.video ? 'video.mp4' : 'image.jpg');
      final file = await _writeTemp(name, bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: widget.mime, name: name)],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('could not open file')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMaps() async {
    final lat = widget.lat, lng = widget.lng;
    if (lat == null || lng == null) return;
    final geo = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final web = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      if (await launchUrl(geo, mode: LaunchMode.externalApplication)) return;
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('could not open maps')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.caption?.trim();
    final stageScale = 1 - _dragProgress * 0.18;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleChrome,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: Stack(
          children: [
            if (widget._kind == _ViewerKind.image && widget.bytes != null)
              Positioned.fill(
                child: Opacity(
                  opacity: (1 - _dragProgress).clamp(0.0, 1.0),
                  child: _AmbientBackdrop(bytes: widget.bytes!),
                ),
              ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: Transform.scale(scale: stageScale, child: _body()),
              ),
            ),
            _Scrim(visible: _chrome, top: true),
            _Scrim(visible: _chrome, top: false),
            _topChrome(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _bottomChrome(caption),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topChrome() {
    final showShare = widget._kind == _ViewerKind.image && widget.bytes != null;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: IgnorePointer(
          ignoring: !_chrome,
          child: AnimatedSlide(
            duration: Yapp.dur,
            curve: Yapp.curve,
            offset: _chrome ? Offset.zero : const Offset(0, -1.4),
            child: AnimatedOpacity(
              duration: Yapp.dur,
              opacity: _chrome ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    _GlassButton(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Icon(
                        Icons.close_rounded,
                        color: _paper,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    if (showShare)
                      _GlassButton(
                        width: 76,
                        onTap: _shareOrOpen,
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _paper,
                                  ),
                                ),
                              )
                            : Text(
                                'share',
                                style: Yapp.cta(
                                  color: _paper,
                                ).copyWith(fontSize: 14),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (widget._kind) {
      case _ViewerKind.image:
        return InteractiveViewer(
          transformationController: _zoom,
          minScale: 1,
          maxScale: 5,
          panEnabled: _zoomed,
          child: Center(
            child: widget.bytes == null
                ? const _ViewerError()
                : Image.memory(
                    widget.bytes!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const _ViewerError(),
                  ),
          ),
        );
      case _ViewerKind.video:
        return Center(
          child: _PlayStamp(
            busy: _busy,
            label: widget.metaLabel ?? 'video',
            onTap: _shareOrOpen,
          ),
        );
      case _ViewerKind.location:
        return CustomPaint(
          painter: _MapGridPainter(
            line: _paper.withValues(alpha: 0.14),
            pin: _alert,
          ),
          child: const SizedBox.expand(),
        );
    }
  }

  Widget _bottomChrome(String? caption) {
    final action = _primaryAction();
    final hasCaption = caption != null && caption.isNotEmpty;
    if (!hasCaption && action == null) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: !_chrome,
      child: AnimatedSlide(
        duration: Yapp.dur,
        curve: Yapp.curve,
        offset: _chrome ? Offset.zero : const Offset(0, 1.4),
        child: AnimatedOpacity(
          duration: Yapp.dur,
          opacity: _chrome ? 1 : 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasCaption)
                    _GlassPanel(
                      child: Text(
                        caption.toLowerCase(),
                        style: Yapp.bubble(
                          color: _paper,
                        ).copyWith(fontSize: 15, height: 1.35),
                        textDirection: Yapp.dirFor(caption),
                      ),
                    ),
                  if (hasCaption && action != null) const SizedBox(height: 10),
                  ?action,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _primaryAction() {
    switch (widget._kind) {
      case _ViewerKind.image:
        return null;
      case _ViewerKind.video:
        return _StampAction(
          label: 'play in player',
          busy: _busy,
          onTap: _shareOrOpen,
        );
      case _ViewerKind.location:
        final coords = (widget.lat != null && widget.lng != null)
            ? '${widget.lat!.toStringAsFixed(5)}, '
                  '${widget.lng!.toStringAsFixed(5)}'
            : 'location unavailable';
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GlassPanel(
              child: Row(
                children: [
                  Container(width: 10, height: 10, color: _alert),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(coords, style: Yapp.bubble(color: _paper)),
                  ),
                ],
              ),
            ),
            if (widget.lat != null && widget.lng != null) ...[
              const SizedBox(height: 10),
              _StampAction(
                label: 'open in maps',
                busy: false,
                onTap: _openMaps,
              ),
            ],
          ],
        );
    }
  }
}

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 55, sigmaY: 55),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
            ),
            const ColoredBox(color: Color(0x99000000)),
          ],
        ),
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.visible, required this.top});
  final bool visible;
  final bool top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: Yapp.dur,
          opacity: visible ? 1 : 0,
          child: Container(
            height: top ? 160 : 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: const [Color(0x88000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.child,
    required this.onTap,
    this.width = 44,
  });
  final Widget child;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: width,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StampAction extends StatefulWidget {
  const _StampAction({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_StampAction> createState() => _StampActionState();
}

class _StampActionState extends State<_StampAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const alert = _MediaViewerScreenState._alert;
    const paper = _MediaViewerScreenState._paper;
    final bg = _pressed ? paper : alert;
    final fg = _pressed ? alert : paper;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        height: 56,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: widget.busy
            ? Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.label, style: Yapp.cta(color: fg)),
                  YappGlyph.forward(color: fg, size: 18),
                ],
              ),
      ),
    );
  }
}

class _PlayStamp extends StatelessWidget {
  const _PlayStamp({
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const paper = _MediaViewerScreenState._paper;
    const ink = _MediaViewerScreenState._ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            color: paper,
            child: busy
                ? const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(ink),
                      ),
                    ),
                  )
                : const CustomPaint(painter: _PlayTrianglePainter(color: ink)),
          ),
          const SizedBox(height: 16),
          Text(
            label.toLowerCase(),
            style: Yapp.label(
              color: paper,
            ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}

class _PlayTrianglePainter extends CustomPainter {
  const _PlayTrianglePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.36, h * 0.28)
      ..lineTo(w * 0.36, h * 0.72)
      ..lineTo(w * 0.72, h * 0.50)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PlayTrianglePainter old) => old.color != color;
}

class _ViewerError extends StatelessWidget {
  const _ViewerError();
  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, color: Color(0xFFFFFFFF), size: 36),
        SizedBox(height: 10),
        Text(
          "couldn't load",
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter({required this.line, required this.pin});
  final Color line;
  final Color pin;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = line
      ..strokeWidth = 1;
    const step = 44.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawCircle(
      Offset(cx, cy),
      40,
      Paint()
        ..color = pin.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
    final fill = Paint()
      ..color = pin
      ..style = PaintingStyle.fill;
    const s = 26.0;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy - 10), width: s, height: s),
      fill,
    );
    final stem = Path()
      ..moveTo(cx - 11, cy + 3)
      ..lineTo(cx + 11, cy + 3)
      ..lineTo(cx, cy + 26)
      ..close();
    canvas.drawPath(stem, fill);
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => old.line != line || old.pin != pin;
}
