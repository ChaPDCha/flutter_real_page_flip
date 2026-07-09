import Flutter
import UIKit
import CoreHaptics

public class RealPageFlipPlugin: NSObject, FlutterPlugin {
  private var hapticEngine: CHHapticEngine?
  private var _continuousPlayer: CHHapticAdvancedPatternPlayer?

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
      }
    } catch {
      print("Failed to start CoreHaptics engine: \(error)")
    }
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

    // ── Continuous waveform API ──────────────────────────────────────
    case "playContinuousWaveform":
      let args = call.arguments as? [String: Any]
      let intensities = args?["intensities"] as? [Double] ?? []
      let totalDurationMs = args?["totalDurationMs"] as? Double ?? 0
      playContinuousWaveform(intensities: intensities, totalDurationMs: totalDurationMs)
      result(nil)

    case "stopContinuous":
      stopContinuousHaptics()
      result(nil)

    case "cancel":
      _continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
      _continuousPlayer = nil
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // -----------------------------------------------------------------------
  // MARK: - Continuous waveform (CoreHaptics parameter curve)
  // -----------------------------------------------------------------------
  //
  // Instead of creating/destroying a new player per transient (the old
  // model), this creates a CHHapticAdvancedPatternPlayer with a continuous
  // event whose intensity is modulated by a CHHapticParameterCurve.
  // Each flush from the Dart side (every ~40ms) stops the previous player
  // and starts a new one with the latest amplitude curve — producing a
  // seamless continuous vibration that feels like paper friction rather
  // than discrete ticks.
  //
  // The base event is .hapticContinuous with a matched duration so the
  // vibration stops cleanly if the next flush is delayed.

  private func playContinuousWaveform(intensities: [Double], totalDurationMs: Double) {
    guard let engine = hapticEngine,
          !intensities.isEmpty,
          totalDurationMs >= 4 else {
      // Fallback: single light tap for very short segments.
      if intensities.contains(where: { $0 > 0.6 }) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      }
      return
    }

    let durationSec = Double(totalDurationMs) / 1000.0
    let sampleCount = intensities.count
    let perSampleSec = durationSec / Double(max(sampleCount, 1))
    let lastIntensity = Float(intensities.last ?? 0.5)

    // ── Build parameter curve control points ──
    // Each sample becomes a control point at its relative time position.
    var controlPoints: [CHHapticParameterCurve.ControlPoint] = []
    for (i, amp) in intensities.enumerated() {
      let time = Double(i) * perSampleSec
      let clampedAmp = Float(min(max(amp, 0.0), 1.0))
      controlPoints.append(
        CHHapticParameterCurve.ControlPoint(relativeTime: time, value: clampedAmp)
      )
    }

    // ── Base continuous event ──
    let intensityParam = CHHapticEventParameter(
      parameterID: .hapticIntensity,
      value: lastIntensity
    )
    let sharpnessParam = CHHapticEventParameter(
      parameterID: .hapticSharpness,
      value: 0.45  // moderate sharpness — paper-like, not buzz
    )
    let event = CHHapticEvent(
      eventType: .hapticContinuous,
      parameters: [intensityParam, sharpnessParam],
      relativeTime: 0,
      duration: TimeInterval(durationSec)
    )

    // ── Intensity curve modulates the continuous event ──
    let intensityCurve = CHHapticParameterCurve(
      parameterID: .hapticIntensity,
      controlPoints: controlPoints,
      relativeTime: 0
    )

    do {
      // Stop the previous segment cleanly.
      _continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
      _continuousPlayer = nil

      let pattern = try CHHapticPattern(
        events: [event],
        parameterCurves: [intensityCurve]
      )
      let player = try engine.createAdvancedPlayer(with: pattern)
      _continuousPlayer = player

      // Schedule start with a tiny delay so the previous stop finishes.
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      _continuousPlayer = nil
      // One-shot fallback using median intensity.
      let median = intensities.sorted()[sampleCount / 2]
      if median > 0.6 {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      }
    }
  }

  private func stopContinuousHaptics() {
    guard _continuousPlayer != nil else { return }
    _continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
    _continuousPlayer = nil
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
      let player = try engine.createPlayer(with: pattern)
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
      let player = try engine.createPlayer(with: pattern)
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
      let player = try engine.createPlayer(with: pattern)
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
      let player = try engine.createPlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
  }
}
