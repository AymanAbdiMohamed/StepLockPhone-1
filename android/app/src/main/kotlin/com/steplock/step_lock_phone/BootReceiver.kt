package com.steplock.step_lock_phone

import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        // Flutter SharedPreferences keys are prefixed with "flutter."
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val unlockedDate = prefs.getString("flutter.unlocked_date", "") ?: ""

        if (unlockedDate != today) {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(context, StepLockDeviceAdmin::class.java)
            if (dpm.isAdminActive(adminComponent)) {
                dpm.lockNow()
            }
        }
    }
}
