import Foundation
import Models
import ReadiumNavigator
import ReadiumShared

extension EbookReaderViewModel {
  var isListenSupported: Bool {
    guard let publication, publication.conforms(to: .epub), publication.metadata.layout != .fixed else {
      return false
    }
    return PublicationSpeechSynthesizer.canSpeak(publication: publication)
  }

  func toggleListen() {
    if let listen, listen.status.isActive {
      listen.toggle()
      return
    }

    if readAlong?.status.isActive == true {
      tearDownReadAlong()
    }

    startListen()
  }

  func tearDownListen() {
    listen?.stop()
    listen = nil
  }

  func syncListenPreferences() {
    listen?.applyPreferences(preferences)
  }

  private func startListen() {
    guard isListenSupported, let publication, let navigator, let metadata = listenMetadata() else {
      Toast(error: String(localized: "This ebook can't be read aloud.")).show()
      return
    }

    guard
      let coordinator = EbookListenCoordinator(
        publication: publication,
        navigator: navigator,
        bookID: metadata.bookID,
        title: metadata.title,
        author: metadata.author,
        coverURL: metadata.coverURL,
        preferences: preferences
      )
    else {
      Toast(error: String(localized: "This ebook can't be read aloud.")).show()
      return
    }

    coordinator.onProgressChanged = { [weak self] progress in
      guard let self else { return }
      self.progress = progress
      self.syncProgressToServer(progress)
    }

    coordinator.onStopped = { [weak self] in
      guard let self else { return }
      self.listen = nil
      self.updateAutoScroll()
    }

    listen = coordinator
    updateAutoScroll()
    coordinator.toggle()
  }

  private func listenMetadata() -> (bookID: String, title: String, author: String?, coverURL: URL?)? {
    switch source {
    case .local(_, let bookID):
      guard let localBook = try? LocalBook.fetch(bookID: bookID) else { return nil }
      return (
        bookID,
        localBook.title,
        localBook.authorNames.nilIfEmpty,
        localBook.coverFile ?? localBook.coverURL
      )
    case .book(let book):
      return (book.id, book.title, book.authorName, book.coverURL())
    case .temporary:
      let title = publication?.metadata.title ?? String(localized: "Ebook")
      let author = publication?.metadata.authors.map(\.name).joined(separator: ", ")
      return ("temporary-ebook", title, author.nilIfEmpty, nil)
    }
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
