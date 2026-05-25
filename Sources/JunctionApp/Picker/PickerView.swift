import SwiftUI
import AppKit

extension Color {
    init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

struct PickerView: View {
    @ObservedObject var model: PickerViewModel
    @ObservedObject private var appSettings = SettingsStore.shared
    let width: CGFloat
    let height: CGFloat
    @State private var appeared: Bool = false

    init(model: PickerViewModel, width: CGFloat, height: CGFloat = PickerView.pickerHeight) {
        self.model = model
        self.width = width
        self.height = height
    }

    static let tileWidth: CGFloat = 144
    static let tileSpacing: CGFloat = 13
    static let listHorizontalPadding: CGFloat = 20
    static let minWidth: CGFloat = 600
    static let pickerHeight: CGFloat = 332
    static let previewWidth: CGFloat = 1280
    static let previewHeight: CGFloat = 880

    static let listRowHeight: CGFloat = 52
    static let listRowSpacing: CGFloat = 4
    static let listVerticalPadding: CGFloat = 8
    static let listRowsBeforeScroll: Int = 9
    static let listStyleWidth: CGFloat = 680
    static let listStyleMinHeight: CGFloat = 240
    static let listStyleMaxHeight: CGFloat = 630
    static let listDockHeight: CGFloat = 44
    static let listDockGap: CGFloat = 10
    static let listDockBottomInset: CGFloat = 16

    static let dialStyleWidth: CGFloat = 540
    static let dialDiameter: CGFloat = 440
    static let dialHeaderHeight: CGFloat = 48
    static let dialHeaderGap: CGFloat = 16
    static let dialPanelHorizontalPadding: CGFloat = 20
    static let dialPanelTopPadding: CGFloat = 14

    static var dialStyleHeight: CGFloat {
        dialPanelTopPadding
            + dialHeaderHeight
            + dialHeaderGap
            + dialDiameter
            + listDockGap
            + listDockHeight
            + listDockBottomInset
    }

    static func desiredWidth(forOptionCount count: Int) -> CGFloat {
        let content = CGFloat(count) * tileWidth
            + CGFloat(max(count - 1, 0)) * tileSpacing
            + listHorizontalPadding * 2
        let screenMax: CGFloat = {
            if let screen = NSScreen.main {
                return max(minWidth, screen.visibleFrame.width - 80)
            }
            return 1200
        }()
        return max(minWidth, min(content, screenMax))
    }

    static func desiredSize(forOptionCount count: Int, style: PickerStyle) -> CGSize {
        switch style {
        case .tiles:
            return CGSize(width: desiredWidth(forOptionCount: count), height: pickerHeight)
        case .list:
            let panel = listStyleHeight(forOptionCount: count)
            return CGSize(width: listStyleWidth, height: panel + listDockGap + listDockHeight + listDockBottomInset)
        case .dial:
            return CGSize(width: dialStyleWidth, height: dialStyleHeight)
        }
    }

    static func listStyleHeight(forOptionCount count: Int) -> CGFloat {
        let header: CGFloat = 62
        let footer: CGFloat = 52
        let rows = CGFloat(min(max(count, 1), listRowsBeforeScroll))
        let rowsHeight = rows * listRowHeight + max(rows - 1, 0) * listRowSpacing
        let content = rowsHeight + listVerticalPadding * 2
        let total = header + footer + content
        return min(max(total, listStyleMinHeight), listStyleMaxHeight)
    }

    static func previewSize() -> CGSize {
        if let screen = NSScreen.main {
            let w = min(previewWidth, screen.visibleFrame.width - 80)
            let h = min(previewHeight, screen.visibleFrame.height - 120)
            return CGSize(width: max(minWidth, w), height: max(360, h))
        }
        return CGSize(width: previewWidth, height: previewHeight)
    }

