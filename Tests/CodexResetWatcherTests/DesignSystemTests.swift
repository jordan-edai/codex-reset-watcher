import SwiftUI
import XCTest
@testable import CodexResetWatcher

final class DesignSystemTests: XCTestCase {
    func testAppearanceModeMapsToExpectedColorScheme() {
        XCTAssertNil(CodexAppearanceMode.auto.colorScheme)
        XCTAssertEqual(CodexAppearanceMode.light.colorScheme, .light)
        XCTAssertEqual(CodexAppearanceMode.dark.colorScheme, .dark)
    }

    func testAppearanceModeOrderingKeepsAutoFirst() {
        XCTAssertEqual(CodexAppearanceMode.allCases.map(\.rawValue), ["auto", "light", "dark"])
    }

    func testUsageToneMatchesCapacityThresholds() {
        XCTAssertEqual(CodexTone.usage(remainingPercent: nil), .muted)
        XCTAssertEqual(CodexTone.usage(remainingPercent: 100), .success)
        XCTAssertEqual(CodexTone.usage(remainingPercent: 60), .success)
        XCTAssertEqual(CodexTone.usage(remainingPercent: 59), .warning)
        XCTAssertEqual(CodexTone.usage(remainingPercent: 25), .warning)
        XCTAssertEqual(CodexTone.usage(remainingPercent: 24), .danger)
        XCTAssertEqual(CodexTone.usage(remainingPercent: 0), .danger)
    }
}
