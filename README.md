# Notch Buddy

A little helper that lives in your Mac's notch and keeps an eye on Claude Code for you.

- **See every session at a glance.** Open the notch to see what each Claude Code session is doing, which ones are done, and which ones need you.
- **Answer without switching windows.** Allow or deny a step right from the notch, or jump straight to the conversation.
- **Know your limits.** Usage left in your 5-hour and weekly limits, for one Claude account or several.
- **Hear about what matters.** Short messages on the closed notch ("Tests failed", "Plan ready", "Back at 7:00 PM"), and you choose which ones.
- **Clawd keeps you company.** Clawd works when Claude works, cheers when tests pass, and naps when your usage runs out.

Works on any Mac with macOS 14 or later. On a MacBook it sits around the camera; on other screens it shows a smaller notch at the top.

## Install

1. Download the latest `Notch-Buddy-<version>.zip` from Releases.
2. Unzip it and move **Notch Buddy** to your Applications folder.
3. Open it and click **Connect to Claude Code**. This adds Notch Buddy to Claude Code's settings file (`~/.claude/settings.json`) so Claude Code tells it what's happening. A backup of your settings is kept, and **Disconnect** in Settings puts them back.

## What it reads, and where it goes

Notch Buddy runs on your Mac only. It has no account, no analytics and no server of its own.

- **Claude Code events** come from Claude Code itself, through a small helper Notch Buddy adds to Claude Code's settings. They stay on your Mac.
- **Usage** comes from Claude Code's status line while it runs in the Terminal.
- **Usage without the Terminal** is off until you switch it on in Settings > Usage and accounts. It reads a login already on your Mac (Claude Code's, or the Claude desktop app's) and asks Anthropic for your usage, the same way other usage apps do. macOS asks your permission first. The login is kept in memory only and is only ever sent to Anthropic. This isn't an official Anthropic feature, so it may stop working; the status line stays as a backup.
- **Updates**: once a day it checks this project's Releases page for a newer version, and only tells you. It never downloads anything by itself.

## Build it yourself

You need Xcode's command line tools (Swift 6).

```bash
swift test
```

```bash
scripts/run.sh
```

`scripts/run.sh` builds the app, signs it for this Mac and restarts it. `scripts/release.sh <version>` makes a release zip in `dist/`; the comments at the top of the script explain the optional signing, Apple check and upload steps.

Notch Buddy is not made by or affiliated with Anthropic. Claude and Claude Code are Anthropic's.

Released under the MIT License (see LICENSE).
