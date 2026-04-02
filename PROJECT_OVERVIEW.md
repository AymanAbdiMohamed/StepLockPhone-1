# StepLock Phone — Project Overview

---

## 1. PROJECT SUMMARY

StepLock Phone is an Android app that enforces a daily walking habit by locking the phone until the user reaches a configurable step goal. When a new day starts the app is "locked": the lock screen is shown, back-navigation is blocked, and the OS screen lock is triggered via Android's Device Administration API. As the user walks, the pedometer stream updates a progress ring in real time. When the step count reaches the goal the user taps "Enter" and the phone is marked as unlocked for that day.

The unlock state is stored with a date-string key in SharedPreferences: as long as today's date matches the stored value the app goes straight to the home screen. At midnight the key is stale, so the next launch shows the lock screen again. A background `BroadcastReceiver` listens for `BOOT_COMPLETED` and re-applies the OS-level screen lock if the phone reboots before the daily goal is reached, ensuring the lock cannot be bypassed by powering the device off and on.

---

## 2. ARCHITECTURE

```
StepLockPhone-1/
├── lib/
│   ├── main.dart                         Entry point; loads step goal + lock state, routes to LockScreen or HomeScreen
│   ├── pages/
│   │   ├── lock_screen.dart              Step-gated lock UI; enforces back-block, calls lockNow() on launch
│   │   ├── home_screen.dart              Post-unlock summary screen; shows live step count + progress bar
│   │   └── settings_page.dart            Step-goal editor; persists choice to SharedPreferences
│   └── services/
│       ├── step_service.dart             Wraps pedometer plugin; manages daily baseline, simulated steps
│       ├── lock_service.dart             Reads/writes the date-keyed unlock flag in SharedPreferences
│       └── device_admin_service.dart     MethodChannel wrapper; calls lockNow / isAdminActive / requestAdminActivation
│
├── android/app/src/main/
│   ├── AndroidManifest.xml               Declares permissions, Activity, StepLockDeviceAdmin, BootReceiver
│   ├── kotlin/com/steplock/step_lock_phone/
│   │   ├── MainActivity.kt               Hosts the MethodChannel; delegates device-policy calls to DPM
│   │   ├── MyDeviceAdminReceiver.kt      DeviceAdminReceiver subclass (class name: StepLockDeviceAdmin)
│   │   └── BootReceiver.kt               BroadcastReceiver; re-locks phone after reboot if goal not met
│   └── res/
│       ├── values/strings.xml            App name + device-admin description strings
│       └── xml/device_admin.xml          Declares the force-lock policy used by StepLockDeviceAdmin
│
├── pubspec.yaml                          Flutter/Dart dependencies
└── PROJECT_OVERVIEW.md                   This file
```

---

## 3. HOW IT WORKS END TO END

### First launch ever

1. `main()` runs, calls `WidgetsFlutterBinding.ensureInitialized()`.
2. `StepService.init()` loads the daily baseline from SharedPreferences. Because no baseline exists the sentinel value `-1` is stored.
3. `LockService.isLockedToday()` checks whether `unlocked_date` in SharedPreferences matches today's ISO date string. On first launch it does not, so `isLocked = true`.
4. `main()` also reads `step_goal` from SharedPreferences (defaults to `1000` if absent).
5. `runApp` mounts `LockScreen`.

### Every subsequent launch while locked

1. Same `main()` path — `isLocked = true` → `LockScreen` is shown.
2. `LockScreen._initialize()` runs:
   - Loads `step_goal` from SharedPreferences (fixing the race where the default 1000 could be used).
   - Calls `DeviceAdminService.lockNow()` fire-and-forget: if Device Admin is active the OS screen turns off immediately, ensuring a physical-level lock. If admin is not yet active the activation dialog is shown instead.
   - Requests `ACTIVITY_RECOGNITION` permission if not yet granted, then subscribes to the step stream.
3. `StepService` emits daily step counts as the pedometer fires. `LockScreen` renders the progress ring.
4. When `_currentSteps >= _stepGoal` the `_unlocked` flag flips, the "Enter" button appears.
5. User taps "Enter": `LockService.unlockToday()` writes today's date, then `Navigator.pushReplacement` shows `HomeScreen`.

### Subsequent launch after unlock

`LockService.isLockedToday()` returns `false` → `HomeScreen` is shown directly with the saved step goal. The user can open Settings to change the goal for tomorrow.

### Day rollover / midnight

No foreground service runs. On the next app launch after midnight `isLockedToday()` returns `true` again because the stored date is yesterday's. `StepService._loadBaseline()` also detects the date change and resets the baseline sentinel to `-1` so steps are counted fresh from zero.

---

## 4. HOW THE FILE TYPES COMMUNICATE

