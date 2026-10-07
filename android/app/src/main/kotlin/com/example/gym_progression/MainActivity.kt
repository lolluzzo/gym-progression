package com.example.gym_progression

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var sharedTextChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sharedTextChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "gym_progression/shared_text",
        ).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takeSharedText") {
                    result.success(takeSharedText(intent))
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    // A note shared while the app runs. Dart takes it from the intent, so a
    // share that arrives before Dart listens is read at startup instead.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharedTextChannel?.invokeMethod("sharedTextReceived", null)
    }

    // Removes the text from the intent so it is imported only once. Reopening
    // the app from recents replays the share intent, which is skipped.
    private fun takeSharedText(intent: Intent?): String? {
        if (intent == null ||
            intent.action != Intent.ACTION_SEND ||
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        ) {
            return null
        }

        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        intent.removeExtra(Intent.EXTRA_TEXT)
        return text
    }
}
