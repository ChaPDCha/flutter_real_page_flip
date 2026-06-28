package com.chapdcha.real_page_flip

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class RealPageFlipPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var vibrator: Vibrator? = null
    private var isVibratorAvailable = false
    private var hasAmplitudeControl = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.chapdcha.real_page_flip/haptics")
        channel.setMethodCallHandler(this)

        val context = flutterPluginBinding.applicationContext
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        isVibratorAvailable = vibrator?.hasVibrator() == true
        if (isVibratorAvailable && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            hasAmplitudeControl = vibrator?.hasAmplitudeControl() == true
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (!isVibratorAvailable) {
            result.error("VIBRATOR_UNAVAILABLE", "Device has no vibrator", null)
            return
        }

        try {
            when (call.method) {
                "playTransient" -> {
                    val intensity = call.argument<Double>("intensity") ?: 0.5
                    val sharpness = call.argument<Double>("sharpness") ?: 0.5
                    playTransient(intensity, sharpness)
                    result.success(null)
                }
                "playThud" -> {
                    val intensity = call.argument<Double>("intensity") ?: 0.5
                    playThud(intensity)
                    result.success(null)
                }
                "playSystemMedium" -> {
                    playFallback(40, 180)
                    result.success(null)
                }
                "playSystemLight" -> {
                    playFallback(20, 100)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            // VIBRATE permission missing — report error so Dart side falls back to HapticFeedback
            result.error("VIBRATE_PERMISSION_MISSING", e.message, null)
        } catch (e: Exception) {
            result.error("HAPTIC_ERROR", e.message, null)
        }
    }

    private fun playTransient(intensity: Double, sharpness: Double) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val scale = (intensity * 1.0).toFloat().coerceIn(0.0f, 1.0f)
            val primitive = if (sharpness > 0.6) VibrationEffect.Composition.PRIMITIVE_CLICK else VibrationEffect.Composition.PRIMITIVE_TICK
            try {
                val effect = VibrationEffect.startComposition()
                    .addPrimitive(primitive, scale)
                    .compose()
                vibrator?.vibrate(effect)
                return
            } catch (e: Exception) {
                // fallback
            }
        }

        val amp = (intensity * 255).toInt().coerceIn(10, 255)
        val dur = (10 + (sharpness * 15)).toLong()
        playFallback(dur, amp)
    }

    private fun playThud(intensity: Double) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val scale = (intensity * 1.0).toFloat().coerceIn(0.0f, 1.0f)
            try {
                val effect = VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_THUD, scale)
                    .compose()
                vibrator?.vibrate(effect)
                return
            } catch (e: Exception) {
                // fallback
            }
        }

        val amp = (intensity * 255).toInt().coerceIn(50, 255)
        playFallback(40, amp)
    }

    private fun playFallback(duration: Long, amplitude: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (hasAmplitudeControl) {
                vibrator?.vibrate(VibrationEffect.createOneShot(duration, amplitude))
            } else {
                vibrator?.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
            }
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(duration)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
