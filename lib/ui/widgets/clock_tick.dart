import 'dart:async';

import 'package:flutter/widgets.dart';

/// Baut [builder] regelmäßig neu, damit zeitabhängige Anzeigen (z. B. fällige Erinnerungen) ohne
/// Datenänderung stimmen (#218).
class ClockTick extends StatefulWidget {
  const ClockTick({super.key, required this.builder, this.interval = const Duration(seconds: 30)});
  final WidgetBuilder builder;
  final Duration interval;

  @override
  State<ClockTick> createState() => _ClockTickState();
}

class _ClockTickState extends State<ClockTick> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
