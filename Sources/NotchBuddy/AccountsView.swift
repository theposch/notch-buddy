import SwiftUI

/// Settings > Usage and accounts: the Claude accounts Notch Buddy knows (rename them, pick their
/// colour, switch them off), where usage comes from, and whose usage the closed notch shows.
struct UsagePane: View {
    let model: NotchModel
    @AppStorage("loginUsage") private var terminal = false
    @AppStorage("desktopUsage") private var desktop = false
    @AppStorage("usageFollows") private var follows = "lead"

    var body: some View {
        let _ = model.prefs
        PaneHeader(title: "Usage and accounts", text: "How much of your Claude limits is left, and which accounts Notch Buddy knows.")

        if model.accounts.isEmpty {
            SettingsGroup {
                SettingsRow(label: "No usage yet", text: "Switch on a login below, or use Claude Code in the Terminal. Your accounts show up here.") { EmptyView() }
            }
        } else {
            SettingsGroup(title: "Accounts", footer: "Rename them so you can tell them apart. Click a ring for another colour. Emails stay on your Mac.") {
                ForEach(model.accounts) { account in AccountCard(model: model, account: account) }
            }
        }

        SettingsGroup(title: "Where usage comes from",
                      footer: "Claude Code in the Terminal also sends usage while it runs. Logins are only sent to Anthropic.") {
            ForEach(model.loginChecks, id: \.source) { check in
                LoginRow(check: check, on: check.source == .terminal ? $terminal : $desktop)
            }
        }

        if model.accounts.filter(\.shown).count > 1 {
            SettingsGroup {
                SettingsRow(label: "Closed notch shows usage for") {
                    Picker("Closed notch shows usage for", selection: $follows) {
                        Text("The account you\u{2019}re working in").tag("lead")
                        Text("Whichever is lowest").tag("lowest")
                        Divider()
                        ForEach(model.accounts) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden().fixedSize()
                }
            }
        }
    }
}

/// "Read the Terminal's Claude login": a switch, what it's doing, and Allow when macOS wants your OK.
struct LoginRow: View {
    let check: LoginUsage
    @Binding var on: Bool

    var body: some View {
        SettingsRow(label: title, text: note) {
            if on, check.state == .needsOK {
                Button("Allow\u{2026}") { Task { await check.check(asking: true) } }
            }
            Toggle(title, isOn: $on).labelsHidden().toggleStyle(.switch)
        }
        .onChange(of: on) { _, on in Task { await check.check(asking: on) } }
    }

    private var title: String {
        check.source == .terminal ? "Read the Terminal\u{2019}s Claude login" : "Read the desktop app\u{2019}s login"
    }

    private var note: String {
        switch check.state {
        case .off:
            check.source == .terminal ? "The account Claude Code in the Terminal is logged in to. macOS asks you first."
                                      : "The account the Claude desktop app is logged in to. macOS asks you first."
        case .needsOK: "Click Allow, then \u{201C}Always Allow\u{201D} in the macOS prompt."
        case .checked(let when): "Working. Checked \(when.formatted(.relative(presentation: .named)))."
        case .problem(let text): text
        }
    }
}

/// One account: a big ring for its usage left (click for another colour), its name with a pencil to
/// change it, where it's logged in, its email and limits, and a switch.
struct AccountCard: View {
    let model: NotchModel
    let account: Account
    @State private var name = ""
    /// The pencil was clicked: the name is a box to type in until Return, Esc or a click elsewhere.
    @State private var editing = false
    @FocusState private var typing: Bool

    var body: some View {
        // Colour and Show are saved settings, which SwiftUI doesn't watch; the model does.
        let _ = model.prefs
        let color = Color(hex: account.color(among: model.accounts))
        HStack(spacing: 14) {
            Button {
                let colors = Account.colors, now = account.color(among: model.accounts)
                set("color", colors[((colors.firstIndex(of: now) ?? 0) + 1) % colors.count])
            } label: {
                ZStack {
                    Ring(fraction: Double(account.left ?? 0) / 100, color: color, size: 52, line: 5)
                    Text(account.left.map { "\($0)%" } ?? "\u{2013}").font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.primary)
                }
            }
            .buttonStyle(.plain)
            .help("Click for another colour")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if editing {
                        // Return or a click elsewhere keeps it, Esc doesn't. Emptied, it goes back to the short name ("Desktop").
                        TextField("Name", text: $name, prompt: Text(account.defaultName))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 170)
                            .focused($typing)
                            .onAppear { typing = true }
                            .onSubmit(keep)
                            .onExitCommand { editing = false }
                            .onChange(of: typing) { _, still in if !still { keep() } }
                    } else {
                        Text(account.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                            .onTapGesture(count: 2, perform: edit)
                        Button(action: edit) {
                            Image(systemName: "pencil").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                                .frame(width: 18, height: 18).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Rename this account")
                        .accessibilityLabel("Rename \(account.name)")
                        if let from = account.from {
                            Text(from).font(.system(size: 11)).foregroundStyle(.secondary)
                                .padding(.horizontal, 7).padding(.vertical, 1)
                                .background(Capsule().fill(Color.primary.opacity(0.06)))
                        }
                    }
                }
                if let email = account.email {
                    Text(email).font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                }
                Text(account.summary.isEmpty ? "Waiting for the next check of its usage." : Self.limits(account))
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
                if let pace = account.paceText() {
                    Text(pace + ", before it resets.").font(.system(size: 11.5, weight: .medium)).foregroundStyle(NotchView.orange).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Toggle("Show", isOn: Binding(get: { account.shown }, set: { set("hidden", $0 ? nil : true) }))
                .labelsHidden().toggleStyle(.switch)
        }
        .padding(.leading, 14).padding(.trailing, 10).padding(.vertical, 12)
        .opacity(account.shown ? 1 : 0.5)
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.09)).frame(height: 1) }
    }

    /// "5 hours: 72% left, resets 3:50 PM · Week: 88% left", without the email the line above shows.
    static func limits(_ account: Account) -> String {
        var parts: [String] = []
        if let usage = account.usage, let left = account.left { parts.append("5 hours: \(left)% left, resets \(usage.resets.formatted(date: .omitted, time: .shortened))") }
        if let left = account.week?.left() { parts.append("Week: \(left)% left") }
        return parts.joined(separator: " \u{00B7} ")
    }

    private func edit() {
        name = account.name
        editing = true
    }

    private func keep() {
        guard editing else { return }
        editing = false
        set("name", Self.custom(name, for: account))
    }

    /// What to save for a typed name: nothing when it's empty or just the short name again.
    static func custom(_ typed: String, for account: Account) -> String? {
        let name = typed.trimmingCharacters(in: .whitespaces)
        return name.isEmpty || name == account.defaultName ? nil : name
    }

    /// "Desktop app · you@work.com"
    static func `where`(_ account: Account) -> String {
        [account.from, account.email].compactMap { $0 }.joined(separator: " \u{00B7} ").nilIfEmpty ?? "Claude"
    }

    private func set(_ what: String, _ value: Any?) {
        UserDefaults.standard.set(value, forKey: "account.\(account.id).\(what)")
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
