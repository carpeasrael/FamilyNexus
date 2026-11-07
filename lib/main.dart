import 'package:flutter/material.dart';

import 'app/bootstrap.dart';
import 'app/bootstrapper.dart';
import 'app/quiet_zone.dart';

void main() => runInQuietZone(() {
      WidgetsFlutterBinding.ensureInitialized();
      installErrorHandlers();
      runApp(const Bootstrapper());
    });
