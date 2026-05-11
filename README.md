# Live Discord Notifications

> by Shad3ious

![License: MIT + Commons Clause](https://img.shields.io/badge/license-MIT%20%2B%20Commons%20Clause-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE)
![Platform](https://img.shields.io/badge/platform-Windows-0078D6)

A Stream Deck friendly PowerShell tool that sends "going live" notifications to one or many Discord servers via webhooks. Random or custom messages, optional role pings, DPAPI-encrypted config.


## Why

If you stream on Twitch, YouTube, Kick, and TikTok at the same time, you probably announce your stream in a few different Discord servers. Doing it by hand every time you go live is annoying. Discord bots feel like overkill for a personal setup, and most of them want a bot token plus a hosted process running 24/7.

This is a small PowerShell tool that runs from a Stream Deck button. One press and every server you configured gets a notification with your stream links and an optional role ping. No bot, no hosting, no token. Just webhooks.

## Features

- **Multi-server support.** Configure as many Discord servers as you want. Each can have its own role ping or none at all.
- **Two send modes:**
  - `LiveDiscordNotifications.ps1` - Silent. Sends a random CSV message to every configured server. No popup.
  - `LiveDiscordNotificationsCustom.ps1` - Popup UI. Type a custom message, toggle the random CSV message on/off, pick which servers to send to per-press.
- **Channel management UI.** Add, edit, delete, and test channels through a WPF interface. No editing config files by hand.
- **Test send.** Verify a webhook works before saving it. Optional role ping toggle for tests (off by default).
- **DPAPI encryption.** Webhook URLs are encrypted at rest, tied to your Windows user account.
- **Atomic file writes.** Config saves cannot corrupt mid-write.
- **Validation.** Webhook URL format check, role ID format check, duplicate name prevention.
- **Keyboard shortcuts.** Ctrl+Enter to send, Esc to cancel.
- **Stream Deck friendly.** Launches from a Stream Deck button via a .bat or .lnk wrapper.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1 (preinstalled on Windows 10 and 11) or PowerShell 7+
- A Discord server where you can create webhooks
- (Recommended) A Stream Deck for one-press notifications

## Installation

1. Download or clone this repository.
2. Copy the following files to a folder of your choice (example: `C:\Scripts\LiveDiscordNotifications\`):
   - `_lib.ps1`
   - `LiveDiscordNotifications.ps1`
   - `LiveDiscordNotificationsCustom.ps1`
   - `LiveDiscordNotifications.bat`
   - `LiveDiscordNotificationsCustom.bat`
   - `Actionable_Stream_Notification_Messages.csv`
3. Open `LiveDiscordNotifications.ps1` and `LiveDiscordNotificationsCustom.ps1` in a text editor. Near the top, you'll find a `$linksBlock` section with `YOUR_USERNAME` placeholders. Replace each `YOUR_USERNAME` with your actual handle on that platform (Twitch, YouTube, Kick, TikTok, or whatever platforms you use). Remove any lines for platforms you don't use. Save.

## First-run setup

1. Open PowerShell and navigate to the install folder, e.g.:
   ```
   cd C:\Scripts\LiveDiscordNotifications
   ```
2. Run the customizable popup version:
   ```
   .\LiveDiscordNotificationsCustom.ps1
   ```
3. If you get an execution policy error, unblock the scripts once:
   ```
   Unblock-File .\_lib.ps1
   Unblock-File .\LiveDiscordNotifications.ps1
   Unblock-File .\LiveDiscordNotificationsCustom.ps1
   ```
   Or always launch with:
   ```
   powershell.exe -ExecutionPolicy Bypass -File .\LiveDiscordNotificationsCustom.ps1
   ```
   (The included .bat files already do this for you.)

4. The popup opens with no channels configured. Click `Channels` to open the management window.
5. For each Discord server you want to post to:
   - In Discord, go to **Server Settings -> Integrations -> Webhooks -> New Webhook**. Pick the channel where notifications should post and copy the webhook URL.
   - (Optional) To get a role ID, enable Developer Mode in Discord (**User Settings -> Advanced -> Developer Mode ON**), then right-click the role and choose **Copy Role ID**.
   - In the Channels window, fill in:
     - **Discord Server Name** - a friendly label, just for your reference
     - **Webhook URL** - paste the URL from Discord
     - **Role ID** - paste the role ID, or leave blank for no ping
   - Click `Test` first (with or without the "With role ping" checkbox) to verify the webhook works.
   - If the test succeeds, click `Add Channel`.
6. Repeat for each server. Click `Back` when done.
7. Your channels now appear with checkboxes on the main popup. Type a custom message (optional), toggle the CSV randomizer, pick which servers to send to, and click `Go Live!`.

## Stream Deck setup

The Stream Deck app has a known issue launching `.bat` files directly through its "Open" action - the button sometimes does nothing. The workaround is a Windows shortcut.

1. In File Explorer, right-click `LiveDiscordNotificationsCustom.bat` (or `LiveDiscordNotifications.bat`) and choose **Create shortcut**. You'll get a `.lnk` file in the same folder.
2. In the Stream Deck app, drag a **System -> Open** action onto a button.
3. Set the **App / File** field to the `.lnk` you just created.
4. Give the button a title (e.g., `GO LIVE`) and an icon.
5. Press the button to test.

## Editing the message pool

`Actionable_Stream_Notification_Messages.csv` is a single-column CSV with one message per line. The first line is the header `Message`. Add, remove, or rewrite messages to fit your stream's tone.

Lines that contain commas or quotes should be wrapped in double quotes:

```csv
Message
The stream is live. Come say hi.
"I have no idea what I am doing today, but I am doing it LIVE."
"Fueled by panic and overconfidence - going live now."
```

The script picks one message at random per send.

## Security

- Webhook URLs are sensitive. Anyone holding one can post anything to that channel with no authentication. Don't share them, don't commit them, don't paste them in screenshots.
- This tool encrypts webhook URLs on disk using Windows DPAPI (Data Protection API), scoped to your current Windows user account. The encrypted blob lives in `channels.json` in a field named `WebhookUrlProtected`.
- The `.gitignore` in this repo excludes `channels.json` so you cannot accidentally commit your real config.
- Because DPAPI keys are tied to your Windows user, the encrypted file is not portable. If you migrate to a new PC, do a fresh Windows install, or reset your Windows password under certain conditions, the encrypted webhooks become undecryptable. Corrupted entries get flagged in the UI - re-add them through the Channels window.
- Keep a separate backup of your webhook URLs (a password manager works well) in case you need to restore them.

## Files in this repository

| File | Purpose |
|------|---------|
| `_lib.ps1` | Shared helpers (encryption, config I/O, Discord send). Dot-sourced by the other scripts. Do not run directly. |
| `LiveDiscordNotifications.ps1` | Silent sender. Posts a random CSV message to all configured channels. |
| `LiveDiscordNotificationsCustom.ps1` | Main UI. Custom message, per-press channel selection, channel management. |
| `LiveDiscordNotifications.bat` | Batch wrapper for `LiveDiscordNotifications.ps1`. Use this (or a shortcut to it) as your Stream Deck target. |
| `LiveDiscordNotificationsCustom.bat` | Batch wrapper for `LiveDiscordNotificationsCustom.ps1`. |
| `Actionable_Stream_Notification_Messages.csv` | Random message pool. Edit to taste. |
| `channels.example.json` | Reference for the config file structure. The real `channels.json` is created automatically and is gitignored. |
| `LICENSE` | MIT + Commons Clause. |

## Troubleshooting

**"Cannot be loaded because running scripts is disabled on this system"**
PowerShell execution policy is blocking. Run `Unblock-File` on the three .ps1 files, or always launch via the included .bat files (they pass `-ExecutionPolicy Bypass`).

**Stream Deck button does nothing**
This is a known Stream Deck quirk with .bat files. Use a `.lnk` shortcut instead - right-click the .bat, choose Create Shortcut, and point Stream Deck at the .lnk.

**"Could not decrypt webhook for ..." warning on startup**
The encrypted webhook URL in `channels.json` cannot be read on this machine or user account. This usually means the file was created on a different Windows user or copied from another PC. Open `LiveDiscordNotificationsCustom.ps1`, click `Channels`, delete the broken entry, and re-add it.

**Test send fails with `401 Unauthorized` or similar**
The webhook URL is wrong, was deleted in Discord, or was regenerated. Recreate the webhook in Discord and paste the new URL.

**Message looks weird in Discord (smart quotes, weird characters)**
Make sure your CSV is saved as UTF-8 (not "ANSI" or "Windows-1252"). Most modern editors default to UTF-8.

## License

[MIT + Commons Clause](LICENSE). You may use, modify, and redistribute freely for non-commercial purposes. You may not sell this software or sell a service that derives substantially from its functionality.

## Author

Built by **Shad3ious**. If this saves you time on stream, come say hi:

- Twitch: https://www.twitch.tv/shad3ious
- YouTube: https://www.youtube.com/@shad3ious
- Kick: https://kick.com/shad3ious
- TikTok: https://www.tiktok.com/@shad3ious
