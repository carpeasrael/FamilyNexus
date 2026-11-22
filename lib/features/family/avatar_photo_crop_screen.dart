import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/avatar_photo_processing.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';

/// Erzeugt die Vorschau des gewählten Bildes (Standard: im Hintergrund; Tests geben eine direkte Fassung).
typedef AvatarPreviewBuilder = Future<AvatarPreview> Function(Uint8List input);

/// Erzeugt das Foto (JPEG) aus dem gewählten Bild und dem Ausschnitt.
typedef AvatarPhotoPreparer = Future<Uint8List> Function(Uint8List input, AvatarCrop crop);

AvatarPreview _previewIsolate(Uint8List input) => AvatarPhotoProcessing.preview(input, pixelLimit: _pixelLimit);

Uint8List _prepareIsolate((Uint8List, AvatarCrop) args) =>
    AvatarPhotoProcessing.prepare(args.$1, crop: args.$2, pixelLimit: _pixelLimit);

int get _pixelLimit => kIsWeb ? AvatarPhotoProcessing.maxPixelsWeb : AvatarPhotoProcessing.maxPixels;

Future<AvatarPreview> defaultAvatarPreview(Uint8List input) => compute(_previewIsolate, input);

Future<Uint8List> defaultAvatarPrepare(Uint8List input, AvatarCrop crop) => compute(_prepareIsolate, (input, crop));

/// Ausschnitt für das Avatar-Foto wählen (#434, E-111): Das Bild lässt sich verschieben und zoomen, ein Regler ersetzt
/// die Geste (Tastatur, Screenreader). Vorschau und Foto entstehen in derselben Dart-Pipeline (Ausrichtung nach EXIF
/// inbegriffen). Schließt mit dem fertigen JPEG ([Uint8List]) oder mit `null` bei Abbruch und nach einem Fehler.
class AvatarPhotoCropScreen extends StatefulWidget {
  const AvatarPhotoCropScreen({
    super.key,
    required this.bytes,
    this.preview = defaultAvatarPreview,
    this.prepare = defaultAvatarPrepare,
  });

  final Uint8List bytes;
  final AvatarPreviewBuilder preview;
  final AvatarPhotoPreparer prepare;

  /// Größte Seite der Auswahlfläche.
  static const double maxViewport = 360;
  static const double maxZoom = 6;

  @override
  State<AvatarPhotoCropScreen> createState() => _AvatarPhotoCropScreenState();
}

class _AvatarPhotoCropScreenState extends State<AvatarPhotoCropScreen> {
  final TransformationController _controller = TransformationController();
  AvatarPreview? _preview;
  ui.Image? _image;
  bool _saving = false;
  bool _centered = false;
  double _side = AvatarPhotoCropScreen.maxViewport;
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransform);
    _controller.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await widget.preview(widget.bytes);
      final c = Completer<ui.Image>();
      ui.decodeImageFromPixels(p.rgba, p.width, p.height, ui.PixelFormat.rgba8888, c.complete);
      final image = await c.future;
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _preview = p;
        _image = image;
      });
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object e) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(l, e))));
    Navigator.of(context).pop();
  }

  /// Seite des Bildes in der Größe, in der es die Auswahlfläche mit der kürzeren Seite füllt (Kind des Betrachters).
  ({double w, double h}) _childSize(AvatarPreview p, double side) {
    final k = side / math.min(p.width, p.height);
    return (w: p.width * k, h: p.height * k);
  }

  /// Das Bild mittig in die Fläche setzen (Standard-Ausschnitt).
  void _center(AvatarPreview p, double side) {
    final c = _childSize(p, side);
    _controller.value = Matrix4.identity()..setTranslationRaw(-(c.w - side) / 2, -(c.h - side) / 2, 0);
  }

  void _onTransform() {
    final z = _controller.value.storage[0];
    if ((z - _zoom).abs() > 0.001 && mounted) setState(() => _zoom = z);
  }

  /// Regler: Zoom um die Mitte der Fläche, der Ausschnitt bleibt im Bild.
  void _setZoom(double zoom) {
    final p = _preview;
    if (p == null) return;
    final m = _controller.value;
    final old = m.storage[0];
    final c = _childSize(p, _side);
    final centerX = (-m.storage[12] + _side / 2) / old;
    final centerY = (-m.storage[13] + _side / 2) / old;
    final tx = (_side / 2 - centerX * zoom).clamp(_side - c.w * zoom, 0.0);
    final ty = (_side / 2 - centerY * zoom).clamp(_side - c.h * zoom, 0.0);
    _controller.value = Matrix4.diagonal3Values(zoom, zoom, 1)..setTranslationRaw(tx, ty, 0);
  }

  Future<void> _save() async {
    final p = _preview;
    if (p == null || _saving) return;
    setState(() => _saving = true);
    try {
      final crop = AvatarCrop.fromViewport(
        transform: _controller.value.storage,
        viewportSide: _side,
        imageWidth: p.width,
        imageHeight: p.height,
      );
      final jpeg = await widget.prepare(widget.bytes, crop);
      if (mounted) Navigator.of(context).pop(jpeg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = _preview;
    final image = _image;
    return Scaffold(
      appBar: AppBar(title: Text(l.avatarPhotoCropTitle)),
      body: SafeArea(
        child: p == null || image == null
            ? Center(child: CircularProgressIndicator(semanticsLabel: l.avatarPhotoPreparing))
            : LayoutBuilder(
                builder: (context, box) {
                  // Keine scrollende Liste um die Fläche: Sie risse das senkrechte Verschieben an sich und ließe die
                  // waagerechte Geste nicht durch. Die Fläche passt sich stattdessen der verfügbaren Breite und Höhe an
                  // (Hinweis, Regler und Knöpfe brauchen etwa 230).
                  final available = math.min(box.maxWidth - 32, box.maxHeight - 230);
                  final side = math.min(AvatarPhotoCropScreen.maxViewport, math.max(120.0, available));
                  // Beim ersten Aufbau und bei geänderter Fläche (Drehen des Geräts) wird das Bild mittig gesetzt.
                  if (!_centered || (side - _side).abs() > 0.5) {
                    _centered = true;
                    _side = side;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _center(p, side);
                    });
                  }
                  final c = _childSize(p, side);
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: <Widget>[
                        Text(l.avatarPhotoCropHint, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Center(
                            child: Semantics(
                              label: l.avatarPhotoCropTitle,
                              child: SizedBox(
                                width: side,
                                height: side,
                                child: ClipOval(
                                  child: InteractiveViewer(
                                    key: const ValueKey<String>('avatar-crop-viewer'),
                                    transformationController: _controller,
                                    constrained: false,
                                    minScale: 1,
                                    maxScale: AvatarPhotoCropScreen.maxZoom,
                                    boundaryMargin: EdgeInsets.zero,
                                    child: RawImage(
                                      image: image,
                                      width: c.w,
                                      height: c.h,
                                      fit: BoxFit.fill,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Slider(
                          key: const ValueKey<String>('avatar-crop-zoom'),
                          value: _zoom.clamp(1.0, AvatarPhotoCropScreen.maxZoom),
                          min: 1,
                          max: AvatarPhotoCropScreen.maxZoom,
                          label: '${_zoom.toStringAsFixed(1)}×',
                          semanticFormatterCallback: (v) => '${v.toStringAsFixed(1)}×',
                          onChanged: _saving ? null : _setZoom,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            TextButton(
                              onPressed: _saving ? null : () => Navigator.of(context).pop(),
                              child: Text(l.cancel),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              key: const ValueKey<String>('avatar-crop-save'),
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(l.save),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
