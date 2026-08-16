import DesignKit
import SwiftUI

/// Screen 06. The close, in the counts that actually happened.
struct CaptureResultScreen: View {
    let session: CaptureSession
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let result = session.result {
                Text(result.summary)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(Palette.ink.color)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Self.lines(result), id: \.self) { line in
                        Text(line)
                            .font(Typography.body)
                            .foregroundStyle(Palette.muted.color)
                    }
                }
            } else {
                EmptyState(glyph: .other, message: "This receipt hasn't been saved yet.")
            }
            Spacer(minLength: 0)
            Button(action: onDone) {
                Text("Done")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.card.color)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Palette.persimmon.color))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.paper.color)
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    /// Only what happened gets a line — a zero is not worth a sentence.
    static func lines(_ result: CaptureResult) -> [String] {
        var lines: [String] = []
        if result.rememberedCount > 0 {
            let plural = result.rememberedCount == 1 ? "line is" : "lines are"
            lines.append("\(result.rememberedCount) \(plural) remembered for the whole kitchen.")
        }
        if result.ignoredCount > 0 {
            let plural = result.ignoredCount == 1 ? "line" : "lines"
            lines.append("\(result.ignoredCount) \(plural) will be skipped from now on.")
        }
        lines.append("The photo stays on this phone, with the trip.")
        return lines
    }
}
