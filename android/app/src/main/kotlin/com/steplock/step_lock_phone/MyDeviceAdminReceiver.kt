package com.steplock.step_lock_phone
import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class StepLockDeviceAdmin : DeviceAdminReceiver() {
    override fun onEnable(context: Context, intent: Intent){

    }

    override fun onDisable(context: Context, intent: Intent) {

    }
}