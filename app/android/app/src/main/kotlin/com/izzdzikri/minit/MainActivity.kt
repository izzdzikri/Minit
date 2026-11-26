package com.izzdzikri.minit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var uiBridge: MinitNativeBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        uiBridge?.dispose()
        uiBridge = MinitNativeBridge(
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
