import XCTest
import Core
@testable import DesignKit

// W5-P4's two API gaps, verified where they are verifiable without a UI harness: the
// strings VoiceOver will speak, and the token the disabled mic wears. The gestures
// themselves (tick vs body) need a snapshot/UI harness — see the packet's gap note.
final class ComponentSemanticsTests: XCTestCase {

    private func usd(_ minor: Int) -> Money { Money(minorUnits: minor, currencyCode: "USD") }

    // MARK: ItemRow — the prompt rule

    func testPromptShowsOnlyOnAnUnpricedRow() {
        XCTAssertEqual(
            ItemRowSemantics.visiblePrompt(prompt: "tap to set what you paid", price: .none),
            "tap to set what you paid")
        // A row that has a price is not asking for one, whatever the caller passes.
        XCTAssertNil(ItemRowSemantics.visiblePrompt(
            prompt: "tap to set what you paid",
            price: PriceDisplay(amount: usd(449), confidence: .trusted)))
        XCTAssertNil(ItemRowSemantics.visiblePrompt(
            prompt: "tap to set what you paid", price: .estimated(usd(500))))
        XCTAssertNil(ItemRowSemantics.visiblePrompt(prompt: nil, price: .none))
    }

    // MARK: ItemRow — the quantity slot states what the database holds (W5-P7)

    func testQuantitySlotStatesFractionsAndUnitsVerbatim() {
        // The reason this slot stopped being an Int: 1.5 lb is a real row. It renders,
        // and it renders as itself — not rounded to a ×2 nobody typed.
        for shown in ["1.5 lb", "½ dozen", "2 lb", "×2", "3 punnets"] {
            XCTAssertEqual(
                ItemRowSemantics.visibleQuantity(quantity: shown, visiblePrompt: nil), shown)
        }
    }

    func testAFractionalQuantityIsSpokenExactlyAsItIsShown() {
        XCTAssertEqual(
            ItemRowSemantics.label(
                name: "Chicken breast", quantity: "1.5 lb",
                price: PriceDisplay(amount: usd(899), confidence: .trusted),
                visiblePrompt: nil, isChecked: false),
            "Chicken breast, 1.5 lb, $8.99, not checked")
    }

    func testNothingToSayShowsAndSpeaksNothing() {
        XCTAssertNil(ItemRowSemantics.visibleQuantity(quantity: nil, visiblePrompt: nil))
        // A blank string is nothing to say — never an empty line under the name.
        XCTAssertNil(ItemRowSemantics.visibleQuantity(quantity: "", visiblePrompt: nil))
        XCTAssertNil(ItemRowSemantics.visibleQuantity(quantity: "   ", visiblePrompt: nil))
        XCTAssertEqual(
            ItemRowSemantics.label(
                name: "Bananas", quantity: nil, price: .estimated(usd(200)),
                visiblePrompt: nil, isChecked: false),
            "Bananas, about $2.00, estimated, not checked")
    }

    func testPromptStillOwnsTheSlotWhenItIsOnScreen() {
        // The mutual exclusion, unchanged: a prompted row never shows both, and never
        // speaks a quantity it isn't showing.
        XCTAssertNil(ItemRowSemantics.visibleQuantity(
            quantity: "1.5 lb", visiblePrompt: "tap to set what you paid"))
        XCTAssertEqual(
            ItemRowSemantics.label(
                name: "Chicken breast", quantity: "1.5 lb", price: .none,
                visiblePrompt: ItemRowSemantics.visiblePrompt(
                    prompt: "tap to set what you paid", price: .none),
                isChecked: false),
            "Chicken breast, tap to set what you paid, not checked")
    }

    // MARK: ItemRow — the two named actions must never collide or lie

    func testOpenActionIsNamedForWhatItActuallyDoes() {
        XCTAssertEqual(
            ItemRowSemantics.openActionName(visiblePrompt: "tap to set what you paid"),
            "Set price")
        // No prompt on screen → the body tap opens the item; say that, not "Set price".
        XCTAssertEqual(ItemRowSemantics.openActionName(visiblePrompt: nil), "Open details")
    }

