import 'package:flutter/material.dart';
import 'services/step_service.dart';
import 'services/lock_service.dart';
import 'pages/lock_screen.dart';
import 'pages/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final stepService = StepService();
  final lockService = LockService();

  await stepService.init();

  final isLocked = await lockService.isLockedToday();

  runApp(StepLockApp(
    stepService: stepService,
    lockService: lockService,
    isLocked: isLocked,
  ));
}

class StepLockApp extends StatelessWidget {
  final StepService stepService;
  final LockService lockService;
  final bool isLocked;

  const StepLockApp({
    super.key,
    required this.stepService,
    required this.lockService,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StepLock Phone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xff0F3460),
          secondary: const Color(0xffE94560),
          surface: const Color(0xff16213E),
        ),
        scaffoldBackgroundColor: const Color(0xff1A1A2E),
        useMaterial3: true,
      ),
      home: isLocked
          ? LockScreen(stepService: stepService, lockService: lockService)
          : HomeScreen(
              stepService: stepService,
              lockService: lockService,
              currentSteps: 0,
              stepGoal: 1000,
            ),
    );
  }
}
