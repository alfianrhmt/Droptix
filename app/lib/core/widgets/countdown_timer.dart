import 'dart:async';
import 'package:flutter/widgets.dart';

/// Timer bersama yang mendetak setiap menit (awal menit penuh).
/// Dipakai oleh [CountdownBadge] agar semua badge diperbarui bersamaan.
class CountdownTimer extends InheritedNotifier<MinuteNotifier> {
  const CountdownTimer({
    super.key,
    required super.notifier,
    required super.child,
  });

  static MinuteNotifier of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<CountdownTimer>();
    assert(result != null, 'Tidak ada CountdownTimer di atas widget ini.');
    return result!.notifier!;
  }
}

class MinuteNotifier extends ChangeNotifier {
  Timer? _timer;
  DateTime _now = DateTime.now();

  MinuteNotifier() {
    _scheduleNext();
  }

  DateTime get now => _now;

  void _scheduleNext() {
    final secondsToNextMinute = 60 - _now.second;
    _timer = Timer(Duration(seconds: secondsToNextMinute), () {
      _now = DateTime.now();
      notifyListeners();
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Bungkus seluruh app dengan ini supaya [CountdownBadge] bisa memakai timer bersama.
class CountdownTimerProvider extends StatefulWidget {
  const CountdownTimerProvider({super.key, required this.child});
  final Widget child;

  @override
  State<CountdownTimerProvider> createState() => _CountdownTimerProviderState();
}

class _CountdownTimerProviderState extends State<CountdownTimerProvider> {
  late final MinuteNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = MinuteNotifier();
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CountdownTimer(
      notifier: _notifier,
      child: widget.child,
    );
  }
}
