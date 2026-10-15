import Combine
import Foundation
import Logging
import ReadiumNavigator
import ReadiumShared
import UIKit

@MainActor
@Observable
final class EbookListenCoordinator: PublicationSpeechSynthesizerDelegate {
  enum Status: Equatable {
    case off
    case playing
    case paused

    var isActive: Bool {
      self != .off
    }
  }

  struct Settings: Equatable {
    let config: PublicationSpeechSynthesizer.Configuration
    let availableLanguages: [Language]
    let availableVoiceIDs: [String]

    init(synthesizer: PublicationSpeechSynthesizer) {
      let voicesByLanguage = Dictionary(grouping: synthesizer.availableVoices, by: \.language)
      config = synthesizer.config
      availableLanguages = voicesByLanguage.keys.sorted {
        $0.localizedDescription() < $1.localizedDescription()
      }
      availableVoiceIDs =
        synthesizer.config.defaultLanguage
          .flatMap { voicesByLanguage[$0]?.map(\.identifier) }
          ?? synthesizer.availableVoices.map(\.identifier)
    }
  }

  private(set) var status: Status = .off
  private(set) var settings: Settings

  var rateMultiplier: Float = 1.0

  var onProgressChanged: ((Double) -> Void)?
  var onStopped: (() -> Void)?

  private let publication: Publication
  private weak var navigator: (any Navigator)?
  private let synthesizer: PublicationSpeechSynthesizer
  private let ttsEngine: RateAdjustingAVTTSEngine
  private let remoteCommands = EbookListenRemoteCommands()
  private var nowPlaying: EbookListenNowPlayingManager?

  private let bookID: String
  private let title: String
  private let author: String?
  private let coverURL: URL?

  private var playingUtteranceLocator: Locator?
  private var playingWordLocator: Locator?
  private let playingWordRangeSubject = PassthroughSubject<Locator, Never>()
  private var isNavigating = false
  private var subscriptions = Set<AnyCancellable>()

  private static let decorationGroup = "listen"

  init?(
    publication: Publication,
    navigator: any Navigator,
    bookID: String,
    title: String,
    author: String?,
    coverURL: URL?,
    preferences: EbookReaderPreferences
  ) {
    let engine = RateAdjustingAVTTSEngine()
    guard
      let synthesizer = PublicationSpeechSynthesizer(
        publication: publication,
        config: Self.initialConfig(preferences: preferences),
        audioSession: ReadiumAudioSessionBridge(),
        engineFactory: { engine.engine }
      )
    else {
      return nil
    }

    self.publication = publication
    self.navigator = navigator
    self.synthesizer = synthesizer
    self.ttsEngine = engine
    self.settings = Settings(synthesizer: synthesizer)
    self.bookID = bookID
    self.title = title
    self.author = author
    self.coverURL = coverURL
    self.rateMultiplier = Self.clampedRate(Float(preferences.listenSpeed))

    synthesizer.delegate = self
    ttsEngine.rateMultiplier = Self.clampedRate(rateMultiplier)

    bindNavigation()
  }

  private static func clampedRate(_ value: Float) -> Float {
    min(max(value, 0.5), 2.0)
  }

  func toggle() {
    switch status {
    case .off:
      start()
    case .playing:
      synthesizer.pause()
    case .paused:
      synthesizer.resume()
    }
  }

  func stop() {
    synthesizer.stop()
    tearDown()
  }

  func previousSentence() {
    synthesizer.previous()
  }

  func nextSentence() {
    synthesizer.next()
  }

  func setConfig(_ config: PublicationSpeechSynthesizer.Configuration) {
    synthesizer.config = config
    settings = Settings(synthesizer: synthesizer)
  }

  func voiceWithIdentifier(_ id: String) -> TTSVoice? {
    synthesizer.voiceWithIdentifier(id)
  }

  func applyPreferences(_ preferences: EbookReaderPreferences) {
    rateMultiplier = Self.clampedRate(Float(preferences.listenSpeed))
    ttsEngine.rateMultiplier = rateMultiplier
    var config = synthesizer.config
    if let languageCode = preferences.listenLanguageCode {
      config.defaultLanguage = Language(code: .bcp47(languageCode))
    }
    if let voiceID = preferences.listenVoiceIdentifier {
      config.voiceIdentifier = voiceID
    }
    synthesizer.config = config
    settings = Settings(synthesizer: synthesizer)
  }

  // MARK: - Private

