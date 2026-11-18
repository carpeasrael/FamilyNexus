import 'package:family_nexus/data/platform/device_auth.dart';

class FakeDeviceAuth implements DeviceAuth {
  bool available = true;
  @override
  bool supported = true;
  bool succeed = true;

  /// Die Geräteprüfung wirft (Plugin-Fehler): `isAvailable` ist `false`, `lockAbsent` aber nicht sicher.
  bool checkFails = false;
  final List<String> reasons = <String>[];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> lockAbsent() async => !available && !checkFails;

  @override
  Future<bool> authenticate(String reason) async {
    reasons.add(reason);
    return succeed;
  }
}
