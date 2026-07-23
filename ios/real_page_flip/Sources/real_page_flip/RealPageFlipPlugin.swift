import Flutter
import UIKit
import CoreHaptics

public class RealPageFlipPlugin: NSObject, FlutterPlugin {
  private var hapticEngine: CHHapticEngine?
  private var _continuousPlayer: CHHapticAdvancedPatternPlayer?
  // True once the persistent continuous player has been started for the current
  // drag session. Kept alive across flushes so intensity/sharpness are streamed
  // via dynamic parameters instead of stopping+recreating a player every ~40 ms
  // (the old model, which left an audible/tactile gap at every batch boundary).
  private var _continuousStarted = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.chapdcha.real_page_flip/haptics", binaryMessenger: registrar.messenger())
    let instance = RealPageFlipPlugin()
    instance.setupHaptics()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private func setupHaptics() {
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
    do {
      hapticEngine = try CHHapticEngine()
      try hapticEngine?.start()
      hapticEngine?.resetHandler = { [weak self] in
        do { try self?.hapticEngine?.start() } catch { }
        self?._continuousPlayer = nil
        self?._continuousStarted = false
      }
    } catch {
      print("Failed to start CoreHaptics engine: \(error)")
    }
  }

  /// Compact iPhones where continuous Core Haptics reads as a phone-call buzz.
  /// SE + mini form factors share a small chassis / less refined continuous feel.
  private static let budgetHapticMachineIds: Set<String> = [
    "iphone8,4",  // SE (1st generation)
    "iphone12,8", // SE (2nd generation)
    "iphone14,6", // SE (3rd generation)
    "iphone13,1", // 12 mini
    "iphone14,4", // 13 mini
  ]

