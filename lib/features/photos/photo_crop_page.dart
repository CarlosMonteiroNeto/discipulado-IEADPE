import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;

import '../../data/supabase_gateway.dart';
import 'photo_crop.dart';

/// Full-screen square framing surface; it returns only a confirmed crop value.
class PhotoCropPage extends StatefulWidget {
  const PhotoCropPage({super.key, required this.source});

  final Uint8List source;

  @override
  State<PhotoCropPage> createState() => _PhotoCropPageState();
}

class _PhotoCropPageState extends State<PhotoCropPage> {
  static const double _maximumPreviewDimension = 1600;
  static const double _maximumViewportDimension = 480;
  static const double _minimumViewportDimension = 220;

  final TransformationController _transform = TransformationController();
  final FocusNode _viewportFocus = FocusNode(debugLabel: 'photo-crop-viewport');
  late final Uint8List _previewBytes;
  late final int _previewWidth;
  late final int _previewHeight;
  late final int _sourceWidth;
  late final int _sourceHeight;
  late final String? _errorMessage;
  bool _initialized = false;
  bool _interacting = false;
  double _viewportSize = 0;
  double _fitScale = 1;
  double _gestureScale = 1;
  Offset _gestureAnchor = Offset.zero;
  Offset _gestureTranslation = Offset.zero;
  Offset _gestureFocal = Offset.zero;
  double _gestureDistance = 0;
  final Map<int, Offset> _pointers = {};

  @override
  void initState() {
    super.initState();
    try {
      _initializePreview();
      _errorMessage = null;
    } catch (_) {
      _previewBytes = Uint8List(0);
      _previewWidth = 1;
      _previewHeight = 1;
      _sourceWidth = 1;
      _sourceHeight = 1;
      _errorMessage = 'Não foi possível abrir esta imagem.';
    }
  }

  void _initializePreview() {
    final oriented = _decodeOriented(widget.source);
    final ratio = math.min(
      1.0,
      _maximumPreviewDimension / math.max(oriented.width, oriented.height),
    );
    final previewWidth = math.max(1, (oriented.width * ratio).round());
    final previewHeight = math.max(1, (oriented.height * ratio).round());
    final preview = image.copyResize(
      oriented,
      width: previewWidth,
      height: previewHeight,
      interpolation: image.Interpolation.linear,
    );
    final previewBytes = Uint8List.fromList(image.encodePng(preview));
    _sourceWidth = oriented.width;
    _sourceHeight = oriented.height;
    _previewWidth = previewWidth;
    _previewHeight = previewHeight;
    _previewBytes = previewBytes;
  }

