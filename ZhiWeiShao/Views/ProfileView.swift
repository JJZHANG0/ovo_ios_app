import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.navPath) private var path
    @State private var confirmReset = false

    var body: some View {
        let deviceLine = store.t(Present.deviceChip(store.state.device).label)
        let profileLine = Present.profileSummary(store.state, language: store.language)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.t("个人设置"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                Text(store.t("按你的方式记录"))
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 4)

                HStack(alignment: .center) {
                    Text(store.t("语言"))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                    Spacer(minLength: 12)
                    HStack(spacing: 6) {
                        languageChoice("English", .en, id: "language-en")
                        languageChoice("中文", .zh, id: "language-zh")
                    }
                }
                .padding(.top, 22)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("app-language")

                VStack(spacing: 0) {
                    ProfileLink(title: store.t("我的智慧勺"), value: deviceLine, stacksValue: true, identifier: "profile-device") {
                        path?.wrappedValue.append(AppRoute.device(.none))
                    }
                    Hairline()
                    ProfileLink(title: store.t("设备与同步"), value: store.t("同步记录"), identifier: "profile-sync") {
                        path?.wrappedValue.append(AppRoute.device(.sync))
                    }
                }
                .padding(.horizontal, 16)
                .background { GlassShape(radius: 22) }
                .padding(.top, 28)

                VStack(spacing: 0) {
                    ProfileLink(title: store.t("个人偏好"), value: profileLine, identifier: "profile-prefs") {
                        path?.wrappedValue.append(AppRoute.preferences)
                    }
                    Hairline()
                    HStack {
                        Text(store.t("隐藏热量数字"))
                            .font(.system(size: 17, weight: .regular))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.state.hideCalories },
                            set: { store.setHideCalories($0) }
                        ))
                        .labelsHidden()
                        .tint(Palette.ink)
                        .accessibilityIdentifier("hide-calories")
                    }
                    .frame(minHeight: 52)
                    Hairline()
                    ProfileLink(title: store.t("隐私与数据"), value: "", identifier: "profile-privacy") {
                        path?.wrappedValue.append(AppRoute.privacy)
                    }
                    Hairline()
                    ProfileLink(title: store.t("会员与权益"), value: "", identifier: "profile-membership") {
                        path?.wrappedValue.append(AppRoute.membership)
                    }
                }
                .padding(.top, 28)
                QuietNote(text: store.t("记录只为你自己回顾。"))
                    .padding(.top, 10)

                TextAction(title: store.t("恢复初始记录")) { confirmReset = true }
                    .padding(.top, 36)
                    .accessibilityIdentifier("reset-records")
                QuietNote(text: store.t("恢复后，今天的午餐会回到初始估算。"))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .pageBackground()
        .alert(store.t("恢复初始记录"), isPresented: $confirmReset) {
            Button(store.t("恢复")) { store.resetRecords() }
            Button(store.t("取消"), role: .cancel) {}
        } message: {
            Text(store.t("今天的午餐会回到初始估算。你做过的核对会被清掉。"))
        }
    }

    private func languageChoice(_ title: String, _ language: AppLanguage, id: String) -> some View {
        let on = store.language == language
        return Button {
            store.setLanguage(language)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: on ? .medium : .regular))
                .foregroundStyle(on ? Palette.ink : Palette.tertiary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background {
                    if on {
                        Capsule().fill(Color.black.opacity(0.06))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct ProfileLink: View {
    var title: String
    var value: String
    var stacksValue = false
    var identifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Palette.ink)
                    if !value.isEmpty, stacksValue {
                        Text(value)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Palette.secondary)
                    }
                }
                Spacer(minLength: 8)
                if !value.isEmpty, !stacksValue {
                    Text(value)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.tertiary)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}
