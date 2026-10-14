import AVFoundation
import ReadiumNavigator

/// `AVTTSEngine` that applies a playback-rate multiplier to each utterance.
final class RateAdjustingAVTTSEngine: AVTTSEngine {
  var rateMultiplier: Float = 1.0

  private let rateDelegate = RateDelegate()

  init() {
    super.init(delegate: nil)
    rateDelegate.engine = self
    delegate = rateDelegate
  }

  private final class RateDelegate: NSObject, AVTTSEngineDelegate {
    weak var engine: RateAdjustingAVTTSEngine?

    func avTTSEngine(_ engine: AVTTSEngine, didCreateUtterance utterance: AVSpeechUtterance) {
      guard let adjusting = self.engine else { return }
      let scaled = AVSpeechUtteranceDefaultSpeechRate * adjusting.rateMultiplier
      utterance.rate = min(
        max(scaled, AVSpeechUtteranceMinimumSpeechRate),
        AVSpeechUtteranceMaximumSpeechRate
      )
    }
  }
}
