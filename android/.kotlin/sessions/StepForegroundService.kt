package com.steplock.step_lock_phone

import android.app.*
import android.content.Context
import android.content.Intent
import android.hardware.*
import android.os.IBinder
import androidx.core.app.NotificationCompat

class StepForegroundService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private val CHANNEL_ID = "steplock_channel"
    private val NOTIF_ID = 1

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("StepLock Active")
            .setContentText("Counting steps to unlock your phone...")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .build()
        startForeground(NOTIF_ID, notification)

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        stepSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_STEP_COUNTER) {
            val rawSteps = event.values[0].toInt()
            // Write raw count to SharedPreferences — Flutter reads it on resume
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putInt("flutter.step_raw_background", rawSteps).apply()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, "StepLock", NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}