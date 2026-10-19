package com.binge.app

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.binge.app/key_pipeline"
    private val TAG = "BingeKeys"

    private var methodChannel: MethodChannel? = null
    private var webScreenActive = false
    private var nativeInterceptEnabled = false
    private var lastInterceptHeartbeat = 0L
    private var remoteTestActive = false

    // Long press tracking for remote keys (especially DPAD_CENTER / OK)
    private val handler = Handler(Looper.getMainLooper())
    private val pendingLongPressRunnables = mutableMapOf<Int, Runnable>()
    private val longPressTriggered = mutableSetOf<Int>()
    private val interceptedDownKeys = mutableSetOf<Int>()

    // Data-driven remote map: KeyCode -> Action identifier
    private val remoteKeyMap = mutableMapOf<Int, String>(
        KeyEvent.KEYCODE_DPAD_UP to "Up",
        KeyEvent.KEYCODE_DPAD_DOWN to "Down",
        KeyEvent.KEYCODE_DPAD_LEFT to "Left",
        KeyEvent.KEYCODE_DPAD_RIGHT to "Right",
        KeyEvent.KEYCODE_DPAD_CENTER to "Select",
        KeyEvent.KEYCODE_ENTER to "Select",
        KeyEvent.KEYCODE_NUMPAD_ENTER to "Select",
        KeyEvent.KEYCODE_BUTTON_A to "Select",
        KeyEvent.KEYCODE_BACK to "Back",
        KeyEvent.KEYCODE_MENU to "Menu",
        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE to "PlayPause",
        KeyEvent.KEYCODE_MEDIA_PLAY to "PlayPause",
        KeyEvent.KEYCODE_MEDIA_PAUSE to "PlayPause",
        KeyEvent.KEYCODE_MEDIA_REWIND to "Rewind",
        KeyEvent.KEYCODE_MEDIA_FAST_FORWARD to "FastForward",
        KeyEvent.KEYCODE_PAGE_UP to "ChannelUp",
        KeyEvent.KEYCODE_PAGE_DOWN to "ChannelDown",
        KeyEvent.KEYCODE_CHANNEL_UP to "ChannelUp",
        KeyEvent.KEYCODE_CHANNEL_DOWN to "ChannelDown",
        KeyEvent.KEYCODE_INFO to "Info",
        KeyEvent.KEYCODE_CAPTIONS to "Subtitle",
        KeyEvent.KEYCODE_GUIDE to "Guide",
        KeyEvent.KEYCODE_PROG_RED to "Red",
        KeyEvent.KEYCODE_PROG_GREEN to "Green",
        KeyEvent.KEYCODE_PROG_YELLOW to "Yellow",
        KeyEvent.KEYCODE_PROG_BLUE to "Blue",
        // Digits 0-9
        KeyEvent.KEYCODE_0 to "Digit0",
        KeyEvent.KEYCODE_1 to "Digit1",
        KeyEvent.KEYCODE_2 to "Digit2",
        KeyEvent.KEYCODE_3 to "Digit3",
        KeyEvent.KEYCODE_4 to "Digit4",
        KeyEvent.KEYCODE_5 to "Digit5",
        KeyEvent.KEYCODE_6 to "Digit6",
        KeyEvent.KEYCODE_7 to "Digit7",
        KeyEvent.KEYCODE_8 to "Digit8",
        KeyEvent.KEYCODE_9 to "Digit9"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "setWebScreenActive" -> {
                        webScreenActive = call.argument<Boolean>("active") ?: false
                        if (!webScreenActive) nativeInterceptEnabled = false
                        result.success(true)
                    }
                    "setNativeInterceptEnabled" -> {
                        nativeInterceptEnabled = call.argument<Boolean>("enabled") ?: false
                        if (nativeInterceptEnabled) {
                            lastInterceptHeartbeat = System.currentTimeMillis()
                        }
                        result.success(true)
                    }
                    "nativeInterceptHeartbeat" -> {
                        lastInterceptHeartbeat = System.currentTimeMillis()
                        result.success(true)
                    }
                    "setRemoteTestActive" -> {
                        remoteTestActive = call.argument<Boolean>("active") ?: false
                        result.success(true)
                    }
                    "remapKey" -> {
                        val keyCode = call.argument<Int>("keyCode")
                        val action = call.argument<String>("action")
                        if (keyCode != null && action != null) {
                            remoteKeyMap[keyCode] = action
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "keyCode or action missing", null)
                        }
                    }
                    "getRemoteMap" -> {
                        val map = remoteKeyMap.mapKeys { it.key.toString() }
                        result.success(map)
                    }
                    "copyDiagnostics" -> {
                        val report = call.argument<String>("report")
                        if (report == null) {
                            result.error("INVALID_ARGS", "report missing", null)
                        } else {
                            val file = File(getExternalFilesDir(null), "diagnostics.txt")
                            file.writeText(report)
                            result.success(file.absolutePath)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode
        val keyName = KeyEvent.keyCodeToString(keyCode)
        val repeat = event.repeatCount
        val isDown = event.action == KeyEvent.ACTION_DOWN

        // Always log to logcat tag BingeKeys in debug builds
        if (isDown) {
            Log.d(TAG, "dispatchKeyEvent: code=$keyCode ($keyName) down repeat=$repeat longPress=${event.isLongPress}")
        }

        // Notify Remote Test screen if active (for diagnostics)
        if (remoteTestActive) {
            val payload = mapOf(
                "keyCode" to keyCode,
                "keyName" to keyName,
                "action" to (if (isDown) "DOWN" else "UP"),
                "repeat" to repeat,
                "isLongPress" to event.isLongPress
            )
            runOnUiThread {
                methodChannel?.invokeMethod("onTestKeyEvent", payload)
            }
        }

        // If web screen is active, intercept remote keys to prevent WebView / OS eating them
        val heartbeatFresh = System.currentTimeMillis() - lastInterceptHeartbeat < 2500L
        if (webScreenActive && nativeInterceptEnabled && heartbeatFresh) {
            val actionName = remoteKeyMap[keyCode]
            if (actionName != null) {
                if (isDown) {
                    // Check for OK / Select long-press
                    if ((keyCode == KeyEvent.KEYCODE_DPAD_CENTER || keyCode == KeyEvent.KEYCODE_ENTER) && repeat == 0) {
                        interceptedDownKeys.add(keyCode)
                        longPressTriggered.remove(keyCode)
                        pendingLongPressRunnables[keyCode]?.let { handler.removeCallbacks(it) }
                        val runnable = Runnable {
                            longPressTriggered.add(keyCode)
                            Log.d(TAG, "Triggered long-press for $actionName")
                            sendKeyToFlutter(actionName, repeat = 0, isLongPress = true, keyCode = keyCode)
                        }
                        pendingLongPressRunnables[keyCode] = runnable
                        handler.postDelayed(runnable, 600)
                    } else if (repeat > 0) {
                        // Key repeat (e.g. holding D-pad arrow or rewind/FF)
                        interceptedDownKeys.add(keyCode)
                        sendKeyToFlutter(actionName, repeat = repeat, isLongPress = false, keyCode = keyCode)
                    } else {
                        // First key down for other keys (or repeated)
                        interceptedDownKeys.add(keyCode)
                        sendKeyToFlutter(actionName, repeat = repeat, isLongPress = false, keyCode = keyCode)
                    }
                    return true
                } else if (event.action == KeyEvent.ACTION_UP) {
                    if (interceptedDownKeys.remove(keyCode)) {
                        pendingLongPressRunnables.remove(keyCode)?.let { handler.removeCallbacks(it) }
                        if (!longPressTriggered.remove(keyCode)) {
                            // Normal single click release
                            sendKeyToFlutter(actionName, repeat = 0, isLongPress = false, keyCode = keyCode)
                        }
                        return true
                    }
                    // Do not swallow an UP for a DOWN handled by Flutter/IME.
                    return super.dispatchKeyEvent(event)
                }
            }
        }

        return super.dispatchKeyEvent(event)
    }

    private fun sendKeyToFlutter(action: String, repeat: Int, isLongPress: Boolean, keyCode: Int) {
        val payload = mapOf(
            "action" to action,
            "repeat" to repeat,
            "isLongPress" to isLongPress,
            "keyCode" to keyCode
        )
        runOnUiThread {
            methodChannel?.invokeMethod("onRemoteKey", payload)
        }
    }

    override fun onPause() {
        nativeInterceptEnabled = false
        super.onPause()
    }

    override fun onDestroy() {
        nativeInterceptEnabled = false
        methodChannel = null
        super.onDestroy()
    }
}
