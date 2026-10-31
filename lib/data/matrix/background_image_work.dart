import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

/// Verkleinert ein Bild im Hintergrund-Isolate (#129); im Web im selben Thread, dort gibt es kein `compute` im Isolate.
///
/// Bewusst nur die Bildarbeit: Sie ist reines Dart. `NativeImplementationsIsolate` verlegte auch Schlüsselwege in
/// Isolates und bräuchte dort vodozemac.
Future<MatrixImageFileResizedResponse?> resizeImageInBackground(MatrixImageFileResizeArguments args) =>
    compute(MatrixImageFile.resizeImplementation, args);
