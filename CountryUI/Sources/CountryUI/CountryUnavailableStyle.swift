import SwiftUI

struct CountryUnavailableStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .buttonStyle(.bordered)
    }
}

extension View {
    func countryUnavailableStyle() -> some View {
        modifier(CountryUnavailableStyle())
    }
}
