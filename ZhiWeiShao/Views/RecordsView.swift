import SwiftUI

struct RecordsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.navPath) private var path
    @State private var selected = ""
    @State private var step: NextStep?

    var body: some View {
        let today = ZWFormat.formatISODate(Date())
        let current = selected.isEmpty ? today : selected
        let vm = Present.records(store.state, selected: current, today: today, language: store.language)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.t("饮食日记"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                Text(vm.title)
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 4)

                VStack(spacing: 16) {
                    HStack {
                        Button(store.t("上一周")) { shift(-7) }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .accessibilityIdentifier("prev-week")
                        Spacer()
                        Text(vm.weekLabel)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Palette.secondary)
                        Spacer()
                        Button(store.t("下一周")) { shift(7) }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .accessibilityIdentifier("next-week")
                    }
                    HStack(spacing: 0) {
                        ForEach(vm.days) { day in
                            Button {
                                selected = day.iso
                            } label: {
                                VStack(spacing: 6) {
                                    Text(day.weekday)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(day.selected ? Color.white.opacity(0.75) : Palette.tertiary)
                                    Text(day.dayNum)
                                        .font(.system(size: 17, weight: day.selected ? .medium : .regular))
                                        .monospacedDigit()
                                        .foregroundStyle(day.selected ? Color.white : Palette.ink)
                                    Circle()
                                        .fill(day.isToday ? (day.selected ? Color.white : Palette.ink) : Color.clear)
                                        .frame(width: 4, height: 4)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background {
                                    if day.selected {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Palette.ink)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("day-\(day.iso)")
                            .accessibilityLabel("\(day.weekday) \(day.dayNum)")
                        }
                    }
                }
                .padding(.top, 28)

                if vm.empty {
                    VStack(spacing: 8) {
                        Text(store.t("没有记录"))
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(Palette.ink)
                            .padding(.top, 36)
                            .accessibilityIdentifier("empty-day")
                        Text(store.t("没有记录并不代表没有进食，也不会被算成 0。"))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Palette.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                        PrimaryButton(title: store.t("补记一餐")) {
                            path?.wrappedValue.append(AppRoute.addEntry(mealId: "", date: current))
                        }
                        .padding(.top, 20)
                        TextAction(title: store.t("开始"), action: startMeal)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 36) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(vm.mealCount)")
                                .font(.system(size: 34, weight: .regular))
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                            Text(store.t("餐"))
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Palette.tertiary)
                        }
                        KcalFigure(mode: vm.heroMode, text: vm.heroText, size: 34, unitSize: 12)
                            .accessibilityIdentifier("records-hero")
                        Spacer()
                    }
                    .padding(.top, 32)
                    QuietNote(text: store.t("已留下的记录"))
                        .padding(.top, 6)
                    QuietNote(text: vm.note)
                        .padding(.top, 4)

                    SectionLabel(title: store.t("餐次"), trailing: store.t("补记")) {
                        path?.wrappedValue.append(AppRoute.addEntry(mealId: "", date: current))
                    }
                    .padding(.top, 32)
                    VStack(spacing: 0) {
                        ForEach(Array(vm.meals.enumerated()), id: \.element.id) { index, row in
                            MealRowButton(row: row) {
                                path?.wrappedValue.append(AppRoute.mealDetail(row.id))
                            }
                            if index < vm.meals.count - 1 { Hairline() }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .pageBackground()
        .onAppear {
            if selected.isEmpty { selected = today }
        }
        .overlay {
            if let step {
                NextSheet(step: localized(step), onClose: { self.step = nil }) {
                    let currentStep = step
                    self.step = nil
                    switch currentStep.actionId {
                    case .bind:
                        store.startScan()
                        path?.wrappedValue.append(AppRoute.bind)
                    case .permission:
                        store.openSettings()
                    case .calibrate:
                        path?.wrappedValue.append(AppRoute.device(.calibrate))
                    case .resume:
                        if !store.state.recordingMealId.isEmpty {
                            path?.wrappedValue.append(AppRoute.mealLive(store.state.recordingMealId))
                        }
                    default:
                        path?.wrappedValue.append(AppRoute.device(.none))
                    }
                }
            }
        }
    }

    private func localized(_ step: NextStep) -> NextStep {
        NextStep(title: store.t(step.title), body: store.t(step.body), action: store.t(step.action), actionId: step.actionId)
    }

    private func shift(_ days: Int) {
        let today = ZWFormat.formatISODate(Date())
        let current = selected.isEmpty ? today : selected
        selected = ZWFormat.shiftDate(current, days: days)
    }

    private func startMeal() {
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
}
