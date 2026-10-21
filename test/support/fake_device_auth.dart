import 'package:family_nexus/data/platform/device_auth.dart';

class FakeDeviceAuth implements DeviceAuth {
  bool available = true;
  bool succeed = true;
  final List<String> reasons = <String>[];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    reasons.add(reason);
    return succeed;
  }
}
