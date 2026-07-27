package com.chapdcha.real_page_flip

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class RealPageFlipPluginTest {
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
