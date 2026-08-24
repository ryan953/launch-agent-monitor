import SwiftUI

struct LogTailWindowView: View {
    let label: String
    var viewModel: AgentListViewModel

    @State private var selectedTab: Tab = .stdout
    @State private var lines: [String] = []
    @State private var plistXML: String = ""

    enum Tab: Hashable {
        case stdout
        case stderr
        case plist

        var title: String {
            switch self {
            case .stdout: return "stdout"
            case .stderr: return "stderr"
            case .plist: return "Plist"
            }
        }
    }

    private var item: LaunchAgentItem? {
        viewModel.items.first { $0.label == label }
    }

    /// Only includes log streams that are actually configured (and, if
    /// both are, only once if they point at the same file) — Plist is
    /// always available regardless.
    private var availableTabs: [Tab] {
        var tabs: [Tab] = []
        if item?.standardOutPath != nil {
            tabs.append(.stdout)
        }
        if let err = item?.standardErrorPath, err != item?.standardOutPath {
            tabs.append(.stderr)
        }
        tabs.append(.plist)
        return tabs
    }

    private var currentLogPath: String? {
        switch selectedTab {
        case .stdout: return item?.standardOutPath
        case .stderr: return item?.standardErrorPath
        case .plist: return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 480, minHeight: 320)
        .onAppear {
            if !availableTabs.contains(selectedTab) {
                selectedTab = availableTabs.first ?? .plist
            }
        }
        .task(id: currentLogPath) {
            lines = []
            guard let path = currentLogPath else { return }
            let tailer = LogTailer(path: path)
            for await line in tailer.lines() {
                lines.append(line)
                if lines.count > 2000 {
                    lines.removeFirst(lines.count - 2000)
                }
            }
        }
        .task(id: selectedTab == .plist ? item?.plistURL : nil) {
            guard selectedTab == .plist, let url = item?.plistURL else { return }
            plistXML = Self.formattedXML(at: url)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item?.displayName ?? label)
                    .font(.headline)
                Text(selectedTab == .plist ? (item?.plistURL.path ?? "") : (currentLogPath ?? ""))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer()
            if availableTabs.count > 1 {
                Picker("View", selection: $selectedTab) {
                    ForEach(availableTabs, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .padding(10)
    }

    @ViewBuilder
    private var content: some View {
        if item == nil {
            ContentUnavailableView("Agent Not Found", systemImage: "questionmark.circle")
        } else if selectedTab == .plist {
            plistContent
        } else if currentLogPath == nil {
            ContentUnavailableView(
                "No Log File Configured",
                systemImage: "doc.text.magnifyingglass",
                description: Text("launchd is not capturing this agent's output (no StandardOutPath/StandardErrorPath in its plist).")
            )
        } else {
            logContent
        }
    }

    private var plistContent: some View {
        ScrollView {
            Text(plistXML)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
    }

    private var logContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .id(index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            .onChange(of: lines.count) { _, _ in
                if let last = lines.indices.last {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
    }

    /// Re-serializes the plist through `PropertyListSerialization` so both
    /// XML and binary-format source plists render as readable, pretty
    /// printed XML.
    private static func formattedXML(at url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else {
            return "Could not read plist file at \(url.path)."
        }
        do {
            let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            let xmlData = try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0)
            return String(data: xmlData, encoding: .utf8) ?? "Could not decode plist as UTF-8."
        } catch {
            return "Could not parse plist: \(error.localizedDescription)"
        }
    }
}
