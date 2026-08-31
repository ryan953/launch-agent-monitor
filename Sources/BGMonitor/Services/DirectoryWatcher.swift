import Foundation

/// Watches one or more directories for content changes (files added/removed)
/// using a `DispatchSourceFileSystemObject` per directory, invoking
/// `onChange` on the main thread whenever anything changes.
final class DirectoryWatcher {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var fileDescriptors: [Int32] = []

    init(directories: [URL], onChange: @escaping @Sendable () -> Void) {
        for directory in directories {
            let fd = open(directory.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            fileDescriptors.append(fd)

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: DispatchQueue.main
            )
            source.setEventHandler(handler: onChange)
            source.setCancelHandler { close(fd) }
            source.resume()
            sources.append(source)
        }
    }

    deinit {
        for source in sources { source.cancel() }
    }
}