    func testTheTwoActionNamesAreDistinct() {
        for prompt in ["tap to set what you paid", nil] {
            XCTAssertNotEqual(ItemRowSemantics.openActionName(visiblePrompt: prompt), "Check off")
        }
    }

    // MARK: ItemRow — still ONE phrase, unchanged by the new closure

    func testLabelIsOneCoherentPhrase() {
        XCTAssertEqual(
            ItemRowSemantics.label(
                name: "Oat milk", quantity: "×2",
                price: PriceDisplay(amount: usd(449), confidence: .trusted),
                visiblePrompt: nil, isChecked: false),
            "Oat milk, ×2, $4.49, not checked")
    }

    func testLabelSpeaksTheGapAndThePrompt() {
        XCTAssertEqual(
            ItemRowSemantics.label(
                name: "Bread", quantity: nil, price: .none,
                visiblePrompt: ItemRowSemantics.visiblePrompt(
                    prompt: "tap to set what you paid", price: .none),
                isChecked: false),
            "Bread, no price yet, tap to set what you paid, not checked")
    }

    func testCheckedRowSaysSo() {
        XCTAssertEqual(
            ItemRowSemantics.label(
                name: "Eggs", quantity: nil, price: .estimated(usd(437)),
                visiblePrompt: nil, isChecked: true),
            "Eggs, about $4.50, estimated, checked")
    }

    // MARK: InputBar — an inert control never wears the action colour (PRODUCT.md §2)

    func testDisabledMicIsMutedNotPersimmon() {
        XCTAssertEqual(InputBar.micFill(isEnabled: true), Palette.persimmon)
        XCTAssertEqual(InputBar.micFill(isEnabled: false), Palette.muted)
        XCTAssertNotEqual(InputBar.micFill(isEnabled: false), Palette.persimmon)
    }

    // MARK: SectionLabel — the tone rule, enforced rather than documented (W6-P1)

    func testTheDefaultToneIsMutedAndIsLegalOnEitherGround() {
        // Why the one-argument initializer can omit the surface at all.
        for surface in Palette.Surface.allCases {
            XCTAssertTrue(SectionLabel.isLegible(tone: .muted, on: surface))
            XCTAssertEqual(SectionLabel.foreground(tone: .muted, surface: surface), Palette.muted)
        }
    }

    func testAttentionIsPersimmonOnCard() {
        XCTAssertTrue(SectionLabel.isLegible(tone: .attention, on: .card))
        XCTAssertEqual(
            SectionLabel.foreground(tone: .attention, surface: .card), Palette.persimmon)
    }

    func testAttentionOnPaperIsRefused() {
        // The rule that was being re-decided at six sites: persimmon at caption size holds
        // contrast on card, never on paper. Here it is a value, not a comment.
        XCTAssertFalse(SectionLabel.isLegible(tone: .attention, on: .paper))
        XCTAssertNotEqual(
            SectionLabel.foreground(tone: .attention, surface: .paper), Palette.persimmon)
    }

    func testTheRefusalKeepsTheEmphasisInsteadOfDeletingIt() {
        // Ink, not muted: falling back to muted would silently turn an asking label into an
        // ordinary one — the bug would leave no trace on screen for anyone to notice.
        XCTAssertEqual(SectionLabel.foreground(tone: .attention, surface: .paper), Palette.ink)
        XCTAssertNotEqual(
            SectionLabel.foreground(tone: .attention, surface: .paper),
            SectionLabel.foreground(tone: .muted, surface: .paper))
    }

    func testNoToneAndGroundCombinationEverRendersPersimmonOffCard() {
        for surface in Palette.Surface.allCases {
            for tone in [SectionLabel.Tone.muted, .attention]
            where SectionLabel.foreground(tone: tone, surface: surface) == Palette.persimmon {
                XCTAssertEqual(surface, .card)
            }
        }
    }

    func testUppercaseIsTheRenderingAndIsIdempotent() {
        // Casing moved into the component with the tracking; already-uppercased callers
        // must render exactly as they did before the migration.
        XCTAssertEqual(SectionLabel.display("Produce"), "PRODUCE")
        XCTAssertEqual(SectionLabel.display("TOTAL"), "TOTAL")
        XCTAssertEqual(
            SectionLabel.display(SectionLabel.display("Completed (3)")), "COMPLETED (3)")
    }

