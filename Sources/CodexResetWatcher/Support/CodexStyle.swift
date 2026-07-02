import SwiftUI

enum CodexStyle {
    enum Radius {
        static let panel: CGFloat = 8
        static let row: CGFloat = 6
        static let pill: CGFloat = 20
        static let artwork: CGFloat = 7
    }

    enum Spacing {
        static let page: CGFloat = 20
        static let desktopPage: CGFloat = 16
        static let section: CGFloat = 16
        static let desktopSection: CGFloat = 10
        static let stack: CGFloat = 12
        static let desktopStack: CGFloat = 8
        static let panel: CGFloat = 16
        static let compactPanel: CGFloat = 12
        static let densePanel: CGFloat = 10
        static let menuPadding: CGFloat = 14
        static let rowHorizontal: CGFloat = 13
        static let rowVertical: CGFloat = 9
        static let rowGap: CGFloat = 10
        static let tight: CGFloat = 6
    }

    enum Size {
        static let sidebarWidth: CGFloat = 230
        static let menuWidth: CGFloat = 470
        static let menuIconColumn: CGFloat = 32
        static let menuMetricColumn: CGFloat = 104
        static let menuDateColumn: CGFloat = 142
        static let menuControlWidth: CGFloat = 150
        static let menuRowMinHeight: CGFloat = 50
        static let artworkWidth: CGFloat = 88
        static let artworkHeight: CGFloat = 52
        static let compactArtworkWidth: CGFloat = 66
        static let compactArtworkHeight: CGFloat = 38
        static let menuArtworkWidth: CGFloat = 58
        static let menuArtworkHeight: CGFloat = 34
        static let iconBadge: CGFloat = 30
        static let smallIconBadge: CGFloat = 24
    }

    enum Icon {
        static let menu: CGFloat = 14
        static let content: CGFloat = 17
        static let badge: CGFloat = 15
        static let sidebar: CGFloat = 14
    }

    enum Row {
        static let compact: CGFloat = 40
        static let standard: CGFloat = 44
        static let comfortable: CGFloat = 50
        static let tall: CGFloat = 56
    }

    enum Meter {
        static let height: CGFloat = 5
        static let menuHeight: CGFloat = 4
    }

    enum Badge {
        static let horizontalPadding: CGFloat = 9
        static let verticalPadding: CGFloat = 4
    }

    enum Opacity {
        static let tintBackground: Double = 0.08
        static let tintBorder: Double = 0.26
        static let strongTintBorder: Double = 0.42
    }

    enum Typography {
        static let appTitle = Font.system(size: 23, weight: .bold)
        static let sectionTitle = Font.system(size: 18, weight: .semibold)
        static let cardTitle = Font.system(size: 16, weight: .semibold)
        static let cardMetric = Font.system(size: 25, weight: .bold)
        static let summaryMetric = Font.system(size: 24, weight: .semibold)
        static let largeMetric = Font.system(size: 40, weight: .semibold)
        static let body = Font.system(size: 14, weight: .regular)
        static let bodyStrong = Font.system(size: 14, weight: .semibold)
        static let caption = Font.system(size: 12, weight: .medium)
        static let eyebrow = Font.system(size: 11, weight: .semibold)
        static let menuTitle = Font.system(size: 18, weight: .semibold)
        static let menuRowTitle = Font.system(size: 14, weight: .semibold)
        static let menuRowMeta = Font.system(size: 12, weight: .medium)
        static let menuMetric = Font.system(size: 15, weight: .semibold)
        static let menuDate = Font.system(size: 14, weight: .semibold)
    }
}

private struct CodexPanelModifier: ViewModifier {
    let background: Color
    let border: Color
    let shadow: Bool

    func body(content: Content) -> some View {
        content
            .background(background, in: shape)
            .overlay {
                shape.stroke(border)
            }
            .shadow(color: .black.opacity(shadow ? 0.06 : 0), radius: shadow ? 8 : 0, y: shadow ? 1 : 0)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CodexStyle.Radius.panel, style: .continuous)
    }
}

private struct CodexRowModifier: ViewModifier {
    let isSelected: Bool
    let background: Color?
    let border: Color?
    let minHeight: CGFloat

    private var resolvedBackground: Color {
        background ?? (isSelected ? CodexPalette.selectedRowBackground : CodexPalette.elevatedBackground)
    }

    private var resolvedBorder: Color {
        border ?? (isSelected ? CodexPalette.selectedBorder : CodexPalette.softBorder)
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, CodexStyle.Spacing.rowHorizontal)
            .padding(.vertical, CodexStyle.Spacing.rowVertical)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(resolvedBackground, in: shape)
            .overlay {
                shape.stroke(resolvedBorder)
            }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CodexStyle.Radius.row, style: .continuous)
    }
}

extension View {
    func codexPanel(
        background: Color = CodexPalette.panelBackground,
        border: Color = CodexPalette.border,
        shadow: Bool = true
    ) -> some View {
        modifier(CodexPanelModifier(background: background, border: border, shadow: shadow))
    }

    func codexRow(
        isSelected: Bool = false,
        background: Color? = nil,
        border: Color? = nil,
        minHeight: CGFloat = CodexStyle.Size.menuRowMinHeight
    ) -> some View {
        modifier(CodexRowModifier(isSelected: isSelected, background: background, border: border, minHeight: minHeight))
    }
}
