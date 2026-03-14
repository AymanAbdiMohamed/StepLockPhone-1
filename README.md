# StepLockPhone

StepLockPhone is a Flutter app that enforces physical activity by gatekeeping smartphone access. Each new day, the app presents a full-screen lock UI that can only be dismissed by walking a configured number of steps. Once the goal is met, the phone is unlocked for the rest of the day and the lock resets automatically the following morning.

## Features

- **Step-gated lock screen** — full-screen lock on every new day, bypassed only by reaching your step goal
- **Daily auto-reset** — locks again at midnight with no manual intervention required
- **Real-time step tracking** — live step count and progress indicator powered by the device pedometer
- **Configurable step goal** — default 1,000 steps; adjustable via Settings (1–100,000)
- **Permission handling** — gracefully handles Activity Recognition permission denial; prompts to re-grant or open OS settings
- **Emulator/testing mode** — simulated step button (+50) appears automatically when the pedometer is unavailable

## Tech Stack

| | |
| --- | --- |
| **Framework** | Flutter (≥3.35.0) |
| **Language** | Dart (≥3.11.1) |
| **Step Counter** | [`pedometer`](https://pub.dev/packages/pedometer) ^4.0.0 |
| **Persistence** | [`shared_preferences`](https://pub.dev/packages/shared_preferences) ^2.3.0 |
| **Permissions** | [`permission_handler`](https://pub.dev/packages/permission_handler) ^11.3.1 |
| **UI** | Material Design 3, dark theme |
| **Platforms** | Android, iOS |

## Project Structure

```text
lib/
├── main.dart               # Entry point — wires services, decides initial route
├── pages/
│   ├── lock_screen.dart    # Step-gated lock UI
│   ├── home_screen.dart    # Post-unlock dashboard
│   └── settings_page.dart  # Step goal configuration
└── services/
    ├── step_service.dart   # Pedometer abstraction; emits daily step count via Stream
    └── lock_service.dart   # Lock state persistence (reads/writes unlock date)
```

## How It Works

1. On launch, `LockService` checks if the phone has already been unlocked today (date string stored in SharedPreferences).
2. If locked, `LockScreen` is shown. It subscribes to `StepService`'s step stream and updates a live progress indicator.
3. `StepService` reads the raw cumulative pedometer count and subtracts a daily baseline (also persisted to SharedPreferences) to isolate today's steps.
4. Once `currentSteps >= stepGoal`, an **Enter** button appears. Tapping it writes today's date to SharedPreferences and navigates to `HomeScreen`.
5. The next day, the stored date no longer matches today, and the lock screen is shown again on app open.

## Android Permissions

The following permissions are declared in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
<uses-permission android:name="android.permission.BODY_SENSORS"/>
```

`ACTIVITY_RECOGNITION` is also requested at runtime via `permission_handler`.

## Getting Started

```bash
flutter pub get
flutter run
```

To run on a physical Android device (recommended — emulators lack a hardware step counter):

```bash
flutter run -d <device-id>
```

To reset the lock state for testing:

```dart
await lockService.resetLock();
```
