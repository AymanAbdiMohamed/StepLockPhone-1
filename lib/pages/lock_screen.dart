import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/step_service.dart';
import '../services/lock_service.dart';
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

  StreamSubscription<int>? _stepsSubscription;
  int _currentSteps = 0;
  int _stepGoal = _defaultGoal;
  bool _permissionDenied = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _loadGoal();
    _requestPermissionAndStart();
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
          // Still subscribe — step service will emit simulated steps on error
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

  @override
  void dispose() {
    _stepsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_stepGoal > 0 ? _currentSteps / _stepGoal : 0.0)
        .clamp(0.0, 1.0);
    final stepsRemaining = (_stepGoal - _currentSteps).clamp(0, _stepGoal);

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Padlock icon
                Icon(
                  _unlocked ? Icons.lock_open : Icons.lock,
                  size: 80,
                  color: _unlocked ? Colors.greenAccent : _highlightColor,
                ),
                const SizedBox(height: 24),

                // Good Morning heading
                const Text(
                  'Good Morning',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 32),

                // Step count
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
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white54,
                  ),
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

                // Permission error section
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
                          style: TextStyle(color: Colors.white70, fontSize: 13),
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

                // Simulate steps button (for testing when pedometer unavailable)
                if (!widget.stepService.isAvailable || _permissionDenied) ...[
                  TextButton.icon(
                    onPressed: () {
                      widget.stepService.simulateSteps(50);
                    },
                    icon: const Icon(Icons.directions_walk, color: Colors.white54),
                    label: const Text(
                      'Simulate Steps +50',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
