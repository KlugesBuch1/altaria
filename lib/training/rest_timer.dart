import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'notifications.dart';

class RestTimerController extends ChangeNotifier {
  RestTimerController({
    required this.notifier,
    this.notificationsEnabled = true,
    this.onFinished,
  });

  final RestNotifier notifier;
  bool notificationsEnabled;
  VoidCallback? onFinished;

  Timer? _ticker;
  DateTime? _endsAt;
  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  bool _running = false;

  bool get isRunning => _running;

  int get totalSeconds => _totalSeconds;

  int get remainingSeconds => _remainingSeconds;

  double get progress {
    if (_totalSeconds <= 0) return 0;
    return (_remainingSeconds / _totalSeconds).clamp(0.0, 1.0);
  }

  void start(int seconds) {
    if (seconds <= 0) return;
    _ticker?.cancel();
    _totalSeconds = seconds;
    _remainingSeconds = seconds;
    _endsAt = DateTime.now().add(Duration(seconds: seconds));
    _running = true;
    _ticker = Timer.periodic(const Duration(milliseconds: 250), _tick);
    if (notificationsEnabled) {
      unawaited(notifier.schedule(firesAt: _endsAt!));
    }
    notifyListeners();
  }

  void addSeconds(int delta) {
    if (!_running || _endsAt == null) return;
    final next = _remainingSeconds + delta;
    if (next <= 0) {
      skip();
      return;
    }
    _remainingSeconds = next;
    if (next > _totalSeconds) _totalSeconds = next;
    _endsAt = DateTime.now().add(Duration(seconds: next));
    if (notificationsEnabled) {
      unawaited(notifier.schedule(firesAt: _endsAt!));
    }
    notifyListeners();
  }

  void skip() {
    _ticker?.cancel();
    _ticker = null;
    _running = false;
    _remainingSeconds = 0;
    _endsAt = null;
    unawaited(notifier.cancelRest());
    notifyListeners();
  }

  void _tick(Timer _) {
    final endsAt = _endsAt;
    if (!_running || endsAt == null) return;
    final remainingMs = endsAt.difference(DateTime.now()).inMilliseconds;
    final next = math.max(0, (remainingMs / 1000).ceil());
    if (next == _remainingSeconds) return;
    _remainingSeconds = next;
    if (next <= 0) {
      _finish();
      return;
    }
    notifyListeners();
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    _running = false;
    _remainingSeconds = 0;
    _endsAt = null;
    if (notificationsEnabled) {
      unawaited(notifier.showRestComplete());
    }
    notifyListeners();
    onFinished?.call();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _running = false;
    unawaited(notifier.cancelRest());
    super.dispose();
  }
}
