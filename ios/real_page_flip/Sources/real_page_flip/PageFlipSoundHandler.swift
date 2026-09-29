import AVFoundation
import Flutter

/// Default page-turn sound for iOS (`com.chapdcha.real_page_flip/sound`).
///
/// Each Dart `DefaultPageFlipSound` instance is identified by an integer `id`
/// and gets a small pool of `AVAudioPlayer`s so rapid turns can overlap.
///
/// Methods:
/// - `load {id, asset}` -> Bool (true once decoded)
/// - `play {id, volume}` -> Bool (false when not loaded)
/// - `unload {id}`
final class PageFlipSoundHandler: NSObject {
  private static let voiceCount = 3

  private let registrar: FlutterPluginRegistrar
  private var playersById: [Int: [AVAudioPlayer]] = [:]
  private var nextVoiceById: [Int: Int] = [:]
  private static var didPrepareSession = false

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "load":
      guard let id = args["id"] as? Int, let asset = args["asset"] as? String else {
        result(FlutterError(code: "BAD_ARGS", message: "load requires id and asset", details: nil))
        return
      }
      result(load(id: id, asset: asset))
    case "play":
      guard let id = args["id"] as? Int,
            let voices = playersById[id],
            !voices.isEmpty else {
        result(false)
        return
      }
      let requested = (args["volume"] as? Double) ?? 0.3
      let volume = Float(min(max(requested, 0), 1))
      let index = nextVoiceById[id] ?? 0
      nextVoiceById[id] = (index + 1) % voices.count
      let player = voices[index]
      PageFlipSoundHandler.prepareSessionIfUnconfigured()
      player.stop()
      player.currentTime = 0
      player.volume = volume
      result(player.play())
    case "unload":
      if let id = args["id"] as? Int {
        playersById[id]?.forEach { $0.stop() }
        playersById.removeValue(forKey: id)
        nextVoiceById.removeValue(forKey: id)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func load(id: Int, asset: String) -> Bool {
    let key = registrar.lookupKey(forAsset: asset)
    guard let path = Bundle.main.path(forResource: key, ofType: nil) else {
      return false
    }
    let url = URL(fileURLWithPath: path)
    var voices: [AVAudioPlayer] = []
    for _ in 0..<PageFlipSoundHandler.voiceCount {
      // AVAudioPlayer cannot decode every container (e.g. Ogg/Opus); a throw
      // here reports `false` so Dart falls back to the next format.
      guard let player = try? AVAudioPlayer(contentsOf: url) else { break }
      player.prepareToPlay()
      voices.append(player)
    }
    guard !voices.isEmpty else { return false }
    playersById[id] = voices
    nextVoiceById[id] = 0
    return true
  }

  /// A page-turn sound must not stop the user's music.
  ///
  /// The session is shared with the host app, so a host-configured category is
  /// left untouched. Only the untouched system default (`.soloAmbient`, which
  /// silences other apps' audio) is switched to `.ambient`: it mixes with other
  /// audio and respects the silent switch, as UI sound effects should.
  private static func prepareSessionIfUnconfigured() {
    guard !didPrepareSession else { return }
    didPrepareSession = true
    let session = AVAudioSession.sharedInstance()
    if session.category == .soloAmbient {
      try? session.setCategory(.ambient)
    }
  }
}
