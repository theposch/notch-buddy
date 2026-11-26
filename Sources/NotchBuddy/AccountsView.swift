import SwiftUI

/// Where usage comes from, and the Claude accounts it found: rename them, pick their colour,
/// switch them off, and choose whose usage the closed notch shows.
struct AccountsView: View {
    let model: NotchModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("loginUsage") private var terminal = false
    @AppStorage("desktopUsage") private var desktop = false
    @AppStorage("usageFollows") private var follows = "lead"

    var body: some View {
        let _ = model.prefs
        VStack(spacing: 0) {
            Form {
                Section {
                    ForEach(model.loginChecks, id: \.source) { check in
                        LoginRow(check: check, on: check.source == .terminal ? $terminal : $desktop)
                    }
                } header: {
                    Text("Where usage comes from")
                } footer: {
                    Text("Claude Code in the Terminal also sends usage while it runs. Logins are only sent to Anthropic.")
                        .foregroundStyle(.secondary)
                }

                if !model.accounts.isEmpty {
                    Section {
                        ForEach(model.accounts) { account in AccountRow(model: model, account: account) }
                    } header: {
                        Text("Accounts")
                    } footer: {
                        Text("Rename them so you can tell them apart. The colour marks their sessions.")
                            .foregroundStyle(.secondary)
                    }
                }

                if model.accounts.filter(\.shown).count > 1 {
                    Section {
                        Picker("Closed notch shows usage for", selection: $follows) {
                            Text("The account you\u{2019}re working in").tag("lead")
                            Text("Whichever is lowest").tag("lowest")
                            Divider()
                            ForEach(model.accounts) { Text($0.name).tag($0.id) }
                        }
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
        .frame(width: 520, height: 520)
    }
}

/// "Read the Terminal's Claude login": a switch, what it's doing, and Allow when macOS wants your OK.
struct LoginRow: View {
    let check: LoginUsage
    @Binding var on: Bool

    var body: some View {
        LabeledContent {
            HStack {
                if on, check.state == .needsOK {
                    Button("Allow\u{2026}") { Task { await check.check(asking: true) } }
                }
                Toggle(title, isOn: $on).labelsHidden().toggleStyle(.switch)
            }
        } label: {
            Text(title)
            Text(note)
        }
        .onChange(of: on) { _, on in Task { await check.check(asking: on) } }
    }

    private var title: String {
        check.source == .terminal ? "Read the Terminal\u{2019}s Claude login" : "Read this desktop app\u{2019}s login"
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

/// One account: its colour (click for another), its name, where it's from, its usage, and a switch.
struct AccountRow: View {
    let model: NotchModel
    let account: Account
    @State private var name = ""

    var body: some View {
        // Colour and Show are saved settings, which SwiftUI doesn't watch; the model does.
        let _ = model.prefs
        HStack(spacing: 10) {
            Button {
                let colors = Account.colors, now = account.color(among: model.accounts)
                set("color", colors[((colors.firstIndex(of: now) ?? 0) + 1) % colors.count])
            } label: {
                Circle().fill(Color(hex: account.color(among: model.accounts))).frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .help("Click for another colour")

            VStack(alignment: .leading, spacing: 1) {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .fontWeight(.medium)
                    .onChange(of: name) { _, now in set("name", now.isEmpty || now == account.defaultName ? nil : now) }
                Text(account.from ?? "Claude")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let left = account.left {
                Text("\(left)%").monospacedDigit()
                + Text(account.week?.left().map { " \u{00B7} week \($0)%" } ?? "").foregroundStyle(.secondary)
            }
            Toggle("Show", isOn: Binding(
                get: { account.shown },
                set: { set("hidden", $0 ? nil : true) }))
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        .opacity(account.shown ? 1 : 0.5)
        .onAppear { name = account.name }
    }

    private func set(_ what: String, _ value: Any?) {
        UserDefaults.standard.set(value, forKey: "account.\(account.id).\(what)")
    }
}
