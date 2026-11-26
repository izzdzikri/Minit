package com.izzdzikri.minute

import android.app.Application
import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import com.pravera.flutter_foreground_task.FlutterForegroundTaskStarter
import io.flutter.embedding.engine.FlutterEngine

/**
 * Registers the native bridge on the foreground service's background FlutterEngine
 * so recording, segment merging, storage checks, and audio device callbacks work
 * even when the UI Activity is closed or the screen is locked.
 */
class MainApplication : Application() {
    private var backgroundBridge: MinuteNativeBridge? = null

    private val taskLifecycleListener = object : FlutterForegroundTaskLifecycleListener {
        override fun onEngineCreate(flutterEngine: FlutterEngine?) {
            if (flutterEngine != null) {
                backgroundBridge?.dispose()
                backgroundBridge = MinuteNativeBridge(
                    applicationContext,
                    flutterEngine.dartExecutor.binaryMessenger,
                )
            }
        }

        override fun onTaskStart(starter: FlutterForegroundTaskStarter) {}

        override fun onTaskRepeatEvent() {}

        override fun onTaskDestroy() {}

        override fun onEngineWillDestroy() {
            backgroundBridge?.dispose()
            backgroundBridge = null
        }
    }

    override fun onCreate() {
        super.onCreate()
        FlutterForegroundTaskPlugin.addTaskLifecycleListener(taskLifecycleListener)
    }
}
