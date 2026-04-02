import 'package:flutter/services.dart';

class DeviceAdminService {
  static const _channel = MethodChannel(
    'com.steplock.step_lock_phone/device_admin',
  );

  Future<bool> isAdminActive() async {
    try {
      return await _channel.invokeMethod<bool>('isAdminActive') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestAdminActivation() async {
    try {
      await _channel.invokeMethod<void>('requestAdminActivation');
    } on PlatformException {
      // Activity will launch the admin activation screen; ignore errors here.
    }
  }

  /// Locks the device screen immediately via DevicePolicyManager.
  /// Returns true on success, false if admin is not active (and triggers
  /// requestAdminActivation() as a side-effect in that case).
  Future<bool> lockNow() async {
    try {
      return await _channel.invokeMethod<bool>('lockNow') ?? false;
    } on PlatformException catch (e) {
      if (e.code == 'NOT_ADMIN') {
        await requestAdminActivation();
      }
      return false;
    }
  }
}
