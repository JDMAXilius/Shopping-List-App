import XCTest
@testable import DesignKit   // reaches InputBar.micFill; the colour math stays in one file

// The gate's "verified, not assumed" (PRODUCT.md §2): pure WCAG 2.x relative-luminance
// math over Palette's raw components. Deliberately no SwiftUI import.
final class ContrastTests: XCTestCase {

    private func luminance(_ c: Palette.RGB) -> Double {
        func lin(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    private func ratio(_ a: Palette.RGB, _ b: Palette.RGB) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    // muted is #716A5F, corrected from Figma's #8C857A precisely to pass these two.
    func testMutedOnPaperMeetsBodyText() {
        XCTAssertGreaterThanOrEqual(ratio(Palette.muted, Palette.paper), 4.5)  // measures 4.87
    }

    func testMutedOnCardMeetsBodyText() {
        XCTAssertGreaterThanOrEqual(ratio(Palette.muted, Palette.card), 4.5)   // measures 5.34
    }

    func testInkOnPaper() {
        XCTAssertGreaterThanOrEqual(ratio(Palette.ink, Palette.paper), 4.5)    // measures 16.30
    }

    func testConfirmedOnCard() {
        XCTAssertGreaterThanOrEqual(ratio(Palette.confirmed, Palette.card), 4.5)  // measures 5.32
    }

    // W4-C1 ruling: persimmon darkened #C9502C → #C64E2B; STRICT ≥4.5, no 2dp
    // rounding. Contrast is symmetric, so this covers white-on-it and it-on-white.
    func testWhiteOnPersimmon() {
        XCTAssertGreaterThanOrEqual(ratio(Palette.card, Palette.persimmon), 4.5)  // measures 4.64
    }

    // The persimmon usage rule encoded (Palette.swift comment): body text allowed on
    // card, NOT on paper — there it must be ≥18pt, bold, or a fill behind white text.
    func testPersimmonBodyTextAllowedOnCardOnly() {
        XCTAssertGreaterThanOrEqual(ratio(Palette.persimmon, Palette.card), 4.5)  // 4.64 — passes strictly
        let onPaper = ratio(Palette.persimmon, Palette.paper)
        XCTAssertLessThan(onPaper, 4.5)                                        // 4.23 — why the rule exists
        XCTAssertGreaterThanOrEqual(onPaper, 3.0)                              // still passes large-text AA
    }

    // Checked-row prices dropped their 0.75 opacity (W4-C1 fix 6) — the remaining
    // treatment is `.saturation(0)`, modelled here with the SVG/CoreImage saturate
    // matrix on gamma-encoded sRGB (weights 0.213/0.715/0.072). Both checked price
    // colours must still clear 4.5 on card.
    func testCheckedDesaturatedPricesOnCard() {
        func desaturated(_ c: Palette.RGB) -> Palette.RGB {
            let gray = 0.213 * c.r + 0.715 * c.g + 0.072 * c.b
            let v = Int((gray * 255).rounded())
            return Palette.RGB(v, v, v)
        }
        XCTAssertGreaterThanOrEqual(ratio(desaturated(Palette.ink), Palette.card), 4.5)    // 17.90
        XCTAssertGreaterThanOrEqual(ratio(desaturated(Palette.muted), Palette.card), 4.5)  // 5.35
    }

    // W5-P4 fix 2: the disabled mic drops the action colour for muted. Muted keeps the
    // white glyph legible (5.35) — a disabled control must read as unavailable, never as
    // broken — and the disc itself clears the 3:1 non-text floor against the bar's card.
    func testDisabledMicRemainsLegibleOnceItIsNoLongerPersimmon() {
        let disabled = InputBar.micFill(isEnabled: false)
        XCTAssertNotEqual(disabled, Palette.persimmon)
        XCTAssertGreaterThanOrEqual(ratio(Palette.card, disabled), 4.5)   // measures 5.35
        XCTAssertGreaterThanOrEqual(ratio(disabled, Palette.card), 3.0)   // the disc's own edge
    }

    // Ink must survive on every aisle tint — glyph strokes and text sit on the tiles.
    func testInkOnEveryAisleTint() {
        for tint in Palette.aisleTints {
            XCTAssertGreaterThanOrEqual(ratio(Palette.ink, tint), 4.5)         // all measure >10
        }
    }
}