    var body: some View {
        ZStack {
            if model.previewMode {
                PreviewView(model: model)
                    .frame(width: Self.previewSize().width, height: Self.previewSize().height)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if appSettings.settings.pickerStyle == .list {
                listLayout
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if appSettings.settings.pickerStyle == .dial {
                dialLayout
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                pickerBody()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            if model.cheatSheetVisible {
                CheatSheetOverlay(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: model.previewMode)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: model.cheatSheetVisible)
        .background(KeyEventCatcher(model: model))
        .tint(appSettings.settings.accentPreset.swiftUIColor)
        .scaleEffect(appeared ? 1.0 : 0.96)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }

    private var listLayout: some View {
        let panelHeight = max(0, height - Self.listDockHeight - Self.listDockGap - Self.listDockBottomInset)
        return VStack(spacing: Self.listDockGap) {
            pickerBody(height: panelHeight)
                .frame(width: width, height: panelHeight)
            shortcutDock
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: Self.listDockHeight)
        }
        .padding(.bottom, Self.listDockBottomInset)
        .frame(width: width, height: height, alignment: .top)
    }

    private var shortcutDock: some View {
        HStack(spacing: 12) {
            ForEach(PickerShortcutHelp.pickerFooterHints) { hint in
                HintPill(key: hint.key, label: hint.label)
            }
            Button {
                model.cheatSheetVisible.toggle()
            } label: {
                HintPill(key: "?", label: "More", emphasized: model.cheatSheetVisible)
            }
            .buttonStyle(.plain)
            .help(PickerShortcutHelp.picker)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(
            JunctionChromeBackground(
                theme: appSettings.settings.chromeTheme,
                accent: appSettings.settings.accentPreset.swiftUIColor
            )
        )
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .compositingGroup()
    }

    private func pickerBody(height bodyHeight: CGFloat? = nil) -> some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                optionList
                footer
            }

            if model.showQRSheet {
                QRSheetOverlay(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .background(
            JunctionChromeBackground(
                theme: appSettings.settings.chromeTheme,
                accent: appSettings.settings.accentPreset.swiftUIColor
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .frame(width: width, height: bodyHeight ?? height)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: model.showQRSheet)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                if let source = model.sourceApp {
                    sourcePill(source)
                }
                if let focus = model.focusName {
                    focusBadge(focus)
                }
                if model.incognitoMode {
                    incognitoBadge
                }
                if !idnRiskFlags.isEmpty {
                    RiskChip(flags: idnRiskFlags)
                }
                if !otherRiskFlags.isEmpty {
                    riskChip(otherRiskFlags)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            GeometryReader { geo in
                let faviconSlot: CGFloat = 18 + 8
                let textCap = max(60, geo.size.width - faviconSlot)
                HStack {
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        FaviconView(data: model.displayFaviconData, fallbackSize: 11)
                            .frame(width: 18, height: 18)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                        Text(displayURL)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)

                        if model.willOpenCleaned {
                            cleanedChip
                        }
                    }
                    .frame(maxWidth: textCap)
                    .help(model.cleaningSummary ?? displayURL)
                    Spacer(minLength: 0)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 34)

            HStack(spacing: 8) {
                Button {
                    model.openPreferences()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Open Preferences")
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var incognitoBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 11, weight: .semibold))
            Text("Private")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.indigo)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(Color.indigo.opacity(0.18)))
        .help("Open in private/incognito mode (⌥ to toggle, ⌥⏎ to confirm)")
    }

    private var displayURL: String {
        model.displayURLString
    }

    private func sourcePill(_ source: URLSource) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 22, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                if let icon = source.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 15, height: 15)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.45))
                }
            }
            (Text("from ")
                .foregroundColor(.secondary)
                + Text(source.name)
                .foregroundColor(.primary)
                .fontWeight(.semibold))
                .font(.system(size: 13))
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    private func focusBadge(_ name: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "moon.fill")
                .font(.system(size: 11))
            Text(name)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .foregroundColor(.purple)
        .background(Capsule().fill(Color.purple.opacity(0.18)))
    }

    private var idnRiskFlags: [RiskFlag] { model.riskFlags.filter { $0.isIDNRelated } }
    private var otherRiskFlags: [RiskFlag] { model.riskFlags.filter { !$0.isIDNRelated } }

    private func riskChip(_ flags: [RiskFlag]) -> some View {
        RiskChip(flags: flags)
    }

    /// Inline "cleaned" pill next to the URL row that hosts the cleaning trace
    /// in its tooltip; gives users a visible nudge that the URL was modified.
    private var cleanedChip: some View {
        let count = model.cleaningTrace.steps.count
        return HStack(spacing: 4) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 9, weight: .semibold))
            Text("cleaned")
                .font(.system(size: 10, weight: .semibold))
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 4).padding(.vertical, 0)
                    .background(Capsule().fill(Color.accentColor.opacity(0.28)))
            }
        }
        .foregroundColor(.accentColor)
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 0.5))
        .help(model.cleaningSummary ?? "URL was cleaned before opening.")
    }

    private func riskTint(_ level: RiskLevel) -> Color {
        switch level {
        case .info: return .blue
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }

    private func riskIcon(_ level: RiskLevel) -> String {
        switch level {
        case .info: return "info.circle.fill"
        case .low: return "exclamationmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "shield.lefthalf.filled"
        }
    }

    private var optionList: some View {
        let list = model.filteredOptions
        let grouped = model.groupedFilteredOptions
        let tiles = groupedTiles(grouped)
        return Group {
            if list.isEmpty {
                Text("No browsers enabled — open Preferences to show some.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appSettings.settings.pickerStyle == .list {
                listStyleBody(tiles: tiles)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Self.tileSpacing) {
                            ForEach(Array(tiles.enumerated()), id: \.element.tileID) { idx, entry in
                                tileForEntry(entry, visibleIndex: idx)
                                    .id(entry.tileID)
                            }
                        }
                        .padding(.horizontal, Self.listHorizontalPadding)
                        .padding(.vertical, 10)
                        .frame(minWidth: width, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: model.selectedIndex) { newIndex in
                        guard tiles.indices.contains(newIndex) else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(tiles[newIndex].tileID, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func brandColor(for bundleID: String) -> Color {
        let id = bundleID.lowercased()
        if id.contains("chrome") { return .blue }
        if id.contains("safari") { return Color(red: 0.0, green: 0.6, blue: 0.9) }
        if id.contains("firefox") { return .orange }
        if id.contains("brave") { return Color(red: 0.9, green: 0.3, blue: 0.1) }
        if id.contains("edge") { return .teal }
        if id.contains("arc") { return .purple }
        if id.contains("opera") { return .red }
        if id.contains("vivaldi") { return .red }
        return appSettings.settings.accentPreset.swiftUIColor
    }

    private var dialLayout: some View {
        let tiles = groupedTiles(model.groupedFilteredOptions)
        return VStack(spacing: Self.dialHeaderGap) {
            dialHeader
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(height: Self.dialHeaderHeight)
                .frame(maxWidth: .infinity)
                .background(
                    JunctionChromeBackground(
                        theme: appSettings.settings.chromeTheme,
                        accent: appSettings.settings.accentPreset.swiftUIColor
                    )
                )
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, Self.dialPanelHorizontalPadding)

            dialBoard(tiles: tiles)
                .frame(width: Self.dialDiameter, height: Self.dialDiameter)

            shortcutDock
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: Self.listDockHeight)
                .padding(.top, Self.listDockGap - Self.dialHeaderGap)
        }
        .padding(.top, Self.dialPanelTopPadding)
        .padding(.bottom, Self.listDockBottomInset)
        .frame(width: width, height: height, alignment: .top)
        .overlay(alignment: .center) {
            if model.showQRSheet {
                QRSheetOverlay(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
    }

    private var dialHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            if let source = model.sourceApp {
                sourcePill(source)
            }
            if model.incognitoMode {
                incognitoBadge
            }
            if !idnRiskFlags.isEmpty {
                RiskChip(flags: idnRiskFlags)
            }
            if !otherRiskFlags.isEmpty {
                riskChip(otherRiskFlags)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                FaviconView(data: model.displayFaviconData, fallbackSize: 11)
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text(displayURL)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if model.willOpenCleaned {
                    cleanedChip
                }
            }
            .help(model.cleaningSummary ?? displayURL)
            .layoutPriority(1)

            Spacer(minLength: 8)

            Button {
                model.openQRSheet()
            } label: {
                Image(systemName: "qrcode")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Show QR code for this URL")

            Button {
                model.openPreferences()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Open Preferences")
        }
    }

    private func dialBoard(tiles: [TileEntry]) -> some View {
        let outerRad: CGFloat = Self.dialDiameter / 2.0
        let innerRad: CGFloat = outerRad * 0.42
        let iconRad: CGFloat = outerRad * 0.66

        let count = tiles.count
        let angleStep: Double = 360.0 / Double(max(count, 1))
        let selectedIdx = model.selectedIndex
        let selectedOption: LaunchOption? = {
            guard tiles.indices.contains(selectedIdx) else { return nil }
            switch tiles[selectedIdx].kind {
            case .single(let opt), .groupChild(let opt): return opt
            }
        }()
        let selectedBrand: Color = selectedOption.map { brandColor(for: $0.browser.bundleID) }
            ?? appSettings.settings.accentPreset.swiftUIColor

        return ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    selectedBrand.opacity(0.18),
                                    Color.black.opacity(0.05),
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: outerRad
                            )
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 22, x: 0, y: 10)

            if tiles.indices.contains(selectedIdx) {
                let startAngle = Double(selectedIdx) * angleStep - 90.0 - (angleStep / 2.0)
                let endAngle = startAngle + angleStep

                CircularWedge(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    innerRadius: innerRad,
                    outerRadius: outerRad
                )
                .fill(
                    RadialGradient(
                        colors: [selectedBrand.opacity(0.32), selectedBrand.opacity(0.06)],
                        center: .center,
                        startRadius: innerRad,
                        endRadius: outerRad
                    )
                )

                CircularWedge(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    innerRadius: innerRad,
                    outerRadius: outerRad
                )
                .stroke(selectedBrand.opacity(0.7), lineWidth: 1.5)
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selectedIdx)
            }

            DialDividers(count: count, innerRadius: innerRad, outerRadius: outerRad)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

            ForEach(Array(tiles.enumerated()), id: \.element.tileID) { idx, entry in
                let option: LaunchOption = {
                    switch entry.kind {
                    case .single(let opt), .groupChild(let opt): return opt
                    }
                }()
                let isSelected = idx == selectedIdx
                let isMultiSelected = model.multiSelection.contains(option.id)
                let startAngle = Double(idx) * angleStep - 90.0 - (angleStep / 2.0)
                let endAngle = startAngle + angleStep
                let centerAngle = Double(idx) * angleStep - 90.0
                let centerRad = centerAngle * .pi / 180.0
                let supportsIncognito = URLOpener.supportsIncognito(bundleID: option.browser.bundleID)
                let privateActive = model.incognitoMode || model.optionKeyHeld

                DialSegmentView(
                    option: option,
                    idx: idx,
                    number: idx + 1,
                    isSelected: isSelected,
                    isMultiSelected: isMultiSelected,
                    showIncognito: privateActive && supportsIncognito,
                    dimmed: privateActive && !supportsIncognito,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    innerRadius: innerRad,
                    outerRadius: outerRad,
                    iconOffsetX: iconRad * cos(centerRad),
                    iconOffsetY: iconRad * sin(centerRad),
                    labelMaxWidth: max(60, 2 * outerRad * sin((angleStep * .pi / 180.0) / 2.0) - 18),
                    brandCol: brandColor(for: option.browser.bundleID),
                    model: model
                )
            }

            DialCenterHub(
                radius: innerRad,
                selectedOption: selectedOption,
                multiCount: model.multiSelection.count,
                privateActive: model.incognitoMode || model.optionKeyHeld,
                accent: selectedBrand
            )
        }
        .compositingGroup()
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selectedIdx)
    }

private struct DialSegmentView: View {
    let option: LaunchOption
    let idx: Int
    let number: Int
    let isSelected: Bool
    let isMultiSelected: Bool
    let showIncognito: Bool
    let dimmed: Bool
    let startAngle: Double
    let endAngle: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let iconOffsetX: CGFloat
    let iconOffsetY: CGFloat
    let labelMaxWidth: CGFloat
    let brandCol: Color
    @ObservedObject var model: PickerViewModel
    @State private var isHovered = false

    private var iconSize: CGFloat { isSelected ? 50 : 42 }

    private var labelText: String {
        option.profile?.displayName ?? option.browser.name
    }

    var body: some View {
        ZStack {
            if !isSelected && isHovered {
                CircularWedge(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    innerRadius: innerRadius,
                    outerRadius: outerRadius
                )
                .fill(Color.white.opacity(0.06))
            }

            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(brandCol.opacity(0.16))
                            .frame(width: iconSize + 18, height: iconSize + 18)
                            .blur(radius: 6)
                    }

                    Image(nsImage: option.icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: iconSize, height: iconSize)
                        .shadow(
                            color: isSelected ? brandCol.opacity(0.45) : Color.black.opacity(0.18),
                            radius: isSelected ? 10 : 4,
                            x: 0,
                            y: 2
                        )
                        .overlay(alignment: .bottomTrailing) {
                            if showIncognito {
                                IncognitoBadge(size: 18)
                                    .offset(x: 4, y: 4)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }

                    if number <= 9 {
                        Text("\(number)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.primary.opacity(0.85))
                            .frame(width: 18, height: 18)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.55))
                                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                            )
                            .offset(x: iconSize / 2 - 4, y: -iconSize / 2 + 4)
                    }

                    if isMultiSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                            .background(Circle().fill(Color.black.opacity(0.6)))
                            .offset(x: iconSize / 2 - 4, y: iconSize / 2 - 4)
                    }
                }

                HStack(spacing: 4) {
                    if let hex = option.colorHex, let color = Color(hexString: hex) {
                        Capsule()
                            .fill(color)
                            .frame(width: 8, height: 3)
                    }
                    Text(labelText)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: labelMaxWidth)
                .shadow(color: Color.black.opacity(0.5), radius: 1.5, x: 0, y: 1)
            }
            .opacity(dimmed ? 0.45 : 1.0)
            .scaleEffect(isHovered && !isSelected ? 1.04 : 1.0)
            .offset(x: iconOffsetX, y: iconOffsetY)
        }
        .contentShape(
            CircularWedge(
                startAngle: startAngle,
                endAngle: endAngle,
                innerRadius: innerRadius,
                outerRadius: outerRadius
            )
        )
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
                if model.selectedIndex != idx {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        model.selectedIndex = idx
                    }
                }
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            let flags = NSEvent.modifierFlags
            if flags.contains(.shift) {
                model.toggleMulti(option)
            } else {
                let incognito = flags.contains(.option) || model.incognitoMode
                model.pick(option, incognito: incognito)
            }
        }
        .help(dimmed
              ? "\(option.browser.name) doesn't support private windows — it will open normally."
              : "Open in \(option.displayName)")
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isSelected)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: showIncognito)
    }
}

