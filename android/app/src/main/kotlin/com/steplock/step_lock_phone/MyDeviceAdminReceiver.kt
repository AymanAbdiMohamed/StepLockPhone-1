package com.steplock.step_lock_phone

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class StepLockDeviceAdmin : DeviceAdminReceiver() {

    // Called by Android when the user successfully grants Device Admin to this app.
    // Empty for now — nothing special needs to happen on activation.
    override fun onEnable(context: Context, intent: Intent) {

    }

    // Called by Android after the user has already deactivated Device Admin.
    // Empty for now — the lock is already gone at this point so nothing to do.
    override fun onDisable(context: Context, intent: Intent) {

    }

    // ADDED: called by Android BEFORE the user confirms deactivation.
    // Android shows the string returned here inside the deactivation dialog
    // as a warning message — the user sees it and has to read it before
    // they can confirm. This does not block deactivation, it just warns them.
    // Without this override the dialog shows no explanation at all.
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        return "Warning: Deactivating StepLock will remove the step-goal lock. You will be able to use your phone freely without reaching your step goal."
    }
}