import 'dart:async';

import 'package:family_nexus/data/platform/link_source.dart';

class FakeLinkSource implements LinkSource {
  // ignore: close_sinks
  final StreamController<String> controller = StreamController<String>.broadcast();
  String? initial;

  @override
  Future<String?> initialLink() async {
    final v = initial;
    initial = null;
    return v;
  }

  @override
  Stream<String> get links => controller.stream;
}
