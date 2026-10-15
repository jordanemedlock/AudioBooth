import ReadiumNavigator
import ReadiumShared
import SwiftUI

struct EbookListenControlsView: View {
  @Bindable var listen: EbookListenCoordinator
  @ObservedObject var preferences: EbookReaderPreferences
  @State private var showSettings = false

  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 28) {
        Button(action: listen.previousSentence) {
          Image(systemName: "backward.fill")
            .font(.title3)
        }
        .accessibilityLabel("Previous sentence")

        Button(action: listen.toggle) {
          Image(systemName: listen.status == .playing ? "pause.fill" : "play.fill")
            .font(.title)
        }
        .accessibilityLabel(listen.status == .playing ? "Pause" : "Play")

        Button(action: listen.nextSentence) {
          Image(systemName: "forward.fill")
            .font(.title3)
        }
        .accessibilityLabel("Next sentence")
      }

      HStack {
        Button {
          showSettings = true
        } label: {
          Label("Voice", systemImage: "person.wave.2")
            .font(.caption)
        }

        Spacer()

        Menu {
          ForEach(EbookReaderPreferences.listenSpeedPresets, id: \.self) { speed in
            Button {
              preferences.listenSpeed = speed
              listen.applyPreferences(preferences)
            } label: {
              if abs(preferences.listenSpeed - speed) < 0.01 {
                Label(speed.formatted(.number.precision(.fractionLength(2))), systemImage: "checkmark")
              } else {
                Text(speed.formatted(.number.precision(.fractionLength(2))))
              }
            }
          }
        } label: {
          Label(
            preferences.listenSpeed.formatted(.number.precision(.fractionLength(2))),
            systemImage: "gauge.with.needle"
          )
          .font(.caption)
        }
        .accessibilityLabel("Speech speed")

        Spacer()

        Button(role: .destructive, action: listen.stop) {
          Label("Stop", systemImage: "stop.fill")
            .font(.caption)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .sheet(isPresented: $showSettings) {
      EbookListenSettingsView(listen: listen, preferences: preferences)
    }
  }
}

private struct EbookListenSettingsView: View {
  @Bindable var listen: EbookListenCoordinator
  @ObservedObject var preferences: EbookReaderPreferences
  @Environment(\.dismiss) private var dismiss

  private typealias Config = PublicationSpeechSynthesizer.Configuration

  var body: some View {
    NavigationStack {
      Form {
        Picker("Language", selection: languageBinding) {
          Text("Default").tag(Optional<String>.none)
          ForEach(listen.settings.availableLanguages, id: \.code.bcp47) { language in
            Text(language.localizedDescription()).tag(Optional(language.code.bcp47))
          }
        }

        Picker("Voice", selection: voiceBinding) {
          Text("Default").tag(Optional<String>.none)
          ForEach(listen.settings.availableVoiceIDs, id: \.self) { voiceID in
            Text(listen.voiceWithIdentifier(voiceID)?.name ?? voiceID).tag(Optional(voiceID))
          }
        }
      }
      .navigationTitle("Listen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  private var languageBinding: Binding<String?> {
    Binding(
      get: { preferences.listenLanguageCode },
      set: { newValue in
        preferences.listenLanguageCode = newValue
        listen.applyPreferences(preferences)
      }
    )
  }

  private var voiceBinding: Binding<String?> {
    Binding(
      get: { preferences.listenVoiceIdentifier },
      set: { newValue in
        preferences.listenVoiceIdentifier = newValue
        listen.applyPreferences(preferences)
      }
    )
  }
}
