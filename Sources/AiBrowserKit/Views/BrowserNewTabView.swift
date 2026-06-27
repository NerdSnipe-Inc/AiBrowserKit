import SwiftUI

/// Landing page shown on new/empty browser tabs.
public struct BrowserNewTabView: View {
    /// Creates the default new-tab landing view.
    public init() {}

    /// Renders the new-tab placeholder content.
    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "globe")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.tertiary)

                Text("New Tab")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))

                Text("Enter a URL or search above")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
            Spacer().frame(height: 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
