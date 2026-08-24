import Foundation

/// Live-tails a single file, first emitting its existing tail (~8KB) and
/// then newly-appended lines as they're written, recovering from rotation
/// (in-place truncate, or unlink+recreate).
actor LogTailer {
    private let path: String
    private var fd: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var offset: UInt64 = 0
    private var lastInode: UInt64?
    private var pendingPartialLine: String = ""
    private var continuation: AsyncStream<String>.Continuation?
    private var isStopped = false

    init(path: String) {
        self.path = path
    }

    /// Returns immediately; the stream starts producing lines once the
    /// underlying file watch is attached (a moment later on the actor).
    /// Cancelling the consuming `for await` loop (e.g. a SwiftUI `.task`
    /// whose view disappears) automatically tears the watch down.
    nonisolated func lines() -> AsyncStream<String> {
        AsyncStream { continuation in
            Task { await self.attach(continuation) }
        }
    }

    private func attach(_ continuation: AsyncStream<String>.Continuation) {
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.stop() }
        }
        openAndWatch(fromScratch: true)
    }

    private func stop() {
        isStopped = true
        source?.cancel()
        source = nil
        continuation?.finish()
        continuation = nil
    }

    private func openAndWatch(fromScratch: Bool) {
        guard !isStopped else { return }

        source?.cancel()
        source = nil
        if fd >= 0 {
            close(fd)
            fd = -1
        }

        let newFD = open(path, O_EVTONLY)
        guard newFD >= 0 else {
            // File doesn't exist yet (agent has never run / log not created)
            // — poll for its creation rather than giving up.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                await self?.openAndWatch(fromScratch: true)
            }
            return
        }
        fd = newFD

        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attributes?[.size] as? UInt64) ?? 0
        lastInode = attributes?[.systemFileNumber] as? UInt64

        if fromScratch {
            offset = size > 8192 ? size - 8192 : 0
            pendingPartialLine = ""
            emitLines(from: readNewData())
        }

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: DispatchQueue(label: "com.bgmonitor.logtailer")
        )
        newSource.setEventHandler { [weak self] in
            let rawFlags = newSource.data.rawValue
            Task { await self?.handleEvent(flags: DispatchSource.FileSystemEvent(rawValue: rawFlags)) }
        }
        newSource.setCancelHandler { [fd = newFD] in
            close(fd)
        }
        newSource.resume()
        source = newSource
    }

    private func handleEvent(flags: DispatchSource.FileSystemEvent) {
        guard !isStopped else { return }

        if flags.contains(.delete) || flags.contains(.rename) {
            openAndWatch(fromScratch: false)
            offset = 0
            pendingPartialLine = ""
            emitLines(from: readNewData())
            return
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        let currentInode = attributes?[.systemFileNumber] as? UInt64
        let currentSize = (attributes?[.size] as? UInt64) ?? 0

        if currentInode != lastInode || currentSize < offset {
            offset = 0
            pendingPartialLine = ""
            lastInode = currentInode
        }

        emitLines(from: readNewData())
    }

    private func readNewData() -> Data {
        guard fd >= 0 else { return Data() }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        handle.seek(toFileOffset: offset)
        let data = handle.readDataToEndOfFile()
        offset += UInt64(data.count)
        return data
    }

    private func emitLines(from data: Data) {
        guard !data.isEmpty else { return }
        let text = pendingPartialLine + String(decoding: data, as: UTF8.self)
        var lines = text.components(separatedBy: "\n")
        pendingPartialLine = lines.removeLast()
        for line in lines {
            continuation?.yield(line)
        }
    }
}
