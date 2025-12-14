package com.example.child_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		createNotificationChannel()
	}

	private fun createNotificationChannel() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

		val channel = NotificationChannel(
			"child_tracker_channel",
			"Child Tracker",
			NotificationManager.IMPORTANCE_LOW,
		).apply {
			description = "Background location sharing"
		}

		val manager = getSystemService(NotificationManager::class.java)
		manager?.createNotificationChannel(channel)
	}
}
