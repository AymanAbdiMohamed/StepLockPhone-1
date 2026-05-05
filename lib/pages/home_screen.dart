import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/step_service.dart';
import '../services/lock_service.dart';
import 'settings_page.dart';
import 'lock_screen.dart';

const Color _bgColor = Color(0xff1A1A2E);
const Color _accentColor = Color(0xff16213E);
const Color _primaryColor = Color(0xff0F3460);
const Color _highlightColor = Color(0xffE94560);

class HomeScreen extends StatefulWidget {
  final StepService stepService;
  final LockService lockService;
  final int currentSteps;
  final int stepGoal;

  const HomeScreen({
    super.key,
    required this.stepService,
    required this.lockService,
    required this.currentSteps,
    required this.stepGoal,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<int>? _stepsSubscription;
  late int _currentSteps;
  late int _stepGoal;

  @override
  void initState() {
    super.initState();
    _currentSteps = widget.currentSteps;
    _stepGoal = widget.stepGoal;
    _stepsSubscription = widget.stepService.stepsStream.listen((steps) {
      if (!mounted) return;
      setState(() {
        _currentSteps = steps;
      });
    });
  }

  @override
  void dispose() {
    _stepsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final newGoal = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => SettingsPage(currentGoal: _stepGoal)),
    );
    if (newGoal != null && mounted) {
      setState(() {
        _stepGoal = newGoal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_stepGoal > 0 ? _currentSteps / _stepGoal : 0.0).clamp(
      0.0,
      1.0,
    );

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _accentColor,
        title: const Text(
          'StepLock',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Checkmark icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 64,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(height: 24),

                // Phone Unlocked heading
                const Text(
                  'Phone Unlocked',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'Great job reaching your step goal!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.white60),
                ),
                const SizedBox(height: 40),

                // Stats card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Steps",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white54,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$_currentSteps',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '/ $_stepGoal',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor: _primaryColor,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.greenAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toInt()}% of daily goal',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),

                // Debug button — only visible in debug builds, not in release
                if (kDebugMode)
                  TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await widget.lockService.resetLock();
                      if (!mounted) return;
                      navigator.pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => LockScreen(
                            stepService: widget.stepService,
                            lockService: widget.lockService,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Reset Lock (Debug)',
                      style: TextStyle(color: Colors.white30),
                    ),
                  ),

                const SizedBox(height: 32),

                // Lock again tomorrow message
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _highlightColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_clock,
                        size: 18,
                        color: _highlightColor.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Lock again tomorrow',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