### Dart → Kotlin via MethodChannel

- **Channel name (must match exactly in both files):**
  `com.steplock.step_lock_phone/device_admin`
- Defined in `device_admin_service.dart` and `MainActivity.kt`.
- Three methods:

| Method name              | Direction       | Return            | What it does                                      |
|--------------------------|-----------------|-------------------|---------------------------------------------------|
| `lockNow`                | Dart → Kotlin   | `bool` / error    | Calls `DevicePolicyManager.lockNow()`; returns error code `NOT_ADMIN` if admin inactive |
| `isAdminActive`          | Dart → Kotlin   | `bool`            | Queries `DevicePolicyManager.isAdminActive()`     |
| `requestAdminActivation` | Dart → Kotlin   | `null`            | Launches `ACTION_ADD_DEVICE_ADMIN` intent         |

`DeviceAdminService.lockNow()` catches the `NOT_ADMIN` error and calls `requestAdminActivation()` automatically, so callers only need to call `lockNow()`.

### Pedometer plugin

The `pedometer` package registers a `SensorEventListener` on Android's `TYPE_STEP_COUNTER` sensor (a hardware step counter that runs even when the app is backgrounded, but only while the phone is on). It exposes a Dart `Stream<StepCount>`. The sensor returns a cumulative count since the last device reboot — that is why `StepService` maintains a `_baseline`: on the first event of each day it records the raw count and subtracts it from all subsequent events to get today's steps.

### SharedPreferences

`shared_preferences` uses `android.content.SharedPreferences` on Android. Flutter stores keys with a `flutter.` prefix in the `FlutterSharedPreferences` named preferences file. This is exploited in `BootReceiver.kt` to read the unlock state without going through Flutter:

```kotlin
val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
val unlockedDate = prefs.getString("flutter.unlocked_date", "") ?: ""
```

Keys used in this project:

| Dart key          | Android key                      | Type   | Purpose                          |
|-------------------|----------------------------------|--------|----------------------------------|
| `unlocked_date`   | `flutter.unlocked_date`          | String | ISO date when phone was unlocked |
| `step_goal`       | `flutter.step_goal`              | Int    | Daily step target                |
| `step_baseline`   | `flutter.step_baseline`          | Int    | Raw pedometer count at day start |
| `step_baseline_date` | `flutter.step_baseline_date` | String | Date the baseline was last set   |

### DeviceAdminReceiver

`StepLockDeviceAdmin` (in `MyDeviceAdminReceiver.kt`) extends `DeviceAdminReceiver`. Declaring it in `AndroidManifest.xml` with the `BIND_DEVICE_ADMIN` permission and a reference to `device_admin.xml` registers the app as a Device Administration app. The `device_admin.xml` policy file declares `<force-lock/>`, which is the only policy needed. Until the user accepts the activation dialog, `isAdminActive()` returns `false` and `lockNow()` will not work.

---

## 5. DATA FLOW DIAGRAM

```
┌────────────────────────────────────────────────────────────────────────┐
│  Android Hardware                                                       │
│  TYPE_STEP_COUNTER sensor  ─── cumulative count since last reboot ───► │
└──────────────────────────┬─────────────────────────────────────────────┘
                           │  pedometer plugin (SensorEventListener)
                           ▼
┌──────────────────────────────────────┐
│  StepService (Dart)                  │
│  _baseline = raw count at day start  │
│  daily = raw − baseline              │
│  StreamController<int>.broadcast()   │
└──────────────┬───────────────────────┘
               │  Stream<int>  (stepsStream)
               ▼
┌─────────────────────────────────────────┐
│  LockScreen  (stateful widget)          │
│  _currentSteps updated on each event   │
│  if _currentSteps >= _stepGoal          │
│      → _unlocked = true (show button)  │
└──────────────┬──────────────────────────┘
               │  User taps "Enter"
               ▼
┌──────────────────────────────┐
│  LockService.unlockToday()   │
│  SharedPrefs ← today's date  │
└──────────────┬───────────────┘
               │  Navigator.pushReplacement
               ▼
┌──────────────────────────────┐
│  HomeScreen  (unlocked UI)   │
└──────────────────────────────┘

OS-level lock path:
LockScreen._initialize()
  └─► DeviceAdminService.lockNow()   (MethodChannel)
        └─► MainActivity.kt
              └─► DevicePolicyManager.lockNow()
                    └─► Android OS turns screen off immediately

Boot path:
Android BOOT_COMPLETED broadcast
  └─► BootReceiver.onReceive()
        ├─ reads FlutterSharedPreferences directly (no Flutter engine)
        ├─ if unlockedDate ≠ today
        └─► DevicePolicyManager.lockNow()
```

---

## 6. KEY DECISIONS LOG

