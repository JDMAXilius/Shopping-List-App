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
}
