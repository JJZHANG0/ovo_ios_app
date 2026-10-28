import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.navPath) private var path
    @State private var step: NextStep?

    var body: some View {
        let vm = Present.home(store.state, now: Date(), language: store.language)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(vm.dateLine)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                HStack(alignment: .center, spacing: 12) {
                    Text(store.t("今天"))
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    DeviceChip(label: vm.deviceLabel, phase: vm.devicePhase, on: vm.deviceOn) {
                        store.startScan()
                        path?.wrappedValue.append(AppRoute.bind)
                    }
                }
                .padding(.top, 4)

                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.t("今日已记录热量 · 估算"))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Palette.secondary)
                        KcalFigure(mode: vm.heroMode, text: vm.heroText, size: 52, unitSize: 13)
                            .accessibilityIdentifier("home-hero")
                        Text(vm.helper)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Palette.secondary)
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 4)
                    Image("ProductSpoon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 132, height: 168)
                        .accessibilityIdentifier("product-spoon")
                        .accessibilityLabel(store.t("智慧勺"))
                }
                .padding(.top, 28)

                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.actionTitle)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(2)
                            .fixedSize(horizontal: true, vertical: true)
                            .accessibilityIdentifier("home-action-title")
                        Text(vm.actionCopy)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Palette.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: true, vertical: true)
                            .accessibilityIdentifier("home-action-copy")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    SideActionButton(title: vm.primaryLabel, action: onPrimary)
                }
                .padding(.top, 36)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("start-row")

                if vm.savings.visible {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(vm.savings.figure)
                                .font(.system(size: 28, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                            Text("kcal")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Palette.tertiary)
                        }
                        Text(vm.savings.caption)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Palette.secondary)
                        Text(vm.savings.detail)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Palette.tertiary)
                    }
                    .padding(.top, 32)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("month-savings")
                    .accessibilityLabel("\(vm.savings.figure) kcal, \(vm.savings.caption)")
                }

                SectionLabel(title: store.t("最近记录"), trailing: store.t("全部记录")) {
                    NotificationCenter.default.post(name: .openRecords, object: nil)
                }
                .padding(.top, 40)

                if vm.meals.isEmpty {
                    Text(store.t("今天还没有记录"))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 16)
                    QuietNote(text: store.t("没有记录并不代表没有进食。"))
                        .padding(.top, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(vm.meals.enumerated()), id: \.element.id) { index, row in
                            MealRowButton(row: row) {
                                path?.wrappedValue.append(AppRoute.mealDetail(row.id))
                            }
                            if index < vm.meals.count - 1 { Hairline() }
                        }
                    }
                    .padding(.top, 4)
                }

                QuietNote(text: vm.note)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .pageBackground()
        .overlay {
            if let step {
                NextSheet(step: localized(step), onClose: { self.step = nil }) {
                    let current = step
                    self.step = nil
                    route(current)
                }
            }
        }
    }

    private func localized(_ step: NextStep) -> NextStep {
        NextStep(title: store.t(step.title), body: store.t(step.body), action: store.t(step.action), actionId: step.actionId)
    }

    private func onPrimary() {
        if !store.state.recordingMealId.isEmpty {
            path?.wrappedValue.append(AppRoute.mealLive(store.state.recordingMealId))
            return
        }
        switch store.startMeal() {
        case .started(let id):
            path?.wrappedValue.append(AppRoute.mealLive(id))
        case .blocked(let next):
            step = next
        }
    }

    private func route(_ step: NextStep) {
        switch step.actionId {
        case .bind:
            store.startScan()
            path?.wrappedValue.append(AppRoute.bind)
        case .permission:
            store.openSettings()
        case .resume:
            if !store.state.recordingMealId.isEmpty {
                path?.wrappedValue.append(AppRoute.mealLive(store.state.recordingMealId))
            }
        case .calibrate:
            path?.wrappedValue.append(AppRoute.device(.calibrate))
        case .reconnect, .device:
            path?.wrappedValue.append(AppRoute.device(.none))
        }
    }
}

struct DeviceChip: View {
    var label: String
    var phase: DevicePhase
    var on: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(on ? Palette.ink : Palette.tertiary)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(on ? Palette.ink : Palette.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background {
                Capsule().fill(.ultraThinMaterial)
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), Color.black.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )
            }
            .overlay { ConnectionAura(phase: phase, capsule: true) }
            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("device-chip")
        .accessibilityLabel(label)
    }
}

struct SideActionButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minWidth: 72, minHeight: 44, maxHeight: 44)
                .background { GlassShape(radius: 14, dark: true) }
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityIdentifier("primary-action")
    }
}

extension Notification.Name {
    static let openRecords = Notification.Name("zhiweishao.openRecords")
}