  private static func currentMachineIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(cString: $0)
      }
    }
  }

  private static func isBudgetHapticDevice() -> Bool {
    let machine = currentMachineIdentifier()
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    return budgetHapticMachineIds.contains(machine)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "playTransient":
      let args = call.arguments as? [String: Any]
      let intensity = args?["intensity"] as? Double ?? 0.5
      let sharpness = args?["sharpness"] as? Double ?? 0.5
      let durationMs = args?["durationMs"] as? Int ?? 8
      playTransient(intensity: Float(intensity), sharpness: Float(sharpness), durationMs: durationMs)
      result(nil)
    case "playThud":
      let args = call.arguments as? [String: Any]
      let intensity = args?["intensity"] as? Double ?? 0.5
      playThud(intensity: Float(intensity))
      result(nil)
    case "playSlipBurst":
      let args = call.arguments as? [String: Any]
      let intensity = args?["intensity"] as? Double ?? 0.5
      playSlipBurst(intensity: Float(intensity))
      result(nil)
    case "playSettleThud":
      let args = call.arguments as? [String: Any]
      let intensity = args?["intensity"] as? Double ?? 0.5
      playSettleThud(intensity: Float(intensity))
      result(nil)
    case "playSystemMedium":
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      result(nil)
    case "playSystemLight":
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      result(nil)
    case "getHapticCapabilities":
      // Compact iPhones (SE, 12/13 mini) have Core Haptics, but continuous
      // `.hapticContinuous` texture reads as a crude phone-call buzz. Downgrade
      // capability flags so `HapticQuality.adaptive` resolves to `.basic`
      // (settle/impulse only) instead of `.premium` continuous drag texture.
      let supportsCoreHaptics = hapticEngine != nil &&
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
      let allowAdvancedTexture = supportsCoreHaptics && !Self.isBudgetHapticDevice()
      result([
        "hasVibrator": true,
        "hasAmplitudeControl": allowAdvancedTexture,
        "hasAdvancedHaptics": allowAdvancedTexture,
      ])

    // ── Continuous waveform API ──────────────────────────────────────
    case "playContinuousWaveform":
      let args = call.arguments as? [String: Any]
      let intensities = args?["intensities"] as? [Double] ?? []
      let totalDurationMs = args?["totalDurationMs"] as? Double ?? 0
      let sharpness = args?["sharpness"] as? Double ?? 0.45
      playContinuousWaveform(intensities: intensities, totalDurationMs: totalDurationMs, sharpness: sharpness)
      result(nil)

    case "stopContinuous":
      stopContinuousHaptics()
      result(nil)

    case "cancel":
      try? _continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
      _continuousPlayer = nil
      _continuousStarted = false
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // -----------------------------------------------------------------------
  // MARK: - Continuous waveform (persistent player + dynamic parameters)
  // -----------------------------------------------------------------------
  //
  // A single long-lived CHHapticAdvancedPatternPlayer is started once per drag
  // session and then MODULATED in real time. Each ~40 ms flush from Dart:
  //   • schedules a CHHapticParameterCurve on .hapticIntensityControl for the
  //     upcoming segment (smooth intensity envelope between the 8 samples), and
  //   • sends an immediate .hapticSharpnessControl dynamic parameter.
  //
  // Because the player is never stopped/recreated between flushes, there is no
  // gap at batch boundaries — the vibration reads as one uninterrupted paper
  // friction texture that tracks fingertip speed, instead of the "tick… tick…"
  // of the old stop-and-restart model.
  //
  // NOTE: iOS-only path — verify on a physical device (CoreHaptics is a no-op
  // in the simulator and unavailable on Windows/CI).

  /// Lazily creates and starts the persistent continuous player.
  private func ensureContinuousPlayer(engine: CHHapticEngine) -> CHHapticAdvancedPatternPlayer? {
    if let player = _continuousPlayer, _continuousStarted { return player }
    do {
      // Base continuous event — dynamic intensity CONTROL (0…1) multiplies this
      // base. Kept below 1.0 so small/mid motors do not start at full phone-buzz
      // before the first parameter curve arrives. Long duration + looping keeps
      // it alive for the whole drag; stopContinuous ends it.
      let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55)
      let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45)
      let event = CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [intensityParam, sharpnessParam],
        relativeTime: 0,
        duration: 8.0
      )
      let pattern = try CHHapticPattern(events: [event], parameters: [])
      let player = try engine.makeAdvancedPlayer(with: pattern)
      player.loopEnabled = true
      try engine.start()
      try player.start(atTime: CHHapticTimeImmediate)
      _continuousPlayer = player
      _continuousStarted = true
      return player
    } catch {
      _continuousPlayer = nil
      _continuousStarted = false
      return nil
    }
  }

  private func playContinuousWaveform(intensities: [Double], totalDurationMs: Double, sharpness: Double) {
    guard let engine = hapticEngine,
          !intensities.isEmpty,
          totalDurationMs >= 4 else {
      if intensities.contains(where: { $0 > 0.6 }) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      }
      return
    }

    guard let player = ensureContinuousPlayer(engine: engine) else {
      let median = intensities.sorted()[intensities.count / 2]
      if median > 0.6 {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      }
      return
    }

    let durationSec = Double(totalDurationMs) / 1000.0
    let sampleCount = intensities.count
    let perSampleSec = durationSec / Double(max(sampleCount, 1))

    // Intensity envelope for the upcoming segment (relative to "now").
    var controlPoints: [CHHapticParameterCurve.ControlPoint] = []
    for (i, amp) in intensities.enumerated() {
      let time = Double(i) * perSampleSec
      let clampedAmp = Float(min(max(amp, 0.0), 1.0))
      controlPoints.append(
        CHHapticParameterCurve.ControlPoint(relativeTime: time, value: clampedAmp)
      )
    }
    let intensityCurve = CHHapticParameterCurve(
      parameterID: .hapticIntensityControl,
      controlPoints: controlPoints,
      relativeTime: 0
    )

    do {
      try player.scheduleParameterCurve(intensityCurve, atTime: CHHapticTimeImmediate)
      let sharpnessControl = CHHapticDynamicParameter(
        parameterID: .hapticSharpnessControl,
        value: Float(min(max(sharpness, 0.0), 1.0)),
        relativeTime: 0
      )
      try player.sendParameters([sharpnessControl], atTime: CHHapticTimeImmediate)
    } catch {
      // Drop the player so the next flush recreates it cleanly.
      _continuousPlayer = nil
      _continuousStarted = false
    }
  }

  private func stopContinuousHaptics() {
    guard let player = _continuousPlayer else {
      _continuousStarted = false
      return
    }
    try? player.stop(atTime: CHHapticTimeImmediate)
    _continuousPlayer = nil
    _continuousStarted = false
  }

  // -----------------------------------------------------------------------
  // MARK: - Legacy discrete methods (backward compatibility)
  // -----------------------------------------------------------------------

  private func playTransient(intensity: Float, sharpness: Float, durationMs: Int) {
    let clampedDurationMs = min(max(durationMs, 1), 500)
    let route = clampedDurationMs <= 25 ? "transient" : "continuous"
    print("[HAPTIC_DIAGNOSTIC] iOS playTransient: intensity=\(intensity), sharpness=\(sharpness), durationMs=\(clampedDurationMs), route=\(route)")
    guard let engine = hapticEngine else {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      return
    }

    // Modulate sharpness dynamically: soft at low intensity, crisp at high intensity
    let modulatedSharpness = min(max(sharpness * 0.7 + intensity * 0.3, 0.0), 1.0)

    let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
    let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: modulatedSharpness)
    let event: CHHapticEvent
    if clampedDurationMs <= 25 {
      event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpnessParam], relativeTime: 0)
    } else {
      event = CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [intensityParam, sharpnessParam],
        relativeTime: 0,
        duration: Double(clampedDurationMs) / 1000.0
      )
    }

    do {
      let pattern = try CHHapticPattern(events: [event], parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      UISelectionFeedbackGenerator().selectionChanged()
    }
  }

  private func playThud(intensity: Float) {
    print("[HAPTIC_DIAGNOSTIC] iOS playThud: intensity=\(intensity)")
    guard let engine = hapticEngine else {
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
      return
    }

    let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
    let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
    let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpnessParam], relativeTime: 0)

    do {
      let pattern = try CHHapticPattern(events: [event], parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
  }

  private func playSlipBurst(intensity: Float) {
    print("[HAPTIC_DIAGNOSTIC] iOS playSlipBurst: intensity=\(intensity)")
    guard let engine = hapticEngine else {
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      return
    }

    // 3 transient bursts in rapid succession (15-20ms spacing) simulating friction slip
    let p1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
    let s1 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
    let e1 = CHHapticEvent(eventType: .hapticTransient, parameters: [p1, s1], relativeTime: 0.0)

    let p2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.75)
    let s2 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.28)
    let e2 = CHHapticEvent(eventType: .hapticTransient, parameters: [p2, s2], relativeTime: 0.02)

    let p3 = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.5)
    let s3 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
    let e3 = CHHapticEvent(eventType: .hapticTransient, parameters: [p3, s3], relativeTime: 0.04)

    do {
      let pattern = try CHHapticPattern(events: [e1, e2, e3], parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
  }

  private func playSettleThud(intensity: Float) {
    print("[HAPTIC_DIAGNOSTIC] iOS playSettleThud: intensity=\(intensity)")
    guard let engine = hapticEngine else {
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
      return
    }

    // Short continuous landing feedback (35ms) combined with a crisp transient thud
    let continuousIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.6)
    let continuousSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
    let continuousEvent = CHHapticEvent(
      eventType: .hapticContinuous,
      parameters: [continuousIntensity, continuousSharpness],
      relativeTime: 0.0,
      duration: 0.035
    )

    let transientIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.95)
    let transientSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
    let transientEvent = CHHapticEvent(
      eventType: .hapticTransient,
      parameters: [transientIntensity, transientSharpness],
      relativeTime: 0.02
    )

    do {
      let pattern = try CHHapticPattern(events: [continuousEvent, transientEvent], parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
  }
}