  private static func initialConfig(preferences: EbookReaderPreferences) -> PublicationSpeechSynthesizer.Configuration {
    var config = PublicationSpeechSynthesizer.Configuration()
    if let languageCode = preferences.listenLanguageCode {
      config.defaultLanguage = Language(code: .bcp47(languageCode))
    }
    config.voiceIdentifier = preferences.listenVoiceIdentifier
    return config
  }

  private func start() {
    guard status == .off else { return }

    if PlayerManager.shared.isPlaying {
      PlayerManager.shared.pause()
    }

    remoteCommands.onTogglePlayPause = { [weak self] in self?.toggle() }
    remoteCommands.onNextSentence = { [weak self] in self?.nextSentence() }
    remoteCommands.onPreviousSentence = { [weak self] in self?.previousSentence() }
    remoteCommands.register()

    Task {
      let startLocator: Locator?
      if let visual = navigator as? VisualNavigator {
        startLocator = await visual.firstVisibleElementLocator() ?? navigator?.currentLocation
      } else {
        startLocator = navigator?.currentLocation
      }
      synthesizer.start(from: startLocator)
    }
  }

  private func tearDown() {
    status = .off
    playingUtteranceLocator = nil
    playingWordLocator = nil
    remoteCommands.unregister()
    nowPlaying?.clear()
    nowPlaying = nil
    clearDecorations()
    onStopped?()
  }

  private func applyDecorations() {
    guard let decorable = navigator as? DecorableNavigator else { return }

    var decorations: [Decoration] = []
    if let sentence = playingUtteranceLocator {
      decorations.append(
        Decoration(
          id: "listen.sentence",
          locator: sentence,
          style: .highlight(tint: UIColor.systemYellow.withAlphaComponent(0.35), isActive: false)
        )
      )
    }
    if let word = playingWordLocator {
      decorations.append(
        Decoration(
          id: "listen.word",
          locator: word,
          style: .highlight(tint: UIColor.systemOrange.withAlphaComponent(0.5), isActive: true)
        )
      )
    }
    decorable.apply(decorations: decorations, in: Self.decorationGroup)
  }

  private func clearDecorations() {
    (navigator as? DecorableNavigator)?.apply(decorations: [], in: Self.decorationGroup)
  }

  private func bindNavigation() {
    playingWordRangeSubject
      .removeDuplicates()
      .throttle(for: 0.8, scheduler: RunLoop.main, latest: true)
      .sink { [weak self] locator in
        guard let self, let navigator, !self.isNavigating else { return }
        self.isNavigating = true
        Task {
          await navigator.go(to: locator, options: NavigatorGoOptions(animated: false))
          self.isNavigating = false
        }
      }
      .store(in: &subscriptions)
  }

  private func updateNowPlaying(isPlaying: Bool) {
    let progress = navigator?.currentLocation?.locations.totalProgression ?? 0
    if nowPlaying == nil {
      nowPlaying = EbookListenNowPlayingManager(
        bookID: bookID,
        title: title,
        author: author,
        coverURL: coverURL,
        progress: progress,
        isPlaying: isPlaying,
        playbackRate: rateMultiplier
      )
    } else {
      nowPlaying?.update(progress: progress, isPlaying: isPlaying, playbackRate: rateMultiplier)
    }
    onProgressChanged?(progress)
  }

  // MARK: PublicationSpeechSynthesizerDelegate

  func publicationSpeechSynthesizer(
    _ synthesizer: PublicationSpeechSynthesizer,
    stateDidChange synthesizerState: PublicationSpeechSynthesizer.State
  ) {
    switch synthesizerState {
    case .stopped:
      tearDown()

    case let .playing(utterance, range: wordRange):
      status = .playing
      playingUtteranceLocator = utterance.locator
      playingWordLocator = wordRange
      applyDecorations()
      if let wordRange {
        playingWordRangeSubject.send(wordRange)
      }
      updateNowPlaying(isPlaying: true)

    case let .paused(utterance):
      status = .paused
      playingUtteranceLocator = utterance.locator
      applyDecorations()
      updateNowPlaying(isPlaying: false)
    }
  }

  func publicationSpeechSynthesizer(
    _ synthesizer: PublicationSpeechSynthesizer,
    utterance: PublicationSpeechSynthesizer.Utterance,
    didFailWithError error: PublicationSpeechSynthesizer.Error
  ) {
    AppLogger.player.error("Ebook Listen TTS error: \(error)")
  }
}
