import Foundation

/// When set, lock-screen and headset controls route to EPUB Listen mode instead of the audiobook player.
@MainActor
final class EbookListenRemoteCommands {
  static weak var active: EbookListenRemoteCommands?

  var onTogglePlayPause: (() -> Void)?
  var onNextSentence: (() -> Void)?
  var onPreviousSentence: (() -> Void)?

  func register() {
    Self.active = self
  }

  func unregister() {
    if Self.active === self {
      Self.active = nil
    }
  }
}
