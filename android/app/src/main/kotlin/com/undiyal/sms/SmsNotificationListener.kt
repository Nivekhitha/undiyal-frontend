package com.undiyal.sms

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.os.Bundle
import com.undiyal.fintracker.deepblue.NotificationEventEmitter

class SmsNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        try {
            val notification = sbn?.notification
            val extras: Bundle? = notification?.extras
            val title = extras?.getString("android.title") ?: ""
            val text = extras?.getCharSequence("android.text")?.toString() ?: ""

            // Simple payload - you can include packageName, time, etc.
            val payload = mapOf(
                "title" to (title ?: ""),
                "text" to (text ?: ""),
                "package" to (sbn?.packageName ?: ""),
                "postedTime" to (sbn?.postTime ?: 0L)
            )

            // Emit to Dart via the EventChannel sink
            NotificationEventEmitter.emitEvent(payload)
        } catch (e: Exception) {
            // ignore
        }
    }
}
