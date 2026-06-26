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
    case "playSystemMedium":
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      result(nil)
    case "playSystemLight":
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
    
    let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
    let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
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
}
