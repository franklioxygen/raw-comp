import SwiftUI

struct AdjustmentSliderRow: View {
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let valueFormatter: (Double) -> String
    var parseValue: (String) -> Double? = ComparisonAdjustmentFormatting.parseNumber
    var onLabelDoubleClick: (() -> Void)?
    var onDragActiveChanged: ((Bool) -> Void)?

    @State private var textValue = ""
    @FocusState private var valueFieldFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .frame(width: 72, alignment: .leading)
                .lineLimit(2)
                .onTapGesture(count: 2) {
                    onLabelDoubleClick?()
                }

            Slider(value: steppedValue, in: range, onEditingChanged: { editing in
                onDragActiveChanged?(editing)
            })
            .labelsHidden()

            TextField("", text: $textValue)
                .textFieldStyle(.plain)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
                .focused($valueFieldFocused)
                .onSubmit(commitTextValue)
                .onChange(of: value.wrappedValue) { _, newValue in
                    guard !valueFieldFocused else {
                        return
                    }

                    textValue = valueFormatter(newValue)
                }
                .onChange(of: valueFieldFocused) { _, focused in
                    if focused {
                        textValue = valueFormatter(value.wrappedValue)
                    } else {
                        commitTextValue()
                    }
                }
                .onAppear {
                    textValue = valueFormatter(value.wrappedValue)
                }
        }
        .opacity(1)
    }

    private func commitTextValue() {
        guard let parsed = parseValue(textValue) else {
            textValue = valueFormatter(value.wrappedValue)
            return
        }

        let stepped = (parsed / step).rounded() * step
        value.wrappedValue = min(max(stepped, range.lowerBound), range.upperBound)
        textValue = valueFormatter(value.wrappedValue)
    }

    private var steppedValue: Binding<Double> {
        Binding(
            get: { value.wrappedValue },
            set: { newValue in
                let stepped = (newValue / step).rounded() * step
                value.wrappedValue = min(max(stepped, range.lowerBound), range.upperBound)
            }
        )
    }
}

struct AdjustmentToggleRow: View {
    let title: String
    let isOn: Binding<Bool>

    var body: some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.caption.weight(.medium))
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}