private struct DialDividers: Shape {
    let count: Int
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard count > 1 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let step = 360.0 / Double(count)
        for i in 0..<count {
            let angle = Double(i) * step - 90.0 - (step / 2.0)
            let rad = angle * .pi / 180.0
            let s = CGPoint(x: center.x + innerRadius * cos(rad), y: center.y + innerRadius * sin(rad))
            let e = CGPoint(x: center.x + outerRadius * cos(rad), y: center.y + outerRadius * sin(rad))
            path.move(to: s)
            path.addLine(to: e)
        }
        return path
    }
}

private struct DialCenterHub: View {
    let radius: CGFloat
    let selectedOption: LaunchOption?
    let multiCount: Int
    let privateActive: Bool
    let accent: Color

    var body: some View {
        let diameter = radius * 2
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.25), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )

            VStack(spacing: 6) {
                if privateActive {
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(.indigo)
                    Text("Private")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.indigo)
                } else if let selectedOption {
                    Text(selectedOption.browser.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("Press ↵ to open")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }

                if multiCount > 0 {
                    Text("\(multiCount) selected")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: diameter - 16)
            .multilineTextAlignment(.center)
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeOut(duration: 0.15), value: privateActive)
    }
}

    private func listStyleBody(tiles: [TileEntry]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Self.listRowSpacing) {
                    ForEach(Array(tiles.enumerated()), id: \.element.tileID) { idx, entry in
                        listRowForEntry(entry, visibleIndex: idx)
                            .id(entry.tileID)
                    }
                }
                .padding(.horizontal, Self.listHorizontalPadding)
                .padding(.vertical, Self.listVerticalPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: model.selectedIndex) { newIndex in
                guard tiles.indices.contains(newIndex) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(tiles[newIndex].tileID, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func listRowForEntry(_ entry: TileEntry, visibleIndex: Int) -> some View {
        switch entry.kind {
        case .single(let opt), .groupChild(let opt):
            listRow(idx: visibleIndex, option: opt)
        }
    }

    private func listRow(idx: Int, option: LaunchOption) -> some View {
        let privateActive = model.incognitoMode || model.optionKeyHeld
        let supportsIncognito = URLOpener.supportsIncognito(bundleID: option.browser.bundleID)
        let incognitoUnsupported = privateActive && !supportsIncognito
        return PickerListRow(
            option: option,
            number: idx + 1,
            selected: idx == model.selectedIndex,
            multiSelected: model.multiSelection.contains(option.id),
            dimmed: incognitoUnsupported,
            showIncognito: privateActive && supportsIncognito
        )
        .help(incognitoUnsupported
              ? "\(option.browser.name) doesn't support private windows — it will open normally."
              : "Open in \(option.displayName)")
        .contentShape(Rectangle())
        .contextMenu {
            let key = option.target.storageKey
            let isPinned = appSettings.settings.pinnedTargetKey == key
            if isPinned {
                Button("Unpin") {
                    appSettings.setPinnedTargetKey(nil)
                }
            } else {
                Button("Pin to first slot") {
                    appSettings.setPinnedTargetKey(key)
                }
            }
        }
        .onTapGesture {
            let flags = NSEvent.modifierFlags
            if flags.contains(.shift) {
                model.toggleMulti(option)
            } else {
                let incognito = flags.contains(.option) || model.incognitoMode
                model.pick(option, incognito: incognito)
            }
        }
    }

    private struct TileEntry {
        enum Kind {
            case single(LaunchOption)
            case groupChild(LaunchOption)
        }
        let kind: Kind
        var tileID: String {
            switch kind {
            case .single(let opt): return opt.id
            case .groupChild(let opt): return opt.id
            }
        }
    }

    private func groupedTiles(_ grouped: [GroupedLaunchOption]) -> [TileEntry] {
        var entries: [TileEntry] = []
        for item in grouped {
            switch item {
            case .single(let opt):
                entries.append(TileEntry(kind: .single(opt)))
            case .group(_, let opts):
                for opt in opts {
                    entries.append(TileEntry(kind: .groupChild(opt)))
                }
            }
        }
        return entries
    }

    @ViewBuilder
    private func tileForEntry(_ entry: TileEntry, visibleIndex: Int) -> some View {
        switch entry.kind {
        case .single(let opt), .groupChild(let opt):
            tile(idx: visibleIndex, option: opt)
        }
    }

    private func tile(idx: Int, option: LaunchOption) -> some View {
        let privateActive = model.incognitoMode || model.optionKeyHeld
        let supportsIncognito = URLOpener.supportsIncognito(bundleID: option.browser.bundleID)
        let incognitoUnsupported = privateActive && !supportsIncognito
        return PickerTile(
            option: option,
            number: idx + 1,
            selected: idx == model.selectedIndex,
            multiSelected: model.multiSelection.contains(option.id),
            dimmed: incognitoUnsupported,
            showIncognito: privateActive && supportsIncognito,
            appearDelay: Double(idx) * 0.018
        )
        .help(incognitoUnsupported
              ? "\(option.browser.name) doesn't support private windows — it will open normally."
              : "Open in \(option.displayName)")
        .contentShape(Rectangle())
        .contextMenu {
            let key = option.target.storageKey
            let isPinned = appSettings.settings.pinnedTargetKey == key
            if isPinned {
                Button("Unpin") {
                    appSettings.setPinnedTargetKey(nil)
                }
            } else {
                Button("Pin to first slot") {
                    appSettings.setPinnedTargetKey(key)
                }
            }
        }
        .onTapGesture {
            let flags = NSEvent.modifierFlags
            if flags.contains(.shift) {
                model.toggleMulti(option)
            } else {
                let incognito = flags.contains(.option) || model.incognitoMode
                model.pick(option, incognito: incognito)
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 12) {
            if !model.multiSelection.isEmpty {
                Text("\(model.multiSelection.count) selected")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            }

            if let host = model.rememberHost, !model.incognitoMode {
                RememberHostToggle(host: host, isOn: model.rememberChoice, action: model.toggleRemember)
            }

            Spacer(minLength: 10)

            Button {
                model.openQRSheet()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 12, weight: .medium))
                    Text("QR")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Show QR code for this URL")

            hintSegments
        }
        .frame(height: 34)
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    private var hintSegments: some View {
        Group {
            if appSettings.settings.pickerStyle == .list {
                EmptyView()
            } else {
                PickerShortcutFooter(
                    hints: PickerShortcutHelp.pickerFooterHints,
                    fullHelp: PickerShortcutHelp.picker,
                    cheatSheetVisible: Binding(
                        get: { model.cheatSheetVisible },
                        set: { model.cheatSheetVisible = $0 }
                    )
                )
            }
        }
    }
}

private extension RiskLevel {
    var rank: Int { rawValue }
}

private struct CheatSheetOverlay: View {
    @ObservedObject var model: PickerViewModel
    @ObservedObject private var appSettings = SettingsStore.shared

    private var accent: Color { appSettings.settings.accentPreset.swiftUIColor }
    private var theme: ChromeTheme { appSettings.settings.chromeTheme }
    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .onTapGesture {
                    model.cheatSheetVisible = false
                }

            PickerGlassPanel(theme: theme, accent: accent, cornerRadius: 20, subtle: true) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    CheatSheetGrid(
                        rows: model.cheatSheetRows,
                        keyWidth: 80,
                        labelWidth: 210,
                        rowSpacing: 8,
                        columnGap: 28
                    )
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 20)
                .fixedSize(horizontal: true, vertical: true)
            }
            .fixedSize(horizontal: true, vertical: true)
            .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct QRSheetOverlay: View {
    @ObservedObject var model: PickerViewModel
    @ObservedObject private var appSettings = SettingsStore.shared
    @State private var doneHovered = false

    private var accent: Color { appSettings.settings.accentPreset.swiftUIColor }
    private var theme: ChromeTheme { appSettings.settings.chromeTheme }

    private let qrSize: CGFloat = 160
    private let quietZone: CGFloat = 10

    private var codeSide: CGFloat { qrSize + quietZone * 2 }
    private var cardWidth: CGFloat { codeSide + 32 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .onTapGesture {
                    model.closeQRSheet()
                }

            PickerGlassPanel(theme: theme, accent: accent, subtle: true) {
                VStack(spacing: 0) {
                    qrPlate
                    doneButton
                        .padding(.top, 12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(width: cardWidth)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var qrPlate: some View {
        Group {
            if let cgImage = model.qrImage {
                let nsImage = NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: cgImage.width, height: cgImage.height)
                )
                Image(nsImage: nsImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: qrSize, height: qrSize)
            } else {
                ProgressView()
                    .controlSize(.regular)
                    .frame(width: qrSize, height: qrSize)
            }
        }
        .padding(quietZone)
        .frame(width: codeSide, height: codeSide)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        )
        .help("Scan to open this link on your phone")
    }

    private var doneButton: some View {
        Button {
            model.closeQRSheet()
        } label: {
            Text("Done")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(doneHovered ? 0.92 : 0.78))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(doneHovered ? 0.12 : 0.09),
                                    Color.white.opacity(doneHovered ? 0.06 : 0.04),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(doneHovered ? 0.14 : 0.09), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
        .onHover { doneHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: doneHovered)
    }
}

private struct PickerTile: View {
    let option: LaunchOption
    let number: Int
    let selected: Bool
    let multiSelected: Bool
    let dimmed: Bool
    let showIncognito: Bool
    let appearDelay: Double
    @State private var hovered: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: option.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 60, height: 60)
                    .scaleEffect(hovered && !selected ? 1.06 : (selected ? 1.03 : 1.0))
                    .overlay(alignment: .bottomTrailing) {
                        if showIncognito {
                            IncognitoBadge(size: 22)
                                .offset(x: 5, y: 5)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                if number <= 9 {
                    Text("\(number)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.85))
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                        )
                        .offset(x: 8, y: -5)
                }

                if multiSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 17))
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        .offset(x: 8, y: 48)
                }
            }
            .frame(height: 68)

            VStack(spacing: 3) {
                Text(option.browser.name)
                    .font(.system(size: 14, weight: selected ? .semibold : .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let profile = option.profile {
                    HStack(spacing: 5) {
                        if let hex = option.colorHex, let color = Color(hexString: hex) {
                            Capsule()
                                .fill(color)
                                .frame(width: 12, height: 4)
                        }
                        Text(profile.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 5)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 10)
        .frame(width: 144, height: 156)
        .background(
            tileFill
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tileStroke, lineWidth: selected || multiSelected ? 2 : 1)
        )
        .shadow(
            color: selected ? Color.accentColor.opacity(0.35) : Color.black.opacity(hovered ? 0.22 : 0.0),
            radius: selected ? 14 : 8,
            x: 0,
            y: selected ? 6 : 3
        )
        .opacity(dimmed ? 0.45 : 1.0)
        .contentShape(Rectangle())
        .scaleEffect(appeared ? 1.0 : 0.9)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(appearDelay)) {
                appeared = true
            }
        }
        .onHover { isHovered in
            hovered = isHovered
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .animation(.easeOut(duration: 0.15), value: hovered)
        .animation(.easeOut(duration: 0.15), value: selected)
        .animation(.easeOut(duration: 0.15), value: multiSelected)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: showIncognito)
    }

    @ViewBuilder
    private var tileFill: some View {
        if multiSelected {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.30), Color.accentColor.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if selected {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.34), Color.accentColor.opacity(0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if hovered {
            LinearGradient(
                colors: [Color.white.opacity(0.12), Color.white.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var tileStroke: Color {
        if multiSelected { return Color.accentColor.opacity(0.75) }
        if selected { return Color.accentColor.opacity(0.85) }
        if hovered { return Color.white.opacity(0.18) }
        return Color.white.opacity(0.06)
    }
}

private struct PickerListRow: View {
    let option: LaunchOption
    let number: Int
    let selected: Bool
    let multiSelected: Bool
    let dimmed: Bool
    let showIncognito: Bool
    @State private var hovered: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: option.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)
                if showIncognito {
                    IncognitoBadge(size: 14)
                        .offset(x: 3, y: 3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(option.browser.name)
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let profile = option.profile {
                    HStack(spacing: 6) {
                        if let hex = option.colorHex, let color = Color(hexString: hex) {
                            Capsule()
                                .fill(color)
                                .frame(width: 10, height: 4)
                        }
                        Text(profile.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if multiSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14))
            }

            if number <= 9 {
                Text("\(number)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.75))
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                    )
            }
        }
        .padding(.horizontal, 12)
        .frame(height: PickerView.listRowHeight)
        .background(
            rowFill
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(rowStroke, lineWidth: selected || multiSelected ? 1.5 : 0.5)
        )
        .opacity(dimmed ? 0.45 : 1.0)
        .contentShape(Rectangle())
        .onHover { isHovered in
            hovered = isHovered
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .animation(.easeOut(duration: 0.15), value: hovered)
        .animation(.easeOut(duration: 0.15), value: selected)
        .animation(.easeOut(duration: 0.15), value: multiSelected)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: showIncognito)
    }

    @ViewBuilder
    private var rowFill: some View {
        if multiSelected {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.14)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if selected {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.30), Color.accentColor.opacity(0.12)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if hovered {
            Color.white.opacity(0.08)
        } else {
            Color.white.opacity(0.04)
        }
    }

    private var rowStroke: Color {
        if multiSelected { return Color.accentColor.opacity(0.7) }
        if selected { return Color.accentColor.opacity(0.8) }
        if hovered { return Color.white.opacity(0.16) }
        return Color.white.opacity(0.06)
    }
}

struct IncognitoBadge: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.78))
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                )
            Image(systemName: "eyeglasses")
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

