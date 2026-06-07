**EyeBreak** — a lightweight macOS menu-bar app that reminds you to rest your eyes on a schedule (default every 30 minutes) with a cute full-screen break overlay, to help prevent digital eye strain.

## ⬇️ Download
**EyeBreak-__VERSION__.dmg** (attached below) — universal binary (Apple Silicon **arm64** + Intel **x86_64**), macOS 13+.

## Install
1. Open the `.dmg` and drag **EyeBreak** onto **Applications**.
2. Launch EyeBreak from Applications.

> ⚠️ **First launch (Gatekeeper):** EyeBreak is ad-hoc signed (no paid Apple Developer ID / notarization), so macOS blocks it the first time. To open it anyway:
> ```bash
> xattr -dr com.apple.quarantine /Applications/EyeBreak.app
> ```
> …or open it once, then go to **System Settings → Privacy & Security → Open Anyway**.

## Usage
Click the 👁 menu-bar icon: Take Break Now, Snooze 5 min, Pause, Interval, Break length, Sound, Open at Login. During a break, click **Skip** or press **Esc**.

## Verify your download
```
shasum -a 256 EyeBreak-__VERSION__.dmg
# __SHA256__
```
