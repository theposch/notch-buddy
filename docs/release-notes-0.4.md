# Notch Buddy 0.4

Know when you'll run out, keep many sessions tidy, and land in the right window.

## New

- **Usage forecast.** When you're on track to run out before your 5-hour limit resets, the notch says when, right beside your usage: "out 3:40 PM". Hover a ring or open Settings > Usage and accounts for the same line.
- **A heads-up before you run out.** A new message, "Out by 3:40 PM", once per window when you're half an hour away at your current pace. It's on by default; switch it off in Settings > Messages.
- **Group by project.** Sessions in the same folder sit under the project's name, with a count. Click the name to fold them away. A session that needs you always stays on top. Choose Never, When there are many, or Always in Settings > Sessions.
- **Jump to more apps.** Clicking a session now goes to the right tab in iTerm2, the right pane in WezTerm, kitty and tmux, and the project window in Zed and JetBrains editors. The Claude app, Terminal, Cursor and VS Code worked already.

## Good to know

- The forecast uses your pace over the last 45 minutes. With less than 10 minutes to go on, it uses the average since the window started.
- kitty only takes the jump when its remote control is switched on. Ghostty and Warp have no way to ask for a tab, so they still just come to the front.
- From 0.2 or 0.3, click **Update** in the notch or in Settings > General. From 0.1 or 0.1.1, download this version by hand once.
- This copy isn't signed with a Developer ID, so macOS asks again for Keychain access after an update. Click **Allow usage** in the notch and choose "Always Allow".
