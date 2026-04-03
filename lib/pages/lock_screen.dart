import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/step_service.dart';
import '../services/lock_service.dart';
import '../services/device_admin_service.dart';
import 'home_screen.dart';

const Color _bgColor = Color(0xff1A1A2E);
const Color _accentColor = Color(0xff16213E);
const Color _primaryColor = Color(0xff0F3460);
const Color _highlightColor = Color(0xffE94560);

class LockScreen extends StatefulWidget {
  final StepService stepService;
  final LockService lockService;

  const LockScreen({
    super.key,
    required this.stepService,
    required this.lockService,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const String _keyStepGoal = 'step_goal';
  static const int _defaultGoal = 1000;

  final _deviceAdminService = DeviceAdminService();

  StreamSubscription<int>? _stepsSubscription;
  int _currentSteps = 0;
  int _stepGoal = _defaultGoal;
  bool _permissionDenied = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // Load goal first, then enforce OS-level lock, then start pedometer.
  // Loading the goal before the pedometer subscription eliminates the race
  // where the unlock check could fire against the default 1000 goal instead
  // of the user's saved goal.
  Future<void> _initialize() async {
    await _loadGoal();
    // Enforce OS-level screen lock on every launch while the app is locked.
    // If device admin is not yet active this triggers the activation flow.
    unawaited(_deviceAdminService.lockNow());
    await _requestPermissionAndStart();
  }

  Future<void> _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _stepGoal = prefs.getInt(_keyStepGoal) ?? _defaultGoal;
    });
  }

  Future<void> _requestPermissionAndStart() async {
    try {
      final status = await Permission.activityRecognition.status;
      if (status.isDenied || status.isRestricted) {
        final result = await Permission.activityRecognition.request();
        if (!result.isGranted) {
          if (!mounted) return;
          setState(() {
            _permissionDenied = true;
          });
          _subscribeToSteps();
          return;
        }
      }
    } catch (_) {
      // Permission plugin unavailable (e.g. Linux desktop) — proceed without it
    }
    _subscribeToSteps();
  }

  void _subscribeToSteps() {
    // Cancel any existing subscription before creating a new one
    _stepsSubscription?.cancel();
    _stepsSubscription = widget.stepService.stepsStream.listen((steps) {
      if (!mounted) return;
      setState(() {
        _currentSteps = steps;
        if (_currentSteps >= _stepGoal && !_unlocked) {
          _unlocked = true;
        }
      });
    });
  }

  Future<void> _grantPermission() async {
    final result = await Permission.activityRecognition.request();
    if (!mounted) return;
    if (result.isGranted) {
      setState(() {
        _permissionDenied = false;
      });
      // Restart pedometer subscription after permission is granted.
      // Without this the old subscription (started while permission was denied)
      // keeps running on the error/simulated stream — real steps never arrive
      // until the user kills and restarts the app.
      _subscribeToSteps();
    } else {
      await openAppSettings();
    }
  }

  Future<void> _enterHome() async {
    await widget.lockService.unlockToday();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          stepService: widget.stepService,
          lockService: widget.lockService,
          currentSteps: _currentSteps,
          stepGoal: _stepGoal,
        ),
      ),
    );
  }

  // ADDED: returns a greeting string based on the current hour of the day.
  // Previously the screen always said "Good Morning" regardless of the time.
  // Now it checks DateTime.now().hour:
  //   0–11  → Good Morning
  //   12–16 → Good Afternoon
  //   17+   → Good Evening
  // This is a plain method (not async, no state) — it just reads the clock
  // and returns a string. Called directly inside build() so it re-evaluates
  // on every rebuild.
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  void dispose() {
    _stepsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_stepGoal > 0 ? _currentSteps / _stepGoal : 0.0).clamp(
      0.0,
      1.0,
    );
    final stepsRemaining = (_stepGoal - _currentSteps).clamp(0, _stepGoal);

    return PopScope(
      // Blocks the Android back button so the user cannot bypass the lock
      // screen by pressing back. Without this the lock is bypassed in one tap.
      canPop: false,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Padlock icon — changes to an open lock when goal is reached
                  Icon(
                    _unlocked ? Icons.lock_open : Icons.lock,
                    size: 80,
                    color: _unlocked ? Colors.greenAccent : _highlightColor,
                  ),
                  const SizedBox(height: 24),

                  // CHANGED: was const Text('Good Morning') — hardcoded string.
                  // Now calls _getGreeting() which reads the device clock.
                  // 'const' is removed here because the value changes at runtime.
                  Text(
                    _getGreeting(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Step count display
                  Text(
                    '$_currentSteps',
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  // Step goal label
                  Text(
                    '/ $_stepGoal steps',
                    style: const TextStyle(fontSize: 18, color: Colors.white54),
                  ),
                  const SizedBox(height: 32),

                  // Circular progress indicator
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: _accentColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _unlocked ? Colors.greenAccent : _highlightColor,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Motivational message or unlocked state
                  if (_unlocked) ...[
                    const Text(
                      'Unlocked! 🎉',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _enterHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Enter',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Walk $stepsRemaining more steps to unlock your phone',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Permission error section — shown when activity recognition
                  // permission was denied. Offers a button to re-request it.
                  if (_permissionDenied) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Step counting requires Activity Recognition permission.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _grantPermission,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _highlightColor,
                              side: const BorderSide(color: _highlightColor),
                            ),
                            child: const Text('Grant Permission'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Simulate button is debug-only (kDebugMode = false in release).
                  // Previously appeared for any user who denied permission,
                  // giving them a way to fake steps and bypass the lock entirely.
                  // Now it only exists during development builds.
                  if (kDebugMode &&
                      (!widget.stepService.isAvailable || _permissionDenied))
                    TextButton.icon(
                      onPressed: () => widget.stepService.simulateSteps(50),
                      icon: const Icon(
                        Icons.directions_walk,
                        color: Colors.white54,
                      ),
                      label: const Text(
                        'Simulate Steps +50 (Debug)',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
