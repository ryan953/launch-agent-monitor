import SwiftUI

struct LogTailWindowView: View {
    let label: String
    var viewModel: AgentListViewModel

    @State private var selectedStream: LogStream = .stdout
    @State private var lines: [String] = []

    enum LogStream: String, CaseIterable, Identifiable {
        case stdout = "stdout"
        case stderr = "stderr"
        var id: String { rawValue }
    }

    private var item: LaunchAgentItem? {
        viewModel.items.first { $0.label == label }
    }

    private var currentPath: String? {
        switch selectedStream {
        case .stdout: return item?.standardOutPath ?? item?.standardErrorPath
        case .stderr: return item?.standardErrorPath ?? item?.standardOutPath
        }
    }

    private var showsStreamPicker: Bool {
        guard let out = item?.standardOutPath, let err = item?.standardErrorPath else { return false }
        return out != err
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 480, minHeight: 320)
        .task(id: currentPath) {
            lines = []
            guard let path = currentPath else { return }
            let tailer = LogTailer(path: path)
            for await line in tailer.lines() {
                lines.append(line)
                if lines.count > 2000 {
                    lines.removeFirst(lines.count - 2000)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item?.displayName ?? label)
                    .font(.headline)
                if let currentPath {
                    Text(currentPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            Spacer()
            if showsStreamPicker {
                Picker("Stream", selection: $selectedStream) {
                    ForEach(LogStream.allCases) { stream in
                        Text(stream.rawValue).tag(stream)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
        }
        .padding(10)
    }

    @ViewBuilder
    private var content: some View {
        if item == nil {
            ContentUnavailableView("Agent Not Found", systemImage: "questionmark.circle")
        } else if currentPath == nil {
            ContentUnavailableView(
                "No Log File Configured",
                systemImage: "doc.text.magnifyingglass",
                description: Text("launchd is not capturing this agent's output (no StandardOutPath/StandardErrorPath in its plist).")
            )
        } else {
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
    }
}
