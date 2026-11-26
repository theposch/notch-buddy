# Notch Buddy 0.2

Fewer false alarms, clearer accounts, and updates with one click.

## New

- **One-click updates.** When a newer version is out, an **Update** button appears in the notch and in Settings. One click downloads it from this Releases page, checks it, installs it and restarts. Nothing is downloaded until you click. (This is the last version you download by hand.)
- **"Usage needs your OK".** When macOS wants your permission before Notch Buddy can read a login, the notch now says so, with an **Allow** button, instead of showing no usage at all.
- **Accounts show their email.** Each account shows the email address it's logged in with, in Settings and when you hover over it. Emails stay on your Mac.
- **Rename accounts with a pencil.** Click the pencil next to an account's name in Settings to call it what you like.

## Fixed

- **Idle sessions no longer fill the list.** The Claude desktop app reopens your past conversations when it starts; each one used to show up as "Ready". Now a session gets a row when it does something.
- **"Hide right away" hides every idle session**, not only one that just finished. Hidden sessions keep their colour and their work totals when they come back.
- **No more false "Needs you".** A finished session could pop back a minute later as "Needs you", with a sound. Notices like "signed in" did the same. Only real requests do now.
- **Allow and Deny stay put.** When Claude did several things at once, any of them finishing could take away a request that was still waiting for you.
- **Account names stay true.** An account was named after where it was first seen ("Terminal"), even after you logged in somewhere else, so a desktop session could say "Terminal". Names now follow where each account is logged in. Accounts you've switched away from go away.
- **Lighter on your Mac.** Less work on every mouse move.

## Good to know

- This copy isn't signed with a Developer ID, so macOS asks again for Keychain access after each update. The new **Allow** button in the notch is for exactly that: click it and choose "Always Allow".
- From 0.1 or 0.1.1, download this version by hand once. After that, the Update button does it.
