import Foundation
import Testing
@testable import NotchBuddy

/// Reading Anthropic's usage answer and Claude Code's saved login. No network, no Keychain.
@MainActor
struct LoginUsageTests {
    @Test func readsTheUsageAnswer() throws {
        let answer = """
        {"five_hour": {"utilization": 22.0, "resets_at": "2026-11-25T20:00:00.123456+00:00"},
         "seven_day": {"utilization": 41, "resets_at": "2026-11-30T08:00:00Z"},
         "seven_day_opus": null}
        """
        let event = try #require(LoginUsage.event(from: Data(answer.utf8)))
        #expect(event["hook_event_name"] as? String == Usage.event)
        #expect(event["used_percentage"] as? Double == 22)
        #expect(event["week_used"] as? Double == 41)
        let resets = try #require(event["resets_at"] as? Double)
        #expect(abs(resets - LoginUsage.date("2026-11-25T20:00:00Z")!.timeIntervalSince1970 - 0.123456) < 0.01)
    }

    @Test func missingWindowsAreLeftOut() {
        #expect(LoginUsage.event(from: Data(#"{"five_hour": null, "seven_day": null}"#.utf8)) == nil)
        // Not started yet: nothing used, and it would end 5 hours after your next message.
        let fresh = LoginUsage.event(from: Data(#"{"five_hour": {"utilization": 0, "resets_at": null}}"#.utf8))
        #expect(fresh?["used_percentage"] as? Double == 0)
        #expect((fresh?["resets_at"] as? Double ?? 0) > Date().timeIntervalSince1970 + 4 * 3600)
        #expect(LoginUsage.event(from: Data("not json".utf8)) == nil)
    }

    @Test func readsTheSavedLogin() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func login(_ expires: Double) -> Data {
            Data(#"{"claudeAiOauth": {"accessToken": "abc", "expiresAt": \#(expires)}}"#.utf8)
        }
        #expect(LoginUsage.token(from: login(1_800_000_600_000), now: now) == .found("abc"))
        #expect(LoginUsage.token(from: login(1_799_999_000_000), now: now) == .expired)
        #expect(LoginUsage.token(from: Data(#"{"mcpOAuth": {}}"#.utf8), now: now) == .missing)
    }

    @Test func usageFromTheLoginIsNotClaudeCodeTalking() {
        let model = NotchModel()
        model.live = false
        model.takeUsage(["used_percentage": 30.0, "resets_at": Date().timeIntervalSince1970 + 3600])
        #expect(model.usageLeft == 70)
        #expect(model.lastHeard == nil)   // Settings' "last heard from Claude Code" stays honest
    }
}
