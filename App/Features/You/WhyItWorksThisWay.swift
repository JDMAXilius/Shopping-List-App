import DesignKit
import SwiftUI

/// The one page where the odd-looking decisions are explained. Reasons only: no health claims,
/// no diagnosis language, nothing that reads as a treatment or a badge (PRODUCT §2).
struct WhyItWorksThisWay: View {
    private struct Reason: Identifiable {
        let title: String
        let body: String

        var id: String { title }
    }

    private static let reasons = [
        Reason(title: "One look, always the same",
               body: "There is no dark mode and there are no themes. The app looks the same "
                   + "every time you open it, so nothing has to be recognised twice — "
                   + "particularly in a shop, holding a phone in one hand."),
        Reason(title: "Nothing to keep up",
               body: "No streaks, no badges, no score. People shop once or twice a week, so a "
                   + "streak would mostly be a record of the weeks you didn't. Anything that "
                   + "can be lost is left out."),
        Reason(title: "Nothing pulls you back",
               body: "Bagged sends nothing to get your attention. There are no re-engagement "
                   + "notifications, no red dots and no surprise rewards. You open it when you "
                   + "need it."),
        Reason(title: "Undo instead of \u{201C}are you sure?\u{201D}",
               body: "A confirmation dialog interrupts every delete to catch the rare wrong "
                   + "one. Undo does the opposite: the action happens, and the way back is one "
                   + "tap, for a while."),
        Reason(title: "The total stays on screen",
               body: "What the trip costs is visible while you shop, so it isn't a number you "
                   + "have to carry. The same goes for what's left: the list says it rather "
                   + "than you remembering it."),
        Reason(title: "Checked items sink, they don't vanish",
               body: "A finished item drops to the bottom and stays readable. Work that "
                   + "disappears is work you can't see you did."),
        Reason(title: "Defaults everywhere",
               body: "Every item you add arrives with a quantity and a price already on it. "
                   + "You can change all of it, and you have to change none of it."),
        Reason(title: "A guess never dresses up as a fact",
               body: "A price from your own receipt is solid; an estimate is lighter, with a "
                   + "\u{223C}; nothing at all is a dash. A total containing an estimate wears "
                   + "\u{2248}. You should never have to wonder which kind of number you are "
                   + "looking at."),
        Reason(title: "The end of a list is arrival, not a party",
               body: "The last tick resolves the total to a real figure, plays one quiet tone "
                   + "and says one line. No confetti, no score, no request for a rating."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Some of Bagged's choices look strange until you know why. Here they are, "
                     + "so you can decide whether they suit you.")
                    .font(Typography.body)
                    .foregroundStyle(Palette.muted.color)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Self.reasons) { reason in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reason.title)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(Palette.ink.color)
                        Text(reason.body)
                            .font(Typography.footnote)
                            .foregroundStyle(Palette.muted.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Palette.card.color))
                    .accessibilityElement(children: .combine)
                }
                Text("People sometimes ask whether this was built with ADHD in mind. Some of it "
                     + "was, along with tired evenings, small kitchens and noisy shops. They are "
                     + "design choices and nothing more: Bagged treats nothing and claims "
                     + "nothing about anyone.")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(Palette.paper.color)
        .navigationTitle("Why it works this way")
        .navigationBarTitleDisplayMode(.inline)
    }
}