### Why Device Administration API instead of Accessibility Service or overlay?

Device Admin's `lockNow()` is the only official, non-root Android API that can force an immediate screen lock. Accessibility Service cannot lock the screen. Window overlays (`TYPE_APPLICATION_OVERLAY`) can draw over other apps but cannot prevent the user from navigating to the home screen or dismissing them. Device Admin is the minimal-privilege approach that actually works.

### Why SharedPreferences instead of SQLite or secure storage?

The unlock state is a single date string and the step goal is a single integer. A relational database would be massive overkill. Secure storage (encrypted keystore) is unnecessary because neither value is a secret — knowing today's unlock date gives an attacker nothing. SharedPreferences is available without any extra packages, survives app upgrades, and can be read natively from Kotlin (e.g., in `BootReceiver`) without starting a Flutter engine.

### Why the `pedometer` plugin instead of a raw sensor MethodChannel?

The `pedometer` package handles the Android `SensorManager` registration, background wakelock, and Dart stream plumbing. Writing an equivalent raw channel would add ~150 lines of Kotlin and Java with no benefit. The plugin is well-maintained and is the community standard for this sensor type.

### Why date-string key for unlock state?

Storing the actual unlock date (e.g., `"2026-04-02"`) rather than a boolean means the lock automatically resets at midnight with zero extra logic. Any check is simply `storedDate == today`. A boolean would require a separate reset job or midnight timer.

### Why baseline subtraction for step counting?

Android's `TYPE_STEP_COUNTER` sensor is cumulative since the last reboot — it does not reset at midnight. Storing the raw count at the start of each day and subtracting it gives a daily step count without needing a foreground service or periodic polling. The baseline is persisted so it survives app restarts within the same day.

---

## 7. KNOWN LIMITATIONS