    // MARK: UndoBar — absence is the disabled state, and the wording is one string (W6-P1)

    func testNothingToUndoDrawsNothing() {
        // Absent, never a disabled control: there is no colour for "undo you can't press".
        XCTAssertNil(UndoBarSemantics.visiblePhrase(nil))
        XCTAssertNil(UndoBarSemantics.visiblePhrase(""))
        XCTAssertNil(UndoBarSemantics.visiblePhrase("   "))
    }

    func testAnOfferAlwaysNamesWhatComesBack() {
        XCTAssertEqual(
            UndoBarSemantics.visiblePhrase("  bread back on the list  "),
            "bread back on the list")
        XCTAssertEqual(
            UndoBarSemantics.line("bread back on the list"),
            "Undo · bread back on the list")
    }

    func testTheOfferIsNeverTheBareWord() {
        // "Undo" alone would stand for two different restores; the separator never dangles.
        let line = UndoBarSemantics.line("scan discarded")
        XCTAssertNotEqual(line, UndoBarSemantics.actionWord)
        XCTAssertFalse(line.hasSuffix(UndoBarSemantics.separator))
    }

    func testTheSpokenOfferMatchesTheWrittenOne() {
        XCTAssertEqual(
            UndoBarSemantics.accessibilityLabel("unicorn steaks back to ×1, checked"),
            "Undo, unicorn steaks back to ×1, checked")
    }

    func testTheUndoDwellIsAContractNotAPerScreenNumber() {
        // The bounds that make 8s defensible, tested instead of the literal: above the read
        // + glance + reach budget (~7.5s), and below WCAG 2.2.1's 20s threshold, past which
        // a timed offer would owe the user a control to extend it.
        XCTAssertGreaterThan(Motion.undoDwell, .seconds(7))
        XCTAssertLessThan(Motion.undoDwell, .seconds(20))
    }

    // MARK: Palette.Surface — the fill inversion, defined once

    func testAnInsetFillNeverMatchesTheGroundItSitsOn() {
        for surface in Palette.Surface.allCases {
            XCTAssertNotEqual(surface.insetFill, surface.fill)
        }
        XCTAssertEqual(Palette.Surface.card.insetFill, Palette.paper)
        XCTAssertEqual(Palette.Surface.paper.insetFill, Palette.card)
    }

    func testTheInsetOfASurfaceIsTheOtherOneAndItsFill() {
        for surface in Palette.Surface.allCases {
            XCTAssertNotEqual(surface.inset, surface)
            XCTAssertEqual(surface.inset.inset, surface)
            XCTAssertEqual(surface.insetFill, surface.inset.fill)
        }
    }

    // MARK: Palette.Emphasis — the persimmon rule now has ONE home (W6-P4)

    func testEveryComponentReadsTheSamePersimmonRule() {
        // SectionLabel's statics became forwards. If they ever stop agreeing with the shared
        // rule, three components have started drifting and this fails first.
        for surface in Palette.Surface.allCases {
            for tone in Palette.Emphasis.allCases {
                XCTAssertEqual(SectionLabel.isLegible(tone: tone, on: surface),
                               surface.allows(tone))
                XCTAssertEqual(SectionLabel.foreground(tone: tone, surface: surface),
                               surface.text(tone))
            }
        }
    }

    func testThereIsNoEmphasisThatMeansDone() {
        // Green is a fact, not a volume knob: no emphasis resolves to it on any fill.
        for surface in Palette.Surface.allCases {
            for tone in Palette.Emphasis.allCases {
                XCTAssertNotEqual(surface.text(tone), Palette.confirmed)
            }
        }
    }

    // MARK: Chip — tones are semantic, and none of them is green (W6-P4)

    func testASureLineIsNeverMarkedDone() {
        // The ruling: `sure` is the machine's confidence in its own parse, before review
        // commits anything — nothing is measured and nothing is done, so it takes `.neutral`
        // and no marker colour. Nothing in the enum can produce confirmed green either.
        for tone in Chip.Tone.allCases {
            XCTAssertNotEqual(Chip.ring(tone: tone), Palette.confirmed)
            for surface in Palette.Surface.allCases {
                XCTAssertNotEqual(Chip.label(tone: tone, on: surface), Palette.confirmed)
            }
        }
    }

