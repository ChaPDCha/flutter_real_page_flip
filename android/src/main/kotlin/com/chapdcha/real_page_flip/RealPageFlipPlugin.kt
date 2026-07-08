package com.chapdcha.real_page_flip

import android.content.Context
import android.os.Build
import android.os.SystemClock
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
    private var lastVibrateAt = 0L
    private val minVibrateGapMs = 16L

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
        if (!isVibratorAvailable && call.method != "cancel") {
            result.error("VIBRATOR_UNAVAILABLE", "Device has no vibrator", null)
            return
        }

        try {
            when (call.method) {
                "playTransient" -> {
                    val intensity = call.argument<Double>("intensity") ?: 0.5
                    val sharpness = call.argument<Double>("sharpness") ?: 0.5
                    val durationMs = call.argument<Int>("durationMs") ?: 8
                    playTransient(intensity, sharpness, durationMs)
                    result.success(null)
                }
                "playThud" -> {
                    val intensity = call.argument<Double>("intensity") ?: 0.5
                    playThud(intensity)
                    result.success(null)
                }
                "playSlipBurst" -> {
                    val intensity = call.argument<Double>("intensity") ?: 0.5
                    playSlipBurst(intensity)
                    result.success(null)
                }
                "playSettleThud" -> {
                    val intensity = call.argument<Double>("intensity") ?: 0.5
                    playSettleThud(intensity)
                    result.success(null)
                }
                "playSystemMedium" -> {
                    playPaperTick(0.28)
                    result.success(null)
                }
                "playSystemLight" -> {
                    playPaperTick(0.18)
                    result.success(null)
                }
                "cancel" -> {
                    cancelVibration()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            result.error("VIBRATE_PERMISSION_MISSING", e.message, null)
        } catch (e: Exception) {
            result.error("HAPTIC_ERROR", e.message, null)
        }
    }

    private fun cancelVibration() {
        vibrator?.cancel()
        lastVibrateAt = 0L
    }

    private fun shouldEmitVibration(force: Boolean = false): Boolean {
        val now = SystemClock.uptimeMillis()
        if (!force && now - lastVibrateAt < minVibrateGapMs) {
            return false
        }
        lastVibrateAt = now
        return true
    }

    private fun playPaperTick(scale: Double) {
        if (!shouldEmitVibration()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val clamped = scale.toFloat().coerceIn(0.03f, 0.48f)
            try {
                val effect = VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_TICK, clamped)
                    .compose()
                vibrator?.vibrate(effect)
                return
            } catch (e: Exception) {
                // fallback
            }
        }
        playFallback(8, (scale * 180).toInt().coerceIn(20, 140))
    }

    private fun playTransient(intensity: Double, sharpness: Double, durationMs: Int) {
        val shouldEmit = shouldEmitVibration()
        val clampedDuration = durationMs.coerceIn(1, 500)
        val amplitude = (intensity * 255).toInt().coerceIn(1, 255)
        val route = if (clampedDuration <= 16) "primitive_tick" else "one_shot"
        android.util.Log.d("HAPTIC_DIAGNOSTIC", "Android playTransient: intensity=$intensity, sharpness=$sharpness, durationMs=$clampedDuration, amplitude=$amplitude, route=$route, shouldEmit=$shouldEmit")
        if (!shouldEmit) return
        if (clampedDuration > 16) {
            playFallback(clampedDuration.toLong(), amplitude)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val scale = (intensity * 0.85).toFloat().coerceIn(0.03f, 0.48f)
            try {
                // Paper scrape uses short ticks; CLICK reads as a sharp tap.
                val effect = VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_TICK, scale)
                    .compose()
                vibrator?.vibrate(effect)
                return
            } catch (e: Exception) {
                // fallback
            }
        }

        playFallback(clampedDuration.toLong(), amplitude)
    }

    private fun playThud(intensity: Double) {
        val shouldEmit = shouldEmitVibration()
        android.util.Log.d("HAPTIC_DIAGNOSTIC", "Android playThud: intensity=$intensity, shouldEmit=$shouldEmit")
        if (!shouldEmit) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val scale = (intensity * 0.55).toFloat().coerceIn(0.08f, 0.5f)
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

        val amp = (intensity * 180).toInt().coerceIn(40, 180)
        playFallback(24, amp)
    }

    private fun playSlipBurst(intensity: Double) {
        val shouldEmit = shouldEmitVibration(force = true)
        android.util.Log.d("HAPTIC_DIAGNOSTIC", "Android playSlipBurst: intensity=$intensity, shouldEmit=$shouldEmit")
        if (!shouldEmit) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val scale1 = (intensity * 0.8).toFloat().coerceIn(0.05f, 0.65f)
            val scale2 = (intensity * 0.55).toFloat().coerceIn(0.05f, 0.55f)
            try {
                val effect = VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, scale1)
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_TICK, scale2, 18)
                    .compose()
                vibrator?.vibrate(effect)
                return
            } catch (e: Exception) {
                // fallback
            }
        }

        val amp1 = (intensity * 160).toInt().coerceIn(30, 180)
        val amp2 = (intensity * 100).toInt().coerceIn(15, 120)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val timings = longArrayOf(0, 10, 20, 8)
            if (hasAmplitudeControl) {
                val amplitudes = intArrayOf(0, amp1, 0, amp2)
                vibrator?.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
            } else {
                vibrator?.vibrate(VibrationEffect.createWaveform(timings, -1))
            }
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(longArrayOf(0, 10, 20, 8), -1)
        }
    }

    private fun playSettleThud(intensity: Double) {
        val shouldEmit = shouldEmitVibration(force = true)
        android.util.Log.d("HAPTIC_DIAGNOSTIC", "Android playSettleThud: intensity=$intensity, shouldEmit=$shouldEmit")
        if (!shouldEmit) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val scaleThud = (intensity * 0.6).toFloat().coerceIn(0.08f, 0.6f)
            val scaleTick = (intensity * 0.35).toFloat().coerceIn(0.05f, 0.45f)
            try {
                val effect = VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_THUD, scaleThud)
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_LOW_TICK, scaleTick, 24)
                    .compose()
                vibrator?.vibrate(effect)
                return
            } catch (e: Exception) {
                // fallback
            }
        }

        val amp = (intensity * 180).toInt().coerceIn(40, 180)
        playFallback(24, amp)
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
