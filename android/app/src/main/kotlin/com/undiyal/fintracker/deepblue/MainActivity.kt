package com.undiyal.fintracker.deepblue

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		EventChannel(flutterEngine.dartExecutor.binaryMessenger, "undiyal/notification_events")
			.setStreamHandler(object : EventChannel.StreamHandler {
				override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
					NotificationEventEmitter.eventSink = events
				}

				override fun onCancel(arguments: Any?) {
					NotificationEventEmitter.eventSink = null
				}
			})
	}
}