import Foundation
import Logging
import MediaPlayer
import Nuke
import UIKit

@MainActor
final class EbookListenNowPlayingManager {
  private var info: [String: Any] = [:]
  private var artwork: MPMediaItemArtwork?

  init(
    bookID: String,
    title: String,
    author: String?,
    coverURL: URL?,
    progress: Double,
    isPlaying: Bool,
    playbackRate: Float
  ) {
    info[MPNowPlayingInfoPropertyExternalContentIdentifier] = "ebook-listen-\(bookID)"
    info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
    info[MPMediaItemPropertyMediaType] = MPMediaType.audioBook.rawValue
    info[MPMediaItemPropertyTitle] = title
    info[MPMediaItemPropertyArtist] = author
    info[MPMediaItemPropertyAlbumTitle] = String(localized: "Listen")
    info[MPMediaItemPropertyPlaybackDuration] = 1.0
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress
    info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = playbackRate
    info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0

    if let coverURL {
      loadArtwork(from: coverURL)
    } else {
      publish(isPlaying: isPlaying, playbackRate: playbackRate)
    }
  }

  func update(progress: Double, isPlaying: Bool, playbackRate: Float) {
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress
    info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = playbackRate
    info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
    publish(isPlaying: isPlaying, playbackRate: playbackRate)
  }

  func clear() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    MPNowPlayingInfoCenter.default().playbackState = .paused
  }

  private func publish(isPlaying: Bool, playbackRate: Float) {
    info[MPMediaItemPropertyArtwork] = artwork
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
  }

  private func loadArtwork(from url: URL) {
    Task {
      do {
        let request = ImageRequest(url: url, processors: [], priority: .high)
        let image = try await ImagePipeline.shared.image(for: request)
        artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        info[MPMediaItemPropertyArtwork] = artwork
        let rate = info[MPNowPlayingInfoPropertyDefaultPlaybackRate] as? Float ?? 1.0
        let playing = (info[MPNowPlayingInfoPropertyPlaybackRate] as? Float ?? 0) > 0
        publish(isPlaying: playing, playbackRate: rate)
      } catch {
        AppLogger.player.error("Failed to load cover for ebook listen now playing: \(error)")
      }
    }
  }
}
