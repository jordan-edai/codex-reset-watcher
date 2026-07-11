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

    func testMainWindowDefaultSizeStaysRoomyEnoughForPrimaryContent() {
        XCTAssertGreaterThanOrEqual(CodexStyle.Size.mainWindowMinWidth, 880)
        XCTAssertGreaterThanOrEqual(CodexStyle.Size.mainWindowMinHeight, 680)
        XCTAssertGreaterThanOrEqual(CodexStyle.Size.mainWindowDefaultWidth, 946)
        XCTAssertGreaterThanOrEqual(CodexStyle.Size.mainWindowDefaultHeight, 682)
    }

    func testSmallTextRolesMeetContrastTargetOnCardSurfaces() {
        let lightSurface = CodexPalette.Reference.lightCardBackground
        let darkSurface = CodexPalette.Reference.darkCardBackground
        let lightText = [
            CodexPalette.Reference.lightSecondaryText,
            CodexPalette.Reference.lightMutedText,
            CodexPalette.Reference.lightNeutralText,
            CodexPalette.Reference.lightAvailableText,
            CodexPalette.Reference.lightWarningText,
            CodexPalette.Reference.lightUrgentText,
        ]
        let darkText = [
            CodexPalette.Reference.darkSecondaryText,
            CodexPalette.Reference.darkMutedText,
            CodexPalette.Reference.darkNeutralText,
            CodexPalette.Reference.darkAvailableText,
            CodexPalette.Reference.darkWarningText,
            CodexPalette.Reference.darkUrgentText,
        ]

        for color in lightText {
            XCTAssertGreaterThanOrEqual(contrastRatio(color, lightSurface), 4.5)
        }
        for color in darkText {
            XCTAssertGreaterThanOrEqual(contrastRatio(color, darkSurface), 4.5)
        }
    }

    func testStatusTextAndMeterColorsStaySeparate() {
        XCTAssertNotEqual(CodexPalette.Reference.lightAvailableText, CodexPalette.Reference.lightAvailableMeter)
        XCTAssertNotEqual(CodexPalette.Reference.lightWarningText, CodexPalette.Reference.lightWarningMeter)
        XCTAssertNotEqual(CodexPalette.Reference.lightUrgentText, CodexPalette.Reference.lightUrgentMeter)
    }

    func testSidebarAndMenuSizingKeepsCoreContentReadable() {
        XCTAssertGreaterThanOrEqual(CodexStyle.Typography.sidebarTitleSize, 12)
        XCTAssertGreaterThanOrEqual(CodexStyle.Typography.sidebarDetailSize, 11)
    }

    func testMenuPopoverUsesAvailableScreenHeightInsteadOfAStaticCap() {
        let tallScreenHeight: CGFloat = 1_127
        let maximumHeight = MenuPopoverSizing.maximumDynamicContentHeight(
            for: tallScreenHeight
        )

        XCTAssertGreaterThan(maximumHeight, 620)
        XCTAssertEqual(
            maximumHeight,
            tallScreenHeight
                - CodexStyle.Size.menuFixedChromeHeight
                - CodexStyle.Size.menuScreenEdgeInset
        )
    }

    func testMenuPopoverKeepsAUsableFallbackOnShortScreens() {
        XCTAssertEqual(
            MenuPopoverSizing.maximumDynamicContentHeight(for: 400),
            CodexStyle.Size.menuMinimumDynamicContentHeight
        )
    }

    private func contrastRatio(_ first: UInt, _ second: UInt) -> Double {
        let firstLuminance = relativeLuminance(first)
        let secondLuminance = relativeLuminance(second)
        return (max(firstLuminance, secondLuminance) + 0.05)
            / (min(firstLuminance, secondLuminance) + 0.05)
    }

    private func relativeLuminance(_ hex: UInt) -> Double {
        let components = [
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255,
        ]

        let linear = components.map { component in
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return (0.2126 * linear[0]) + (0.7152 * linear[1]) + (0.0722 * linear[2])
    }
}
