import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shape of the crop frame.
enum CropShape { rect, circle }

/// Pure-Flutter crop screen used on the web (and available on all platforms),
/// because `image_cropper`'s web implementation has no working "Done" button.
///
/// Pops with the cropped PNG bytes, or null if cancelled.
class CropScreen extends StatefulWidget {
  final Uint8List bytes;
  final CropShape shape;
  final double aspectRatio; // crop output width / height

  const CropScreen({
    super.key,
    required this.bytes,
    required this.shape,
    required this.aspectRatio,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  ui.Image? _img;
  final TransformationController _tc = TransformationController();
  Size _viewport = Size.zero;
  Size _child = Size.zero;
  bool _ready = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final codec =
          await ui.instantiateImageCodec(widget.bytes, targetWidth: 2048);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _img = frame.image);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _img?.dispose();
    _tc.dispose();
    super.dispose();
  }

  void _centerOn(Size viewport, Size child) {
    _viewport = viewport;
    _child = child;
    _tc.value = Matrix4.identity()
      ..setTranslationRaw(
          (viewport.width - child.width) / 2, (viewport.height - child.height) / 2, 0);
  }

  Future<void> _done() async {
    if (_saving || _img == null || _viewport == Size.zero) return;
    setState(() => _saving = true);
    try {
      final bytes = await _crop();
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not crop the photo'),
          backgroundColor: Colors.redAccent,
        ));
        setState(() => _saving = false);
      }
    }
  }

  Future<Uint8List?> _crop() async {
    final img = _img!;
    final m = _tc.value.clone();
    final inv = Matrix4.tryInvert(m);
    if (inv == null) return widget.bytes;

    final tl = MatrixUtils.transformPoint(inv, Offset.zero);
    final br = MatrixUtils.transformPoint(inv, Offset(_viewport.width, _viewport.height));
    final src = Rect.fromPoints(tl, br).intersect(
        Rect.fromLTWH(0, 0, _child.width, _child.height));
    if (src.isEmpty) return widget.bytes;

    final imgRect = Rect.fromLTWH(
      src.left / _child.width * img.width,
      src.top / _child.height * img.height,
      src.width / _child.width * img.width,
      src.height / _child.height * img.height,
    );

    const outW = 1080;
    final outH = math.max(1, (outW / widget.aspectRatio).round());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.save();
    if (widget.shape == CropShape.circle) {
      canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble())));
    }
    canvas.scale(outW / imgRect.width, outH / imgRect.height);
    canvas.translate(-imgRect.left, -imgRect.top);
    canvas.drawImage(img, Offset.zero, Paint()..filterQuality = ui.FilterQuality.high);
    canvas.restore();
    final picture = recorder.endRecording();
    final out = await picture.toImage(outW, outH);
    try {
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List() ?? widget.bytes;
    } finally {
      out.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    final img = _img;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.shape == CropShape.circle ? 'Edit Profile Photo' : 'Edit Photo',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _done,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Done',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: img == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : LayoutBuilder(builder: (context, cons) {
              final vw = cons.maxWidth;
              final vh = cons.maxHeight;
              final frame = _frameRect(vw, vh);
              final fit = math.min(frame.width / img.width,
                  frame.height / img.height);
              final childW = img.width * fit;
              final childH = img.height * fit;
              if (!_ready) {
                _ready = true;
                _centerOn(Size(frame.width, frame.height), Size(childW, childH));
              }
              return Stack(children: [
                Positioned(
                  left: frame.left,
                  top: frame.top,
                  width: frame.width,
                  height: frame.height,
                  child: ClipRect(
                    child: InteractiveViewer(
                      transformationController: _tc,
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      minScale: 0.1,
                      maxScale: 12,
                      child: SizedBox(
                        width: childW,
                        height: childH,
                        child: RawImage(
                            image: img,
                            fit: BoxFit.fill,
                            filterQuality: ui.FilterQuality.high),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CropOverlayPainter(
                        frame: frame,
                        shape: widget.shape,
                        isDark: dk,
                      ),
                    ),
                  ),
                ),
              ]);
            }),
    );
  }

  Rect _frameRect(double vw, double vh) {
    final ar = widget.aspectRatio <= 0 ? 1.0 : widget.aspectRatio;
    final maxW = vw * 0.96;
    final maxH = vh * 0.72;
    double w, h;
    if (ar >= 1) {
      w = math.min(maxW, maxH * ar);
      h = w / ar;
    } else {
      h = math.min(maxH, maxW / ar);
      w = h * ar;
    }
    return Rect.fromLTWH((vw - w) / 2, (vh - h) / 2, w, h);
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect frame;
  final CropShape shape;
  final bool isDark;

  _CropOverlayPainter({
    required this.frame,
    required this.shape,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hole = shape == CropShape.circle
        ? (Path()..addOval(frame))
        : (Path()..addRect(frame));
    final dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      hole,
    );
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.6));

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF10B981);
    canvas.drawPath(hole, borderPaint);

    if (shape == CropShape.rect) {
      final grid = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.white.withValues(alpha: 0.4);
      for (var i = 1; i < 3; i++) {
        final dx = frame.left + frame.width * i / 3;
        final dy = frame.top + frame.height * i / 3;
        canvas.drawLine(Offset(dx, frame.top), Offset(dx, frame.bottom), grid);
        canvas.drawLine(Offset(frame.left, dy), Offset(frame.right, dy), grid);
      }
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.frame != frame || old.shape != shape || old.isDark != isDark;
}
