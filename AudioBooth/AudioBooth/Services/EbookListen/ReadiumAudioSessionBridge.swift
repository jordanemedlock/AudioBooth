import AVFAudio
import Foundation
import ReadiumShared

/// Bridges Readium's audio session coordination to AudioBooth's shared `AudioSession`.
final class ReadiumAudioSessionBridge: AudioSessionManaging {
  func start(with user: AudioSessionUser, isPlaying: Bool) {
    AudioSession.configure()
    Task { await AudioSession.activate() }
  }

  func end(for user: AudioSessionUser) {
    guard PlayerManager.shared.current?.isPlaying != true else { return }
    AudioSession.deactivate()
  }

  func user(_ user: AudioSessionUser, didChangePlaying isPlaying: Bool) {
    if isPlaying {
      AudioSession.configure()
      Task { await AudioSession.activate() }
    }
  }
}
