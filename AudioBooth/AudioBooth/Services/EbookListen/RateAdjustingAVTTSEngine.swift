import AVFoundation
import ReadiumNavigator

/// Wraps `AVTTSEngine` and applies a playback-rate multiplier to each utterance.
final class RateAdjustingAVTTSEngine: @unchecked Sendable {
  var rateMultiplier: Float = 1.0

  private let rateDelegate = RateDelegate()

  let engine: AVTTSEngine

  init() {
    rateDelegate.owner = self
    engine = AVTTSEngine(delegate: rateDelegate)
  }

  private final class RateDelegate: NSObject, AVTTSEngineDelegate {
    weak var owner: RateAdjustingAVTTSEngine?

    func avTTSEngine(_ engine: AVTTSEngine, didCreateUtterance utterance: AVSpeechUtterance) {
      guard let adjusting = owner else { return }
      let scaled = AVSpeechUtteranceDefaultSpeechRate * adjusting.rateMultiplier
      utterance.rate = min(
        max(scaled, AVSpeechUtteranceMinimumSpeechRate),
        AVSpeechUtteranceMaximumSpeechRate
      )
    }
  }
}
