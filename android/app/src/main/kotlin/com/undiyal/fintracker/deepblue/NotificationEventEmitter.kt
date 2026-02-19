package com.undiyal.fintracker.deepblue

import io.flutter.plugin.common.EventChannel

object NotificationEventEmitter {
    var eventSink: EventChannel.EventSink? = null

    fun emitEvent(payload: Map<String, Any>) {
        eventSink?.success(payload)
    }
}
