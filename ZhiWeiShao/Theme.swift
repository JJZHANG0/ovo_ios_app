import SwiftUI
import UIKit

enum Palette {
    static let background = Color(red: 0.961, green: 0.961, blue: 0.969)
    static let ink = Color(red: 0.067, green: 0.067, blue: 0.075)
    static let secondary = Color(red: 0.431, green: 0.431, blue: 0.451)
    static let tertiary = Color(red: 0.525, green: 0.525, blue: 0.545)
    static let line = Color.black.opacity(0.08)
    static let inkUI = UIColor(red: 0.067, green: 0.067, blue: 0.075, alpha: 1)
    static let tertiaryUI = UIColor(red: 0.525, green: 0.525, blue: 0.545, alpha: 1)
}

enum TabChrome {
    static func apply() {
        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        tab.backgroundColor = UIColor(white: 1, alpha: 0.52)
        tab.shadowColor = UIColor(white: 0, alpha: 0.08)
        let item = UITabBarItemAppearance()
        item.normal.iconColor = Palette.tertiaryUI
        item.normal.titleTextAttributes = [
            .foregroundColor: Palette.tertiaryUI,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
        ]
        item.selected.iconColor = Palette.inkUI
        item.selected.titleTextAttributes = [
            .foregroundColor: Palette.inkUI,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
        ]
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = Palette.inkUI
        UITabBar.appearance().unselectedItemTintColor = Palette.tertiaryUI

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        nav.backgroundColor = UIColor(white: 1, alpha: 0.55)
        nav.shadowColor = UIColor(white: 0, alpha: 0.06)
        nav.titleTextAttributes = [
            .foregroundColor: Palette.inkUI,
            .font: UIFont.systemFont(ofSize: 17, weight: .regular),
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = Palette.inkUI
    }
}

struct PageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            ZStack {
                Palette.background
                LinearGradient(
                    colors: [Color.white, Color.white.opacity(0)],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.32)
                )
            }
            .ignoresSafeArea()
        }
    }
}

extension View {
    func pageBackground() -> some View {
        modifier(PageBackground())
    }
}

struct GlassShape: View {
    var radius: CGFloat = 22
    var dark: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(dark ? AnyShapeStyle(Color.black.opacity(0.84)) : AnyShapeStyle(.ultraThinMaterial))
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: dark
                            ? [Color.white.opacity(0.42), Color.white.opacity(0.08)]
                            : [Color.white.opacity(0.96), Color.white.opacity(0.28), Color.black.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.7
                )
            }
            .overlay {
                shape
                    .inset(by: 0.8)
                    .stroke(Color.white.opacity(dark ? 0.22 : 0.85), lineWidth: 0.8)
                    .blur(radius: 0.5)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.42)
                        )
                    )
            }
            .overlay {
                shape
                    .stroke(Color.black.opacity(dark ? 0.28 : 0.05), lineWidth: 7)
                    .blur(radius: 3)
                    .mask(shape)
            }
            .shadow(color: Color.black.opacity(dark ? 0.18 : 0.045), radius: dark ? 16 : 14, y: 8)
    }
}

struct ConnectionAura: View {
    var phase: DevicePhase
    var radius: CGFloat = 22
    var capsule: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: phase != .connecting && phase != .scanning && phase != .syncing && phase != .connected)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let shape: AnyShape = capsule
                ? AnyShape(Capsule())
                : AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            if phase == .connecting || phase == .scanning || phase == .syncing {
                let angle = (time.truncatingRemainder(dividingBy: 1.5) / 1.5) * 360
                shape.stroke(
                    AngularGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.95), location: 0.05),
                            .init(color: .white.opacity(0.2), location: 0.1),
                            .init(color: .clear, location: 0.18),
                            .init(color: .clear, location: 1),
                        ],
                        center: .center,
                        angle: .degrees(angle)
                    ),
                    lineWidth: 1.7
                )
            } else if phase == .connected {
                let breath = (sin(time / 5.8 * .pi * 2) + 1) / 2
                shape
                    .stroke(Color.white.opacity(0.28 + 0.6 * breath), lineWidth: 1.15)
                    .shadow(color: Color.black.opacity(0.035 + 0.05 * breath), radius: 7)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct KcalFigure: View {
    var mode: HeroMode
    var text: String
    var size: CGFloat
    var unitSize: CGFloat = 13

    var body: some View {
        if mode == .value {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(text)
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("kcal")
                    .font(.system(size: unitSize, weight: .regular))
                    .foregroundStyle(Palette.tertiary)
            }
            .accessibilityLabel("\(text) kcal")
        } else {
            Text(text)
                .font(.system(size: max(20, size * 0.42), weight: .regular))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PrimaryButton: View {
    var title: String
    var enabled: Bool = true
    var identifier: String = "primary-action"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(enabled ? 1 : 0.72))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background { GlassShape(radius: 16, dark: true).opacity(enabled ? 1 : 0.45) }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
    }
}

struct QuietButton: View {
    var title: String
    var identifier: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background { GlassShape(radius: 16) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

struct TextAction: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}

struct MealRowButton: View {
    var row: MealRowVM
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.name)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Palette.ink)
                    Text(row.meta)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    if row.kcalMode == .value {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(row.kcalText)
                                .font(.system(size: 17, weight: .regular))
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                            Text("kcal")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Palette.tertiary)
                        }
                    } else {
                        Text(row.kcalText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Palette.secondary)
                    }
                    Text(row.status)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(row.tone == .ok ? Palette.tertiary : Palette.ink)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.tertiary)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("meal-\(row.id)")
        .accessibilityLabel("\(row.name)，\(row.kcalText)，\(row.status)")
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(height: 0.5)
    }
}

struct SectionLabel: View {
    var title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Palette.ink)
            Spacer()
            if let trailing, let action {
                Button(trailing, action: action)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.ink)
            }
        }
    }
}

struct QuietNote: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(Palette.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct FieldLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(Palette.secondary)
    }
}

struct LineField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(Palette.ink)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { Hairline() }
    }
}

struct PushScaffold<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    var body: some View {
        content()
            .pageBackground()
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel(store.t("返回"))
                }
                if !title.isEmpty {
                    ToolbarItem(placement: .principal) {
                        Text(title)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Palette.ink)
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct NextSheet: View {
    var step: NextStep
    var onClose: () -> Void
    var onGo: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                Text(step.title)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Palette.ink)
                Text(step.body)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton(title: step.action, identifier: "step-action", action: onGo)
                    .padding(.top, 8)
            }
            .padding(24)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.8), lineWidth: 0.7)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 20, y: -4)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .accessibilityIdentifier("next-sheet")
    }
}

struct PriceText: View {
    var price: Int
    var size: CGFloat = 17

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("¥")
                .font(.system(size: max(11, size * 0.72), weight: .regular))
                .foregroundStyle(Palette.secondary)
            Text(ZWFormat.formatInt(price))
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
        }
        .accessibilityLabel("¥\(ZWFormat.formatInt(price))")
    }
}
