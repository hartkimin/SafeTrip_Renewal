import 'dart:async';
import '../models/demo_scenario.dart';

/// §3.6 step 4: Timer-based event playback engine
///
/// Compresses time: 1 sim-minute = 2 real-seconds for demo pace.
/// Events trigger visual changes (SOS overlay, geofence alerts, toasts).
class DemoEventSimulator {
  DemoEventSimulator({required this.onEvent});

  final void Function(DemoSimEvent event) onEvent;
  Timer? _timer;
  int _currentIndex = 0;
  List<DemoSimEvent> _events = [];
  bool _isPaused = false;

  bool get isPlaying => _timer?.isActive == true;
  int get currentIndex => _currentIndex;
  bool get isComplete => _currentIndex >= _events.length;

  void start(List<DemoSimEvent> events) {
    _events = events;
    _currentIndex = 0;
    _isPaused = false;
    _scheduleNext();
  }

  void _scheduleNext() {
    if (_currentIndex >= _events.length || _isPaused) return;

    final event = _events[_currentIndex];

    // Calculate delay: compress simulation time
    // First event fires after 2 seconds, subsequent events use relative offset
    int delaySec;
    if (_currentIndex == 0) {
      delaySec = 2;
    } else {
      final prevEvent = _events[_currentIndex - 1];
      final diffMinutes =
          event.timeOffsetMinutes - prevEvent.timeOffsetMinutes;
      // 1 sim-minute = 2 real-seconds, clamped between 1-30 seconds
      delaySec = (diffMinutes * 2).clamp(1, 30);
    }

    _timer = Timer(Duration(seconds: delaySec), () {
      if (_isPaused) return;
      onEvent(event);
      _currentIndex++;
      _scheduleNext();
    });
  }

  void pause() {
    _isPaused = true;
    _timer?.cancel();
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    _scheduleNext();
  }

  void seekTo(int eventIndex) {
    _timer?.cancel();
    _currentIndex = eventIndex.clamp(0, _events.length);
    if (!_isPaused) {
      _scheduleNext();
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
