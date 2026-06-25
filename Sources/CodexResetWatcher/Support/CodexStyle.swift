import SwiftUI

enum CodexStyle {
    enum Radius {
        static let panel: CGFloat = 8
        static let row: CGFloat = 7
        static let pill: CGFloat = 6
        static let artwork: CGFloat = 8
    }

    enum Spacing {
        static let page: CGFloat = 16
        static let section: CGFloat = 14
        static let stack: CGFloat = 10
        static let panel: CGFloat = 12
        static let menuPadding: CGFloat = 16
        static let rowHorizontal: CGFloat = 12
        static let rowVertical: CGFloat = 9
        static let rowGap: CGFloat = 10
    }

    enum Size {
        static let menuWidth: CGFloat = 410
        static let menuIconColumn: CGFloat = 22
        static let menuMetricColumn: CGFloat = 112
        static let menuDateColumn: CGFloat = 132
        static let menuControlWidth: CGFloat = 132
        static let menuRowMinHeight: CGFloat = 48
        static let artworkWidth: CGFloat = 104
        static let artworkHeight: CGFloat = 58
    }

    enum Typography {
        static let appTitle = Font.system(size: 23, weight: .bold, design: .rounded)
        static let sectionTitle = Font.system(size: 19, weight: .bold, design: .rounded)
        static let cardTitle = Font.system(size: 17, weight: .bold, design: .rounded)
        static let cardMetric = Font.system(size: 23, weight: .bold, design: .rounded)
        static let largeMetric = Font.system(size: 38, weight: .bold, design: .rounded)
        static let menuTitle = Font.system(size: 21, weight: .bold, design: .rounded)
        static let menuRowTitle = Font.system(size: 15, weight: .semibold)
        static let menuRowMeta = Font.system(size: 13, weight: .medium)
        static let menuMetric = Font.system(size: 16, weight: .bold)
        static let menuDate = Font.system(size: 15, weight: .bold, design: .rounded)
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
            .shadow(color: .black.opacity(shadow ? 0.04 : 0), radius: shadow ? 8 : 0, y: shadow ? 1 : 0)
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
        background ?? (isSelected ? CodexPalette.selectedRowBackground : CodexPalette.rowBackground)
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
