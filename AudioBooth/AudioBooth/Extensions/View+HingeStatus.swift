import SwiftUI

extension EnvironmentValues {
  @Entry var isPartiallyFolded: Bool = false
}

extension View {
  func observesHinge() -> some View {
    modifier(HingeStatusModifier())
  }

}

private struct HingeStatusModifier: ViewModifier {
  @State private var isPartiallyFolded = false

  func body(content: Content) -> some View {
    #if targetEnvironment(macCatalyst)
    content
    #else
    hingeAwareBody(content)
    #endif
  }

  @ViewBuilder
  private func hingeAwareBody(content: Content) -> some View {
    #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if #available(iOS 27.1, *) {
      content
        .onHingeChange { _, newContext in
          let newValue = newContext.hinge?.status == .partiallyOpen
          guard newValue != isPartiallyFolded else { return }
          withAnimation {
            isPartiallyFolded = newValue
          }
        }
        .environment(\.isPartiallyFolded, isPartiallyFolded)
    } else {
      content
    }
    #else
    content
    #endif
  }
}