private struct KeyEventCatcher: NSViewRepresentable {
    let model: PickerViewModel

    func makeNSView(context: Context) -> NSView {
        let view = KeyCatcherView()
        view.model = model
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class KeyCatcherView: NSView {
    weak var model: PickerViewModel?
    private var monitor: Any?
    private var flagsMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else {
            if let monitor { NSEvent.removeMonitor(monitor) }
            if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
            monitor = nil
            flagsMonitor = nil
            return
        }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self, let model = self.model, event.window === self.window else { return event }
            let held = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option)
            if model.optionKeyHeld != held {
                model.optionKeyHeld = held
            }
            return event
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let model = self.model, event.window === self.window else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let cmd = modifiers.contains(.command)
            let opt = modifiers.contains(.option)
            let shift = modifiers.contains(.shift)

            if model.showQRSheet {
                if event.keyCode == 53 {
                    model.closeQRSheet()
                    return nil
                }
                return nil
            }

            // Cheat sheet key handling: ? toggles overlay; Escape hides it when visible.
            // Works in both picker and preview modes. dismiss signal is only acted on
            // in normal picker mode below (preview mode has its own Escape semantics).
            let cheatChars: String? = {
                if let chars = event.characters, !chars.isEmpty { return chars }
                // Shift+/ is ? on US keyboards; charactersIgnoringModifiers is "/".
                if event.keyCode == 44, shift { return "?" }
                return event.charactersIgnoringModifiers
            }()
            let cheatEvent = KeyEvent(
                characters: cheatChars,
                keyCode: event.keyCode,
                shift: shift
            )
            let cheatOutcome = PickerKeyHandler.handle(event: cheatEvent, model: model)
            if cheatOutcome.consumed { return nil }

            if model.previewMode {
                switch event.keyCode {
                case 53:
                    model.exitPreview(); return nil
                case 49 where !shift && !cmd:
                    model.exitPreview(); return nil
                case 36, 76:
                    model.openInBrowserFromPreview(
                        remember: cmd ? true : nil,
                        incognito: opt ? true : nil
                    )
                    return nil
                case 123, 126:
                    model.moveSelection(-1); return nil
                case 124, 125:
                    model.moveSelection(1); return nil
                default: break
                }
                if cmd && !shift,
                   event.charactersIgnoringModifiers?.lowercased() == "c" {
                    model.copyCleanedURL()
                    return nil
                }
                if modifiers == .option,
                   event.charactersIgnoringModifiers?.lowercased() == "p" {
                    model.toggleIncognito()
                    return nil
                }
                if (modifiers.isEmpty || modifiers == .command) && !shift,
                   let chars = event.charactersIgnoringModifiers,
                   chars.count == 1,
                   let digit = Int(chars),
                   digit >= 1, digit <= 9 {
                    let idx = digit - 1
                    guard model.visibleFlatOptions.indices.contains(idx) else { return nil }
                    model.selectedIndex = idx
                    return nil
                }
                return event
            }

            // Normal picker mode: act on dismiss signal from PickerKeyHandler (Escape, sheet hidden).
            if cheatOutcome.dismiss {
                model.cancel()
                return nil
            }

            switch event.keyCode {
            case 124, 125:
                model.moveSelection(1); return nil
            case 123, 126:
                model.moveSelection(-1); return nil
            case 49:
                if shift {
                    model.toggleMultiAtSelection()
                } else {
                    model.enterPreview()
                }
                return nil
            case 36, 76:
                model.confirmSelection(
                    remember: cmd ? true : nil,
                    incognito: opt ? true : nil
                )
                return nil
            default: break
            }
            if modifiers == .command,
               event.charactersIgnoringModifiers?.lowercased() == "c" {
                model.copyCleanedURL()
                return nil
            }
            if modifiers == .option,
               event.charactersIgnoringModifiers?.lowercased() == "p" {
                model.toggleIncognito()
                return nil
            }
            if (modifiers.isEmpty || modifiers == .shift || modifiers == .command || modifiers == .option),
               let chars = event.charactersIgnoringModifiers,
               chars.count == 1,
               let digit = Int(chars),
               digit >= 1, digit <= 9 {
                let withRemember = modifiers.contains(.command)
                let withPrivate = modifiers.contains(.option) ? true : nil
                model.pickByNumber(
                    digit,
                    remember: withRemember ? true : nil,
                    incognito: withPrivate
                )
                return nil
            }
            return event
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
    }
}

struct CircularWedge: Shape {
    let startAngle: Double
    let endAngle: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        let startRad = startAngle * .pi / 180.0
        let endRad = endAngle * .pi / 180.0
        
        let outerStart = CGPoint(x: center.x + outerRadius * cos(startRad), y: center.y + outerRadius * sin(startRad))
        let innerEnd = CGPoint(x: center.x + innerRadius * cos(endRad), y: center.y + innerRadius * sin(endRad))
        
        path.move(to: CGPoint(x: center.x + innerRadius * cos(startRad), y: center.y + innerRadius * sin(startRad)))
        path.addLine(to: outerStart)
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        path.addLine(to: innerEnd)
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .degrees(endAngle),
            endAngle: .degrees(startAngle),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}