  image.Image _decodeOriented(Uint8List bytes) {
    try {
      if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
        throw const DataFailure('invalid');
      }
      final decoder = image.findDecoderForData(bytes);
      final info = decoder?.startDecode(bytes);
      if (info == null ||
          !isSupportedProfilePhotoDimensions(info.width, info.height)) {
        throw const DataFailure('invalid');
      }
      final decoded = decoder!.decodeFrame(0);
      if (decoded == null ||
          !isSupportedProfilePhotoDimensions(decoded.width, decoded.height)) {
        throw const DataFailure('invalid');
      }
      return image.bakeOrientation(decoded);
    } on DataFailure {
      rethrow;
    } catch (_) {
      throw const DataFailure('invalid');
    }
  }

  Matrix4 _initialTransform(double viewport) {
    final scale = math.max(viewport / _previewWidth, viewport / _previewHeight);
    final dx = (viewport - _previewWidth * scale) / 2;
    final dy = (viewport - _previewHeight * scale) / 2;
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
  }

  void _configureViewport(double size) {
    if (size <= 0 || (_initialized && size == _viewportSize)) return;
    if (!_initialized) {
      _transform.value = _initialTransform(size);
      _initialized = true;
    } else {
      final oldCrop = _currentCrop();
      final nextScale =
          size / (oldCrop.size * math.min(_previewWidth, _previewHeight));
      final dx = -(oldCrop.left * _previewWidth) * nextScale;
      final dy = -(oldCrop.top * _previewHeight) * nextScale;
      _transform.value = Matrix4.identity()
        ..setEntry(0, 0, nextScale)
        ..setEntry(1, 1, nextScale)
        ..setEntry(0, 3, dx)
        ..setEntry(1, 3, dy);
    }
    _viewportSize = size;
    _fitScale = math.max(size / _previewWidth, size / _previewHeight);
  }

  NormalizedPhotoCrop _currentCrop() {
    final matrix = _transform.value;
    final scale = matrix.entry(0, 0);
    final left = -matrix.entry(0, 3) / scale / _previewWidth;
    final top = -matrix.entry(1, 3) / scale / _previewHeight;
    final size =
        _viewportSize / scale / math.min(_previewWidth, _previewHeight);
    final boundedSize = size.clamp(0.000001, 1.0);
    final sourceSide = (boundedSize * math.min(_sourceWidth, _sourceHeight))
        .round();
    final maximumLeft = (_sourceWidth - sourceSide) / _sourceWidth;
    final maximumTop = (_sourceHeight - sourceSide) / _sourceHeight;
    return NormalizedPhotoCrop(
      left: left.clamp(0.0, maximumLeft),
      top: top.clamp(0.0, maximumTop),
      size: boundedSize,
    );
  }

  void _nudge(double dx, double dy) {
    final matrix = _transform.value.clone();
    final scale = matrix.entry(0, 0);
    final minX = _viewportSize - _previewWidth * scale;
    final minY = _viewportSize - _previewHeight * scale;
    matrix.setEntry(0, 3, (matrix.entry(0, 3) + dx).clamp(minX, 0.0));
    matrix.setEntry(1, 3, (matrix.entry(1, 3) + dy).clamp(minY, 0.0));
    _applyTransform(matrix);
  }

  void _zoom(double factor) {
    final matrix = _transform.value.clone();
    final oldScale = matrix.entry(0, 0);
    final newScale = (oldScale * factor).clamp(_fitScale, _fitScale * 4);
    final centerX =
        -matrix.entry(0, 3) / oldScale + _viewportSize / (2 * oldScale);
    final centerY =
        -matrix.entry(1, 3) / oldScale + _viewportSize / (2 * oldScale);
    final minX = _viewportSize - _previewWidth * newScale;
    final minY = _viewportSize - _previewHeight * newScale;
    matrix
      ..setEntry(0, 0, newScale)
      ..setEntry(1, 1, newScale)
      ..setEntry(
        0,
        3,
        (_viewportSize / 2 - centerX * newScale).clamp(minX, 0.0),
      )
      ..setEntry(
        1,
        3,
        (_viewportSize / 2 - centerY * newScale).clamp(minY, 0.0),
      );
    _applyTransform(matrix);
  }

  void _applyTransform(Matrix4 matrix) {
    _transform.value = matrix;
    if (mounted) setState(() {});
  }

  void _reset() => _applyTransform(_initialTransform(_viewportSize));

  void _beginPointerGesture() {
    final matrix = _transform.value;
    _gestureScale = matrix.entry(0, 0);
    _gestureTranslation = Offset(matrix.entry(0, 3), matrix.entry(1, 3));
    _gestureFocal = _focalPoint;
    _gestureAnchor = Offset(
      (_gestureFocal.dx - matrix.entry(0, 3)) / _gestureScale,
      (_gestureFocal.dy - matrix.entry(1, 3)) / _gestureScale,
    );
    _gestureDistance = _pointers.length > 1 ? _pointerDistance : 0;
  }

  Offset get _focalPoint {
    if (_pointers.isEmpty) return Offset.zero;
    final sum = _pointers.values.reduce((a, b) => a + b);
    return sum / _pointers.length.toDouble();
  }

  double get _pointerDistance {
    if (_pointers.length < 2) return 0;
    final points = _pointers.values.take(2).toList(growable: false);
    return (points[0] - points[1]).distance;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    _beginPointerGesture();
    _viewportFocus.requestFocus();
    if (!_interacting) setState(() => _interacting = true);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    final focal = _focalPoint;
    final scale = _pointers.length > 1 && _gestureDistance > 0
        ? (_gestureScale * _pointerDistance / _gestureDistance).clamp(
            _fitScale,
            _fitScale * 4,
          )
        : _gestureScale;
    final delta = focal - _gestureFocal;
    final tx = _pointers.length > 1
        ? focal.dx - _gestureAnchor.dx * scale
        : _gestureTranslation.dx + delta.dx;
    final ty = _pointers.length > 1
        ? focal.dy - _gestureAnchor.dy * scale
        : _gestureTranslation.dy + delta.dy;
    final minX = _viewportSize - _previewWidth * scale;
    final minY = _viewportSize - _previewHeight * scale;
    _applyTransform(
      Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, tx.clamp(minX, 0.0))
        ..setEntry(1, 3, ty.clamp(minY, 0.0)),
    );
  }

  void _endPointer(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.isEmpty) {
      setState(() => _interacting = false);
    } else {
      _beginPointerGesture();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _nudge(-8, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _nudge(8, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _nudge(0, -8);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _nudge(0, 8);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.add:
      case LogicalKeyboardKey.equal:
        _zoom(1.1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.minus:
        _zoom(1 / 1.1);
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _confirm() {
    final crop = _currentCrop();
    crop.toPixels(width: _sourceWidth, height: _sourceHeight);
    Navigator.of(context).pop(crop);
  }

  @override
  void dispose() {
    _previewBytes.fillRange(0, _previewBytes.length, 0);
    widget.source.fillRange(0, widget.source.length, 0);
    _transform.dispose();
    _viewportFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _errorMessage == null
      ? _buildCropPage(context)
      : _buildInvalidImagePage(context);

  Widget _buildInvalidImagePage(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ajustar foto'),
      leading: IconButton(
        tooltip: 'Voltar sem selecionar foto',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.close),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, size: 40),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Voltar para o formulário'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildCropPage(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ajustar foto'),
      leading: IconButton(
        tooltip: 'Cancelar ajuste da foto',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.close),
      ),
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = (constraints.maxWidth - 32).clamp(
            _minimumViewportDimension,
            _maximumViewportDimension,
          );
          final viewport = math.min(available, constraints.maxWidth);
          _configureViewport(viewport);
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ajuste o enquadramento quadrado. O círculo mostra como a foto aparece no cartão.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Semantics(
                        label: 'Área de enquadramento da foto',
                        hint: 'Arraste a imagem. Use as setas do teclado para posicionar.',
                        child: Focus(
                          focusNode: _viewportFocus,
                          onKeyEvent: _onKey,
                          child: Listener(
                            key: const ValueKey('photo-crop-viewport'),
                            onPointerDown: _onPointerDown,
                            onPointerMove: _onPointerMove,
                            onPointerUp: _endPointer,
                            onPointerCancel: _endPointer,
                            child: SizedBox.square(
                              dimension: viewport,
                              child: ClipRect(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Transform(
                                      alignment: Alignment.topLeft,
                                      transform: _transform.value,
                                      child: Image.memory(
                                        _previewBytes,
                                        width: _previewWidth.toDouble(),
                                        height: _previewHeight.toDouble(),
                                        fit: BoxFit.fill,
                                        gaplessPlayback: true,
                                      ),
                                    ),
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: _CropGuidePainter(
                                          active: _interacting,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ampliação ${(_transform.value.entry(0, 0) / _fitScale * 100).round()}%',
                      textAlign: TextAlign.center,
                      semanticsLabel: 'Ampliação da foto',
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Afastar foto',
                          onPressed: () => _zoom(1 / 1.1),
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          tooltip: 'Aproximar foto',
                          onPressed: () => _zoom(1.1),
                          icon: const Icon(Icons.add),
                        ),
                        TextButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Redefinir'),
                        ),
                      ],
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Mover foto à esquerda',
                          onPressed: () => _nudge(-8, 0),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        IconButton(
                          tooltip: 'Mover foto à direita',
                          onPressed: () => _nudge(8, 0),
                          icon: const Icon(Icons.arrow_forward),
                        ),
                        IconButton(
                          tooltip: 'Mover foto para cima',
                          onPressed: () => _nudge(0, -8),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Mover foto para baixo',
                          onPressed: () => _nudge(0, 8),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                      ],
                    ),
                    if (textScale >= 2)
                      const Text(
                        'Use os botões de posição para mover a foto em incrementos.',
                        textAlign: TextAlign.center,
                      ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton.icon(
                          onPressed: _confirm,
                          icon: const Icon(Icons.check),
                          label: const Text('Confirmar foto'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _CropGuidePainter extends CustomPainter {
  const _CropGuidePainter({required this.active});
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final center = bounds.center;
    final radius = size.shortestSide * .48;
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(shade, Paint()..color = const Color(0x55000000));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = active ? Colors.lightBlueAccent : Colors.white
        ..strokeWidth = active ? 3 : 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _CropGuidePainter oldDelegate) =>
      active != oldDelegate.active;
}

Future<NormalizedPhotoCrop?> showPhotoCrop(
  BuildContext context,
  Uint8List source,
) => Navigator.of(context).push<NormalizedPhotoCrop>(
  _PhotoCropRoute(
    disableAnimations: MediaQuery.of(context).disableAnimations,
    builder: (_) => PhotoCropPage(source: Uint8List.fromList(source)),
  ),
);

class _PhotoCropRoute extends MaterialPageRoute<NormalizedPhotoCrop> {
  _PhotoCropRoute({required this.disableAnimations, required super.builder});

  final bool disableAnimations;

  @override
  Duration get transitionDuration =>
      disableAnimations ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      disableAnimations ? Duration.zero : super.reverseTransitionDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => disableAnimations
      ? child
      : super.buildTransitions(context, animation, secondaryAnimation, child);
}
