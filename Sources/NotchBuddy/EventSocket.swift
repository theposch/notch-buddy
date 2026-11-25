import Darwin
import Foundation

/// The private "mail slot" between the hook helper and the running app:
/// a local socket file only this user can open.
enum EventSocket {
    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/Notch Buddy")
    }
    static var path: String { folder.appending(path: "events.sock").path }

    static func withAddress(_ path: String, _ body: (UnsafePointer<sockaddr>, socklen_t) -> Int32) -> Int32 {
        var addr = sockaddr_un()
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { return -1 }
        addr.sun_family = sa_family_t(AF_UNIX)
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &addr.sun_path) { $0.copyBytes(from: bytes) }
        return withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }

    static func setTimeout(_ fd: Int32, _ option: Int32, seconds: Double) {
        var wait = timeval(tv_sec: Int(seconds), tv_usec: Int32((seconds - floor(seconds)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, option, &wait, socklen_t(MemoryLayout<timeval>.size))
    }

    /// Marks the end of an event, so the helper can keep the line open while it waits.
    static let end: UInt8 = 0

    /// Reads until the end mark, until the other side hangs up, or until the wait runs out.
    static func readAll(_ fd: Int32) -> Data {
        var data = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        while case let n = read(fd, &chunk, chunk.count), n > 0 {
            data.append(chunk, count: n)
            if data.last == end { return data.dropLast() }
        }
        return data
    }
}

/// The helper Claude Code runs for each event. It must never hold Claude up or break it:
/// whatever goes wrong, it exits with code 0, and it only ever prints a permission answer.
enum HookHelper {
    static func run() -> Never {
        let event = FileHandle.standardInput.readDataToEndOfFile()
        let waits = Permission.wantsAnswer(event)
        // A safety net in case anything below gets stuck.
        DispatchQueue.global().asyncAfter(deadline: .now() + (waits ? Permission.wait + 1 : 1)) { exit(0) }
        let reply = send(Account.addingOrg(to: Git.addingBranch(to: ConversationSize.adding(to: Place.addingHere(to: event)))), to: EventSocket.path, wait: waits ? Permission.wait : nil)
        if let reply, let answer = Permission.output(for: reply, event: event) {
            FileHandle.standardOutput.write(answer)
        }
        exit(0)
    }

    /// Hands the event to the app. With a `wait`, also waits that long for its one-word answer.
    /// Returns nil when there's no app, no answer, or anything fails.
    static func send(_ data: Data, to path: String, wait: Double?) -> Data? {
        guard !data.isEmpty else { return nil }
        let data = data + [EventSocket.end]
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        EventSocket.setTimeout(fd, SO_SNDTIMEO, seconds: 0.3)
        // No app listening? connect fails at once and we simply stop.
        guard EventSocket.withAddress(path, { connect(fd, $0, $1) }) == 0 else { return nil }
        let sent = data.withUnsafeBytes { buffer -> Bool in
            var sent = 0
            while sent < buffer.count {
                let n = write(fd, buffer.baseAddress! + sent, buffer.count - sent)
                if n <= 0 { return false }
                sent += n
            }
            return true
        }
        guard sent, let wait else { return nil }
        EventSocket.setTimeout(fd, SO_RCVTIMEO, seconds: wait)
        let reply = EventSocket.readAll(fd)
        return reply.isEmpty ? nil : reply
    }
}

/// The open line back to a helper that is waiting for Allow or Deny.
/// It notices when the helper goes away (Claude was answered in the terminal, or it gave up).
final class Reply: @unchecked Sendable {
    private let fd: Int32
    private let queue = DispatchQueue(label: "reply")
    private let watch: DispatchSourceRead
    private var finished = false

    init(fd: Int32, onGone: @escaping @Sendable (Reply) -> Void) {
        self.fd = fd
        watch = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        watch.setEventHandler { [weak self] in
            // The helper never sends more, so anything readable means it has hung up.
            guard let self, !self.finished else { return }
            self.end()
            onGone(self)
        }
        watch.setCancelHandler { close(fd) }
        watch.resume()
    }

    deinit { end() }

    /// Sends "allow" or "deny" and hangs up.
    func send(_ word: String) {
        queue.async { [self] in
            guard !finished else { return }
            _ = word.utf8CString.withUnsafeBufferPointer { write(fd, $0.baseAddress, $0.count - 1) }
            end()
        }
    }

    /// Hangs up without answering, so Claude asks in the terminal as usual.
    func cancel() { queue.async { [self] in end() } }

    private func end() {
        guard !finished else { return }
        finished = true
        watch.cancel()
    }
}

/// The app's side: listens on the socket and hands each event over,
/// with a line to answer on when the helper is waiting for one.
final class EventListener: @unchecked Sendable {
    private let fd: Int32
    private let source: DispatchSourceRead

    init?(path: String = EventSocket.path,
          onEvent: @escaping @Sendable (_ event: Data, _ reply: Reply?) -> Void,
          onGone: @escaping @Sendable (Reply) -> Void = { _ in }) {
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(), withIntermediateDirectories: true)
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        guard EventSocket.withAddress(path, { bind(fd, $0, $1) }) == 0, listen(fd, 16) == 0 else {
            close(fd); return nil
        }
        chmod(path, 0o600)
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)

        self.fd = fd
        source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: DispatchQueue(label: "events"))
        source.setEventHandler {
            while case let client = accept(fd, nil, nil), client >= 0 {
                _ = fcntl(client, F_SETFL, fcntl(client, F_GETFL) & ~O_NONBLOCK)
                var on: Int32 = 1
                setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
                EventSocket.setTimeout(client, SO_RCVTIMEO, seconds: 1)
                let event = EventSocket.readAll(client)
                if Permission.wantsAnswer(event) {
                    onEvent(event, Reply(fd: client, onGone: onGone))
                } else {
                    close(client)
                    onEvent(event, nil)
                }
            }
        }
        source.resume()
    }

    deinit {
        source.cancel()
        close(fd)
    }
}
