import DesignKit
import SwiftUI

/// Every sentence the paywall says, kept out of the view so the honesty rules are unit tests
/// rather than promises: a price is always the App Store's own, "free" appears only where a
/// trial really exists, and nothing here counts down, expires or asks twice.
enum PaywallCopy {
    static func callToAction(_ term: PlusPlan.Term, offer: PlusOffer) -> String {
        let plan = offer.plan(term)
        // An intro price names the year it applies to: "then $19.99 a year" would be the
        // launch window quietly wearing the renewal's clothes.
        let price = plan.introDisplayPrice.map { "\($0) for the first year" }
            ?? "\(plan.displayPrice) \(per(term))"
        guard let days = plan.trialDays else { return "Subscribe — \(price)" }
        return "Start \(days) days free — then \(price)"
    }

    /// The whole deal in one line, on screen before anything is tapped.
    static func terms(_ term: PlusPlan.Term, offer: PlusOffer) -> String {
        let plan = offer.plan(term)
        var sentence = ""
        if let days = plan.trialDays { sentence += "\(days) days free, then " }
        if let intro = plan.introDisplayPrice {
            sentence += "\(intro) for the first year, then \(plan.displayPrice) a year"
        } else {
            sentence += "\(plan.displayPrice) \(term == .monthly ? "a month" : "a year")"
        }
        return sentence + " until you cancel. Cancel any time in the App Store."
    }

    /// A count, stated once. Never "only 0 left", never a colour, never a nudge.
    static func scansLine(used: Int) -> String? {
        guard used > 0 else { return nil }
        return "You've used \(used) free receipt scan\(used == 1 ? "" : "s")."
    }

    static func detail(_ capability: Capability) -> String {
        switch capability {
        case .receiptScanning: return "Scan receipts — every line becomes a real price"
        case .priceHistory: return "Full price history, per item and per shop"
        case .moreThanOneShop: return "More than one shop"
        default: return capability.title
        }
    }

    static var freeForever: String {
        Capability.allCases.filter { !$0.isPlus }.map(\.title).joined(separator: " · ")
    }

    private static func per(_ term: PlusPlan.Term) -> String {
        term == .monthly ? "a month" : "a year"
    }
}

/// Screen 26. It appears after the value has been felt — three receipts in — and never before.
/// Structurally free of dark patterns: the close control is the first thing laid out and never
/// moves, both prices and both terms are readable without a tap, dismissing asks nothing, and
/// there is no timer, no scarcity and no colour that implies loss.
struct PaywallScreen: View {
    let store: SubscriptionStore

    @Environment(\.dismiss) private var dismiss
    @State private var term: PlusPlan.Term = .annual
    @State private var notice: String?
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 0) {
            closeRow
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if store.mayBeOffered {
                        plusFeatures
                        freeForever
                        purchase
                    } else {
                        Notice(standingState, on: .paper)
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Palette.paper.color)
    }

    // MARK: - Chrome

    private var closeRow: some View {
        HStack {
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.ink.color)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bagged Plus")
                .font(Typography.screenTitle)
                .foregroundStyle(Palette.ink.color)
            Text(PlusPlan.headline)
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var standingState: String {
        store.isPlus
            ? "Plus is active on this Apple Account. Nothing else to do."
            : SubscriptionStore.joinerSentence(.receiptScanning)
    }

    // MARK: - What it is

    private var plusFeatures: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Capability.allCases.filter(\.isPlus), id: \.self) { capability in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: symbol(capability))
                        .font(.system(.body))
                        .foregroundStyle(Palette.muted.color)
                        .frame(width: 24)
                    Text(PaywallCopy.detail(capability))
                        .font(Typography.body)
                        .foregroundStyle(Palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func symbol(_ capability: Capability) -> String {
        switch capability {
        case .receiptScanning: return "text.viewfinder"
        case .priceHistory: return "clock.arrow.circlepath"
        default: return "mappin.and.ellipse"
        }
    }

    /// Named on the paywall itself, because someone deciding not to buy has to be able to see
    /// that they lose nothing by closing it.
    private var freeForever: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("FREE FOREVER, WITH OR WITHOUT PLUS")
            Text(PaywallCopy.freeForever)
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
    }

    // MARK: - The money

    @ViewBuilder private var purchase: some View {
        if let offer = store.offer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    planCard(offer.monthly)
                    planCard(offer.annual)
                }
                Text(PaywallCopy.terms(term, offer: offer))
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await buy() }
                } label: {
                    Text(PaywallCopy.callToAction(term, offer: offer))
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Palette.card.color)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Palette.persimmon.color))
                }
                .disabled(isWorking)
            }
        } else {
            // The normal state of every build today: no subscription configuration, so there is
            // no price to quote and nothing is for sale. Saying so beats quoting a US figure.
            Notice("Bagged Plus isn't on sale in this build. Nothing is charged, and everything "
                   + "you already have keeps working.", on: .paper)
        }
    }

    private func planCard(_ plan: PlusOffer.Plan) -> some View {
        let isSelected = plan.term == term
        return Button {
            term = plan.term
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.term == .monthly ? "Monthly" : "Yearly")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                Text(plan.introDisplayPrice ?? plan.displayPrice)
                    .font(Typography.total)
                    .foregroundStyle(Palette.ink.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if plan.introDisplayPrice != nil {
                    Text("first year, then \(plan.displayPrice)")
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.muted.color)
                } else {
                    Text(plan.term == .monthly ? "a month" : "a year")
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.muted.color)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.card.color))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder((isSelected ? Palette.persimmon : Palette.line).color,
                              lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - The small print, which is not small

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let line = PaywallCopy.scansLine(used: store.scansUsed) {
                Text(line)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
            }
            if let notice {
                Notice(notice, tone: .attention, on: .paper)
            }
            Button {
                Task { await restore() }
            } label: {
                Text("Restore purchases")
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink.color)
                    .frame(minHeight: 44)
            }
            .disabled(isWorking)
            AboutLinks(rows: AboutLinks.policyRows)
        }
    }

    // MARK: - Actions

    private func buy() async {
        isWorking = true
        let result = await store.purchase(term)
        isWorking = false
        notice = Self.message(for: result)
        if result == .purchased { dismiss() }
    }

    private func restore() async {
        isWorking = true
        let result = await store.restore()
        isWorking = false
        notice = Self.message(for: result)
        if result == .purchased { dismiss() }
    }

    /// A cancelled purchase says nothing at all — no second ask is what "zero dark patterns"
    /// means at the one moment it is tempting to add one.
    static func message(for result: PurchaseResult) -> String? {
        switch result {
        case .purchased, .cancelled: return nil
        case .unavailable: return "Nothing is on sale in this build, so there's nothing to buy "
            + "or restore yet."
        case .failed(let text): return text
        }
    }
}
