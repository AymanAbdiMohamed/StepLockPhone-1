import 'package:shared_preferences/shared_preferences.dart';

class LockService {
  static const String _keyUnlockedDate = 'unlocked_date';

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns true if the phone is currently locked (not yet unlocked today).
  Future<bool> isLockedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedDate = prefs.getString(_keyUnlockedDate) ?? '';
    return unlockedDate != _todayString();
  }

  /// Marks the phone as unlocked for today.
  Future<void> unlockToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUnlockedDate, _todayString());
  }

  /// Resets the unlock state so the lock screen appears again tomorrow
  /// (useful for testing — calling this makes the app locked on next launch).
  Future<void> resetLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUnlockedDate);
  }
}
