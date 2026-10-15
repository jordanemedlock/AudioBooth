import SwiftUI

extension GeometryProxy {
  var leadingPanelWidth: CGFloat? {
    #if CI_BUILD
    return nil
    #elseif targetEnvironment(macCatalyst)
    return nil
    #else
    guard #available(iOS 27.1, *) else { return nil }
    let division = reservedRegions(kind: .division).first { $0.isActive && $0.frame.minX > 0 }
    return division?.frame.midX
    #endif
  }

  var topPanelHeight: CGFloat? {
    #if CI_BUILD
    return nil
    #elseif targetEnvironment(macCatalyst)
    return nil
    #else
    guard #available(iOS 27.1, *) else { return nil }
    let division = reservedRegions(kind: .division).first { $0.isActive && $0.frame.minY > 0 }
    return division?.frame.minY
    #endif
  }
}
