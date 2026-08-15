package com.chapdcha.real_page_flip

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

internal class RealPageFlipPluginTest {
    @Test
    fun transientEnvelope_preservesDurationAndSharpness() {
        val crisp = buildTransientEnvelope(0.7, 0.95, 28)
        val soft = buildTransientEnvelope(0.7, 0.10, 28)

        assertEquals(28L, crisp.timings.sum())
        assertEquals(28L, soft.timings.sum())
        assertTrue(crisp.amplitudes.first() > crisp.amplitudes.last())
        assertTrue(soft.amplitudes.last() > crisp.amplitudes.last())
        assertTrue(soft.timings.last() > crisp.timings.last())

        val shortest = buildTransientEnvelope(0.4, 0.0, 1)
        assertEquals(4L, shortest.timings.sum())
    }

    @Test
    fun transientEnvelope_staysValidAcrossNativeInputBounds() {
        val durations = listOf(-20, 1, 4, 16, 17, 28, 500, 1000)
        val intensities = listOf(-1.0, 0.0, 0.2, 0.8, 1.0, 2.0)
        val sharpnesses = listOf(-1.0, 0.0, 0.5, 1.0, 2.0)

        for (duration in durations) {
            for (intensity in intensities) {
                for (sharpness in sharpnesses) {
                    val envelope = buildTransientEnvelope(
                        intensity,
                        sharpness,
                        duration
                    )
                    assertEquals(duration.coerceIn(4, 500).toLong(), envelope.timings.sum())
                    assertTrue(envelope.timings.all { it > 0 })
                    assertTrue(envelope.amplitudes.all { it in 1..255 })
                }
            }
        }
    }

    @Test
    fun transientEnvelope_intensityIsMonotonicForEveryPhase() {
        val quiet = buildTransientEnvelope(0.2, 0.55, 28)
        val strong = buildTransientEnvelope(0.8, 0.55, 28)

        quiet.amplitudes.zip(strong.amplitudes).forEach { (low, high) ->
            assertTrue(high > low)
        }
    }

    @Test
    fun getHapticCapabilities_beforeAttach_reportsUnavailableHardware() {
        val plugin = RealPageFlipPlugin()
        val call = MethodCall("getHapticCapabilities", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(
            mapOf(
                "hasVibrator" to false,
                "hasAmplitudeControl" to false,
                "hasAdvancedHaptics" to false
            )
        )
    }
}
