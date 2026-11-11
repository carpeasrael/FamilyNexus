import 'package:family_nexus/data/platform/store_launcher.dart';

class FakeStoreLauncher implements StoreLauncher {
  FakeStoreLauncher({this.canRate = true});

  @override
  final bool canRate;

  /// `false` simuliert ein Gerät ohne Play Store und ohne Browser.
  bool available = true;
  int opened = 0;

  @override
  Future<bool> openListing() async {
    opened++;
    return available;
  }
}