| # | Limitation | Impact |
|---|-----------|--------|
| 1 | **No foreground service** — steps are only counted while the phone is on. If the screen is off for hours the sensor hardware may still accumulate counts (the `TYPE_STEP_COUNTER` is always-on), but the Dart stream won't fire until the app is active. In practice Android delivers batched events when the app resumes, so counts are not lost — but the UI won't update in real time while the screen is off. | Medium |
| 2 | **Home button / recents bypass** — `PopScope(canPop: false)` blocks the Android back gesture, but the Home button and Recent Apps button are not interceptable by normal apps. A user can navigate away from the lock screen freely; re-opening the app will show the lock screen again, but there is a window of access. | High (by design of Android) |
| 3 | **Device Admin deprecated since Android 9** — `DevicePolicyManager.lockNow()` for non-managed-device apps is technically deprecated in Android 9+ but continues to function on all current Android versions (up to Android 15 as of this writing). Google may remove it in a future release. | Low (currently) |
| 4 | **Play Store policy** — Apps using Device Administration are restricted on the Play Store unless they are enterprise MDM apps. Publishing this app as a consumer app on the Play Store may require removal of the Device Admin feature or a policy exception. Sideloading works without restriction. | High for distribution |
| 5 | **Single step goal, no history** — There is no per-day step history. The app only tracks whether today's goal was reached. | Low |
| 6 | **No foreground service notification** — Android may kill the app process when it is in the background, stopping step counting. A foreground service with a persistent notification would prevent this but has not been implemented. | Medium |
| 7 | **Lock screen can be removed by uninstalling the app** — The user can go to Settings → Apps → StepLock → Uninstall at any time (Device Admin prevents uninstall only if they don't manually deactivate admin first, but a determined user can do both). | Medium |

---

## 8. BUILD & RUN GUIDE

### Prerequisites

- Flutter SDK ≥ 3.11 (`flutter --version`)
- Android SDK with API 33+ installed
- A physical Android device (the step counter sensor is not available in the emulator)
- ADB (`adb devices` should list your device)

### Install dependencies

```bash
cd StepLockPhone-1
flutter pub get
```

### Run on device (debug)

```bash
flutter run
```

The app will be installed and launched. On first launch you will see a system dialog asking you to grant Device Admin — tap **Activate** to enable screen locking.

### Run on device (release)

```bash
flutter run --release
```

Release mode disables the "Simulate Steps +50" debug button.

### Grant Device Admin during development

If you dismiss the Device Admin activation dialog you can trigger it again by:

1. Opening the app (LockScreen will appear).
2. The app calls `lockNow()` → which fails with `NOT_ADMIN` → which auto-triggers `requestAdminActivation()`, showing the dialog again.

Or manually:

```bash
adb shell dpm set-active-admin com.steplock.step_lock_phone/.StepLockDeviceAdmin
```

### Revoke Device Admin (for uninstalling during development)

```bash
adb shell dpm remove-active-admin com.steplock.step_lock_phone/.StepLockDeviceAdmin
# Then uninstall normally:
flutter clean && adb uninstall com.steplock.step_lock_phone
```

### Reset unlock state (force lock screen on next launch)

From the Dart side (add a temporary debug button or run from Dart DevTools):

```dart
await LockService().resetLock();
```

Or directly via ADB:

```bash
adb shell am broadcast -a com.example.RESET  # (no broadcast receiver yet — use flutter)
```

### Test the boot receiver

```bash
adb shell am broadcast -a android.intent.action.BOOT_COMPLETED \
  -p com.steplock.step_lock_phone
```

This fires `BootReceiver.onReceive()` directly without rebooting the device.

### Build a release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 9. PROJECT CHECKLIST

### ✅ DONE

- [x] `StepService` with daily baseline subtraction and pedometer subscription
- [x] `StepService.simulateSteps()` for testing (only shown in `kDebugMode`)
- [x] `LockService` with date-string unlock state persisted to SharedPreferences
- [x] `DeviceAdminService` isolated in its own file with MethodChannel wrapper
- [x] MethodChannel name matches exactly between Dart and Kotlin (`com.steplock.step_lock_phone/device_admin`)
- [x] `MainActivity.kt` handles `lockNow`, `isAdminActive`, `requestAdminActivation`
- [x] `MainActivity.kt` references correct class `StepLockDeviceAdmin` (was `MyDeviceAdminReceiver`)
- [x] `StepLockDeviceAdmin` (DeviceAdminReceiver) declared in manifest with `force-lock` policy
- [x] `strings.xml` with `app_name` and `device_admin_description`
- [x] `device_admin.xml` declaring `<force-lock/>` policy
- [x] `LockScreen` uses `PopScope(canPop: false)` to block back-button bypass
- [x] `LockScreen._initialize()` loads goal before starting pedometer (race condition fix)
- [x] `LockScreen._initialize()` calls `DeviceAdminService.lockNow()` on every locked launch
- [x] `LockScreen._grantPermission()` restarts pedometer subscription after permission grant
- [x] `LockScreen` wired to `DeviceAdminService` for OS-level lock enforcement
- [x] `ACTIVITY_RECOGNITION` permission requested at runtime
- [x] `main.dart` loads `step_goal` from SharedPreferences (was hardcoded to 1000)
- [x] `BootReceiver` re-locks phone on `BOOT_COMPLETED` if not unlocked today
- [x] `RECEIVE_BOOT_COMPLETED` permission in manifest
- [x] `BootReceiver` registered in manifest
- [x] `flutter analyze` reports zero issues

### 🔲 TODO

| Priority | Item |
|----------|------|
| **P1** | **Foreground service for background step counting** — without it steps are only counted when the screen is on. Implement an Android `Service` that holds a `FOREGROUND_SERVICE` wakelock and posts a persistent notification, updating SharedPreferences so the app can read accumulated steps on next launch. |
| **P1** | **Prevent Home-button bypass** — `PopScope` only blocks back. Consider using `WillPopScope` + `onUserLeaveHint()` override in `MainActivity.kt` to call `lockNow()` whenever the app is sent to background while still locked. |
| **P1** | **Verify Device Admin cannot be deactivated without entering goal** — A determined user can navigate to Settings → Device Admin and deactivate StepLock. Override `onDisableRequested()` in `StepLockDeviceAdmin` to show a warning message. |
| **P2** | **Midnight / day-rollover foreground handling** — If the app is open at midnight the baseline will not reset until the next `init()`. Add a timer or `DateFormat` check in the step stream listener to detect day change and reload the baseline. |
| **P2** | **Time-aware greeting** — The "Good Morning" text in `LockScreen` is hardcoded. Replace with logic based on `DateTime.now().hour` (Good Morning / Afternoon / Evening). |
| **P2** | **Step history** — Store per-day step counts so the home screen can show a weekly bar chart. Use a list of date-keyed entries in SharedPreferences or migrate to a SQLite/Hive store. |
| **P2** | **Persist steps across app restarts within the same day** — Currently `_currentSteps` is `0` on each app cold-start and catches up only when the pedometer fires its first event. Store the last-known step count so the UI doesn't flash "0" on launch. |
| **P3** | **Reset unlock debug button** — Add a "Reset lock (debug)" button in `kDebugMode` on `HomeScreen` that calls `LockService.resetLock()` for faster testing without ADB. |
| **P3** | **App icon and splash screen** — Replace the default Flutter icon with a custom padlock icon. |
| **P3** | **Accessibility / localization** — Add semantic labels to the progress indicators and support at least one additional locale. |
| **P3** | **Unit tests** — `StepService` baseline logic and `LockService` date comparisons are pure Dart and straightforward to unit test with `flutter_test`. |
