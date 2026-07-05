import Flutter
import UIKit
import CoreHaptics

public class RealPageFlipPlugin: NSObject, FlutterPlugin {
  private var hapticEngine: CHHapticEngine?

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
      playTransient(intensity: Float(intensity), sharpness: Float(sharpness))
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
    case "cancel":
      // Transients stop automatically, but we handle cancel to prevent errors.
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func playTransient(intensity: Float, sharpness: Float) {
    guard let engine = hapticEngine else {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      return
    }
    
    // Modulate sharpness dynamically: soft at low intensity, crisp at high intensity
    let modulatedSharpness = min(max(sharpness * 0.7 + intensity * 0.3, 0.0), 1.0)
    
    let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
    let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: modulatedSharpness)
    let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpnessParam], relativeTime: 0)
    
    do {
      let pattern = try CHHapticPattern(events: [event], parameters: [])
      let player = try engine.createPlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      UISelectionFeedbackGenerator().selectionChanged()
    }
  }

  private func playThud(intensity: Float) {
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
