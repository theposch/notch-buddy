import Darwin
import Foundation

/// The private "mail slot" between the hook helper and the running app:
/// a local socket file only this user can open.
enum EventSocket {
    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/Notch Buddy Next")
    }
    static var path: String { folder.appending(path: "events.sock").path }

    static func address() -> sockaddr_un? {
        var addr = sockaddr_un()
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { return nil }
        addr.sun_family = sa_family_t(AF_UNIX)
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &addr.sun_path) { $0.copyBytes(from: bytes) }
        return addr
    }

    static func withAddress(_ body: (UnsafePointer<sockaddr>, socklen_t) -> Int32) -> Int32 {
        guard var addr = address() else { return -1 }
        return withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }
}

/// The helper Claude Code runs for each event. It must never hold Claude up:
/// it always exits straight away with code 0 and prints nothing.
enum HookHelper {
    static func run() -> Never {
        // A safety net in case anything below gets stuck.
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { exit(0) }
        let event = FileHandle.standardInput.readDataToEndOfFile()
        send(event)
        exit(0)
    }

    private static func send(_ data: Data) {
        guard !data.isEmpty else { return }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        defer { close(fd) }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        var wait = timeval(tv_sec: 0, tv_usec: 300_000)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &wait, socklen_t(MemoryLayout<timeval>.size))
        // No app listening? connect fails at once and we simply stop.
        guard EventSocket.withAddress({ connect(fd, $0, $1) }) == 0 else { return }
        data.withUnsafeBytes { buffer in
            var sent = 0
            while sent < buffer.count {
                let n = write(fd, buffer.baseAddress! + sent, buffer.count - sent)
                if n <= 0 { return }
                sent += n
            }
        }
    }
}

/// The app's side: listens on the socket and hands each event over.
final class EventListener: @unchecked Sendable {
    private let fd: Int32
    private let source: DispatchSourceRead

    init?(onEvent: @escaping @Sendable (Data) -> Void) {
        try? FileManager.default.createDirectory(at: EventSocket.folder, withIntermediateDirectories: true)
        unlink(EventSocket.path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        guard EventSocket.withAddress({ bind(fd, $0, $1) }) == 0, listen(fd, 16) == 0 else {
            close(fd); return nil
        }
        chmod(EventSocket.path, 0o600)
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)

        self.fd = fd
        source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: DispatchQueue(label: "events"))
        source.setEventHandler {
            while case let client = accept(fd, nil, nil), client >= 0 {
                onEvent(Self.readAll(client))
            }
        }
        source.resume()
    }

    private static func readAll(_ client: Int32) -> Data {
        defer { close(client) }
        _ = fcntl(client, F_SETFL, fcntl(client, F_GETFL) & ~O_NONBLOCK)
        var wait = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &wait, socklen_t(MemoryLayout<timeval>.size))
        var data = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        while case let n = read(client, &chunk, chunk.count), n > 0 {
            data.append(chunk, count: n)
        }
        return data
    }
}
