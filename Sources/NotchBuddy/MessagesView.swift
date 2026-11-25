import SwiftUI

/// Which messages the closed notch shows, grouped by topic. Each row says when it shows,
/// what it looks like, and has a switch. Some have a limit you can set ("under 10%").
struct MessagesView: View {
    let model: NotchModel
    @Environment(\.dismiss) private var dismiss
    @State private var chosen = Prefs.messages

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
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Show", selection: preset) {
                        ForEach(Preset.allCases, id: \.self) { preset in
                            // Custom is where you end up, not something to pick.
                            if preset != .custom || self.preset.wrappedValue == .custom { Text(preset.rawValue).tag(preset) }
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("A message waits its turn instead of covering a more important one. Clawd still reacts to the ones you switch off.")
                        .foregroundStyle(.secondary)
                }

                ForEach(Notice.Kind.topics, id: \.title) { topic in
                    Section {
                        ForEach(topic.kinds, id: \.self) { kind in
                            MessageRow(kind: kind, on: Binding(
                                get: { chosen.contains(kind) },
                                set: { on in if on { chosen.insert(kind) } else { chosen.remove(kind) } }),
                                tryOut: { model.tryOut(kind) })
                        }
                    } header: {
                        Text(topic.title)
                    } footer: {
                        if let note = topic.note { Text(note).foregroundStyle(.secondary) }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 520, height: 600)
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
