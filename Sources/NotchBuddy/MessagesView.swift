import SwiftUI

/// Settings > Messages: which moments the closed notch tells you about, grouped by topic.
/// Each row says when it shows, what it looks like, and has a switch. Some have a limit you can set
/// ("under 10%"). The notch at the top shows the one you clicked last.
struct MessagesPane: View {
    let model: NotchModel
    @State private var chosen = Prefs.messages
    @State private var shown = Notice.Kind.askToRun

    /// None, Important or All; Custom when you've picked your own mix.
    enum Preset: String, CaseIterable {
        case none = "None", important = "Important", all = "All", custom = "Custom"

        var kinds: Set<Notice.Kind>? {
            switch self {
            case .none: []
            case .important: Notice.Kind.important
            case .all: Set(Notice.Kind.listed)
            case .custom: nil
            }
        }
    }

    private var preset: Binding<Preset> {
        Binding(
            get: { Preset.allCases.first { $0.kinds == chosen } ?? .custom },
            set: { if let kinds = $0.kinds { chosen = kinds } })
    }

    var body: some View {
        let on = chosen.contains(shown)
        PaneHeader(title: "Messages", text: "Which moments the closed notch tells you about. A message waits its turn instead of covering a more important one.")

        NotchPreview(caption: on ? "What the closed notch says. Click any example below to see it here."
                                 : "Switched off: Clawd still reacts, but the notch stays quiet.") {
            ClosedNotch(mode: shown.tone == .needs ? "waiting" : shown.tone == .good ? "done" : "working", color: model.restingColor, wing: 150) {
                if on {
                    if shown.tone == .needs {
                        Text(shown.example).foregroundStyle(Color(red: 0x23 / 255, green: 0x1C / 255, blue: 0))
                            .padding(.horizontal, 9).frame(height: 20).background(Capsule().fill(NotchView.amber)).fixedSize()
                    } else {
                        Text(shown.example).foregroundStyle(shown.color)
                    }
                }
            }
            .id("\(shown.rawValue)\(Prefs.limit(shown))")
        }

        Picker("Show", selection: preset) {
            ForEach(Preset.allCases, id: \.self) { preset in
                // Custom is where you end up, not something to pick.
                if preset != .custom || self.preset.wrappedValue == .custom { Text(preset.rawValue).tag(preset) }
            }
        }
        .pickerStyle(.segmented).labelsHidden()

        ForEach(Notice.Kind.topics, id: \.title) { topic in
            SettingsGroup(title: topic.title, footer: topic.note) {
                ForEach(topic.kinds, id: \.self) { kind in
                    MessageRow(kind: kind, on: Binding(
                        get: { chosen.contains(kind) },
                        set: { on in if on { chosen.insert(kind) } else { chosen.remove(kind) }; shown = kind }),
                        tryOut: { shown = kind; model.tryOut(kind) })
                    .padding(.leading, 14)
                    .padding(.trailing, 10)
                    .frame(minHeight: 40)
                    .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.09)).frame(height: 1) }
                }
            }
        }
        .onChange(of: chosen) { _, now in Prefs.messages = now }
    }
}

/// "Usage is running low under [10%]   (10% left)   [switch]"
struct MessageRow: View {
    let kind: Notice.Kind
    @Binding var on: Bool
    let tryOut: () -> Void
    @State private var limit: Int

    init(kind: Notice.Kind, on: Binding<Bool>, tryOut: @escaping () -> Void) {
        self.kind = kind
        _on = on
        self.tryOut = tryOut
        _limit = State(initialValue: Prefs.limit(kind))
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(kind.limit.map { "\(kind.label) \($0.before)" } ?? kind.label)
            if let rule = kind.limit {
                Picker(rule.before, selection: $limit) {
                    ForEach(rule.options, id: \.self) { Text(rule.text($0)).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .onChange(of: limit) { _, value in Prefs.setLimit(kind, value) }
            }
            Spacer(minLength: 8)
            // What the closed notch would say. Click it to see it on the real notch.
            Button(action: tryOut) {
                Text(kind.example)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(on ? kind.color : Color.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    // Off: plain grey text in an outline, so it's still easy to read.
                    .background(on ? Color.black : Color.clear, in: Capsule())
                    .overlay(Capsule().strokeBorder(on ? Color.clear : Color.secondary.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .help("Show it on the notch")
            .id(limit)
            Toggle(kind.label, isOn: $on).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}
