package com.izzdzikri.minute

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var uiBridge: MinuteNativeBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        uiBridge?.dispose()
        uiBridge = MinuteNativeBridge(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        uiBridge?.dispose()
        uiBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
