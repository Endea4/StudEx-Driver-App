package com.studex.driver_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "studex/test"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // E2E test hook: the harness launches the app with
                    // `am start -a com.studex.driver_app.TEST_LOGIN --es phone .. --es password ..`.
                    // Dart pulls the pending credentials on startup and signs in.
                    "getPendingLogin" -> {
                        if (intent?.action == "com.studex.driver_app.TEST_LOGIN") {
                            result.success(
                                mapOf(
                                    "phone" to intent.getStringExtra("phone"),
                                    "password" to intent.getStringExtra("password")
                                )
                            )
                        } else {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
