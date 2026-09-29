package com.chapdcha.real_page_flip

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.IOException

/**
 * Default page-turn sound for Android (`com.chapdcha.real_page_flip/sound`).
 *
 * Uses [SoundPool]: short, low-latency, decoded once, and it does not request
 * audio focus, so a page-turn sound never pauses the user's music. Each Dart
 * `DefaultPageFlipSound` instance is identified by an integer `id`.
 *
 * Methods:
 * - `load {id, asset}` -> Boolean (true once decoded)
 * - `play {id, volume}` -> Boolean (false when not loaded)
 * - `unload {id}`
 */
internal class PageFlipSoundHandler(
    private val context: Context,
    private val flutterAssets: FlutterPlugin.FlutterAssets
) : MethodCallHandler {
    private var pool: SoundPool? = null
    private val soundIdsByPlayer = HashMap<Int, Int>()
    private val pendingLoads = HashMap<Int, Result>()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "load" -> {
                    val id = call.argument<Int>("id")
                    val asset = call.argument<String>("asset")
                    if (id == null || asset == null) {
                        result.error("BAD_ARGS", "load requires id and asset", null)
                        return
                    }
                    load(id, asset, result)
                }
                "play" -> {
                    val id = call.argument<Int>("id")
                    val volume = (call.argument<Double>("volume") ?: 0.3)
                        .coerceIn(0.0, 1.0)
                        .toFloat()
                    val soundId = id?.let { soundIdsByPlayer[it] }
                    val currentPool = pool
                    if (soundId == null || currentPool == null) {
                        result.success(false)
                        return
                    }
                    currentPool.play(soundId, volume, volume, 1, 0, 1f)
                    result.success(true)
                }
                "unload" -> {
                    call.argument<Int>("id")?.let { unload(it) }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("SOUND_ERROR", e.message, null)
        }
    }

    private fun ensurePool(): SoundPool {
        pool?.let { return it }
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val created = SoundPool.Builder()
            .setMaxStreams(3)
            .setAudioAttributes(attributes)
            .build()
        created.setOnLoadCompleteListener { _, soundId, status ->
            val pending = pendingLoads.remove(soundId) ?: return@setOnLoadCompleteListener
            if (status != 0) {
                soundIdsByPlayer.entries.removeAll { it.value == soundId }
            }
            mainHandler.post { pending.success(status == 0) }
        }
        pool = created
        return created
    }

    private fun load(id: Int, asset: String, result: Result) {
        val currentPool = ensurePool()
        soundIdsByPlayer.remove(id)?.let { currentPool.unload(it) }

        val path = flutterAssets.getAssetFilePathByName(asset)
        val soundId = try {
            context.assets.openFd(path).use { fd -> currentPool.load(fd, 1) }
        } catch (e: IOException) {
            // openFd only works for uncompressed APK entries. Formats outside
            // aapt's no-compress list (e.g. .opus) are compressed, so decode
            // from a cached copy instead.
            val cached = File(
                context.cacheDir,
                "real_page_flip_" + asset.replace('/', '_')
            )
            if (!cached.exists()) {
                context.assets.open(path).use { input ->
                    cached.outputStream().use { output -> input.copyTo(output) }
                }
            }
            currentPool.load(cached.path, 1)
        }

        if (soundId == 0) {
            result.success(false)
            return
        }
        soundIdsByPlayer[id] = soundId
        pendingLoads[soundId] = result
    }

    private fun unload(id: Int) {
        val currentPool = pool ?: return
        soundIdsByPlayer.remove(id)?.let { currentPool.unload(it) }
        if (soundIdsByPlayer.isEmpty()) release()
    }

    /** Releases the pool. Pending loads complete with `false`. */
    fun release() {
        val pending = pendingLoads.values.toList()
        pendingLoads.clear()
        soundIdsByPlayer.clear()
        pool?.release()
        pool = null
        pending.forEach { mainHandler.post { it.success(false) } }
    }
}
