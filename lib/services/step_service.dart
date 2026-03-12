import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepService {
  static const String _keyBaseline = 'step_baseline';
  static const String _keyBaselineDate = 'step_baseline_date';

  final StreamController<int> _stepsController =
      StreamController<int>.broadcast();

  Stream<int> get stepsStream => _stepsController.stream;

  StreamSubscription<StepCount>? _pedometerSubscription;
  int _baseline = 0;
  int _currentRawSteps = 0;
  bool _isAvailable = false;
  int _simulatedSteps = 0;

  bool get isAvailable => _isAvailable;

  Future<void> init() async {
    await _loadBaseline();
    _startPedometer();
  }

  Future<void> _loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final savedDate = prefs.getString(_keyBaselineDate) ?? '';

    if (savedDate != today) {
      // New day — baseline will be set on first step event
      _baseline = -1; // sentinel: not yet set
      await prefs.setString(_keyBaselineDate, today);
      await prefs.setInt(_keyBaseline, -1);
    } else {
      _baseline = prefs.getInt(_keyBaseline) ?? -1;
    }
  }

  void _startPedometer() {
    try {
      _pedometerSubscription =
          Pedometer.stepCountStream.listen(_onStepCount, onError: _onError);
    } catch (e) {
      _isAvailable = false;
      _stepsController.add(_simulatedSteps);
    }
  }

  void _onStepCount(StepCount event) {
    _isAvailable = true;
    _currentRawSteps = event.steps;

    if (_baseline == -1) {
      // First event of the day — set baseline
      _baseline = _currentRawSteps;
      _persistBaseline(_baseline);
    }

    final dailySteps = _currentRawSteps - _baseline;
    _stepsController.add(dailySteps < 0 ? 0 : dailySteps);
  }

  void _onError(Object error) {
    _isAvailable = false;
    _stepsController.add(_simulatedSteps);
  }

  /// Called when pedometer is unavailable — simulates steps for testing.
  void simulateSteps(int additionalSteps) {
    _simulatedSteps += additionalSteps;
    _stepsController.add(_simulatedSteps);
  }

  Future<void> _persistBaseline(int baseline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBaseline, baseline);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _pedometerSubscription?.cancel();
    _stepsController.close();
  }
}