    func testANeutralChipIsInkAndAHairlineOnEitherGround() {
        for surface in Palette.Surface.allCases {
            XCTAssertEqual(Chip.label(tone: .neutral, on: surface), Palette.ink)
        }
        XCTAssertEqual(Chip.ring(tone: .neutral), Palette.line)
    }

    func testTheAttentionRingIsWhatSurvivesWhenTheColourIsRefused() {
        // On paper the chip is filled card, where persimmon text is legal.
        XCTAssertEqual(Chip.label(tone: .attention, on: .paper), Palette.persimmon)
        // Inside a card it is filled paper, where it is refused — the ring still carries it,
        // which is why `not sure` on a review row is legible as itself and not as `sure`.
        XCTAssertEqual(Chip.label(tone: .attention, on: .card), Palette.ink)
        XCTAssertEqual(Chip.ring(tone: .attention), Palette.persimmon)
        XCTAssertNotEqual(Chip.ring(tone: .attention), Chip.ring(tone: .neutral))
    }

    func testOnlyATappableChipClaimsATouchTarget() {
        XCTAssertEqual(Chip.minimumHeight(isTappable: true), 44)
        // A confidence marker is a tag: no button, and no 44pt box pretending there is one.
        XCTAssertNil(Chip.minimumHeight(isTappable: false))
    }

    func testOnlyATappableChipCanShowTheChevron() {
        XCTAssertTrue(Chip.showsDisclosure(opensPicker: true, isTappable: true))
        // A tag that draws a disclosure chevron is advertising a tap it does not have.
        XCTAssertFalse(Chip.showsDisclosure(opensPicker: true, isTappable: false))
        XCTAssertFalse(Chip.showsDisclosure(opensPicker: false, isTappable: true))
    }

    // MARK: Notice — the same rule, resolved against its own fill (W6-P4)

    func testANoticeIsMutedOnEitherGround() {
        for surface in Palette.Surface.allCases {
            XCTAssertEqual(Notice.foreground(tone: .muted, on: surface), Palette.muted)
            XCTAssertNil(Notice.border(tone: .muted))
        }
    }

    func testANoticeResolvesItsColourAgainstItsFillNotItsGround() {
        // The inversion that is easy to get backwards: a notice ON paper is filled card, so
        // persimmon is legal; a notice inside a card is filled paper, so it is refused.
        XCTAssertEqual(Notice.foreground(tone: .attention, on: .paper), Palette.persimmon)
        XCTAssertEqual(Notice.foreground(tone: .attention, on: .card), Palette.ink)
        for surface in Palette.Surface.allCases {
            XCTAssertEqual(Notice.foreground(tone: .attention, on: surface),
                           SectionLabel.foreground(tone: .attention, surface: surface.inset))
        }
    }

    func testAnAttentionNoticeKeepsABorderPreciselyBecauseTheColourCanBeRefused() {
        XCTAssertEqual(Notice.border(tone: .attention), Palette.persimmon)
    }

    // MARK: Field — input, never a price renderer (W6-P4)

    func testAFieldSpeaksItsVisibleLabelAndItsUnitAsOnePhrase() {
        XCTAssertEqual(FieldSemantics.spokenLabel(label: "Price", affix: nil), "Price")
        XCTAssertEqual(FieldSemantics.spokenLabel(label: "Quantity", affix: "lb"), "Quantity, lb")
    }

    func testABlankAffixIsNoAffix() {
        XCTAssertNil(FieldSemantics.visibleAffix(nil))
        XCTAssertNil(FieldSemantics.visibleAffix(""))
        XCTAssertNil(FieldSemantics.visibleAffix("   "))
        XCTAssertEqual(FieldSemantics.visibleAffix("  lb "), "lb")
        XCTAssertEqual(FieldSemantics.spokenLabel(label: "Quantity", affix: "  "), "Quantity")
    }

    func testAmountEntryUsesTheTabularDigitsPricesAreAlwaysSetIn() {
        // The typeface for numerals — not a money format. A Field formats nothing.
        XCTAssertTrue(Field.usesTabularDigits(.decimal))
        XCTAssertFalse(Field.usesTabularDigits(.text))
    }
}
