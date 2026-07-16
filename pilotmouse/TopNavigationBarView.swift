import SwiftUI

struct TopNavigationBarView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 90)

            Spacer(minLength: 12)

            Picker("Section", selection: selectedTabBinding) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.displayName).tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 640)

            Spacer(minLength: 12)

            Color.clear
                .frame(width: 90)
        }
        .padding(.top, 8)
        .padding(.horizontal, 10)
        .frame(height: 52)
        .background(AppColors.windowBackground)
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { settingsStore.settings.selectedTab },
            set: { settingsStore.setSelectedTab($0) }
        )
    }
}

#Preview {
    TopNavigationBarView(settingsStore: SettingsStore())
        .frame(width: 860)
}
