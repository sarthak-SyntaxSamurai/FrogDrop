# 🐸 FrogDrop

<p align="center">
  <img src="https://raw.githubusercontent.com/sarthak-SyntaxSamurai/FrogDrop/main/AppIcon.png" width="120" height="120" alt="FrogDrop">
</p>

<p align="center">
  <strong>A tiny frog in your Menu Bar. A powerful productivity layer on your Mac.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-black?style=flat-square&logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT">
  <img src="https://img.shields.io/badge/Price-Free-brightgreen?style=flat-square" alt="Free">
  <a href="https://www.buymeacoffee.com/sarthakanand"><img src="https://img.shields.io/badge/☕-Buy%20me%20a%20coffee-FFDD00?style=flat-square" alt="Donate"></a>
</p>

---

FrogDrop is a **zero-bloat macOS Menu Bar app** that quietly handles three things you do every day — file dragging, clipboard history, and focus timing — all from a single animated frog icon. No subscriptions, no accounts, no cloud sync. Just open it and it works.

---

## What it does

### 🐸 The Menu Bar Frog
A hand-drawn pixel frog lives in your menu bar. It **blinks**, **winks**, and **changes expression** based on what you're doing — relaxed when idle, focused brows when a timer's running, pink tongue out when something drops in. It's alive.

### 📦 Dropzone — Drag files anywhere, instantly

Drag any file (or 100 files) onto the frog and it gets **shelved**. A smart grid pops up with your custom target folders and quick actions.

- **Custom folder grid** — add your most-used folders, move files in one drag
- **Built-in actions** — AirDrop, Email, Imgur upload, URL shortener
- **Fallback dialogs** — clicking any action when no file is shelved opens a native file picker
- Works with single files, bulk selections, anything Finder can drag

### 📋 Clipboard History — Everything you ever copied, right here

FrogDrop silently watches your clipboard in the background. Every text you copy appears instantly in the history panel.

- **100 items** stored locally
- **Pin items** to keep them from rotating out
- **Per-app rules** — mark apps like password managers as "ignore" or "temporary"
- **Temporary mode** — items auto-expire after a time you set
- **URL shortener** — hover any URL → click the badge → TinyURL link copied
- **Toast notifications** — a subtle popup shows what was just copied, with source app name

### ⏱️ Focus Timer — Pomodoro, stopwatch, or custom

A full-featured timer that lives in your sidebar, not in a cluttered app.

- **Pomodoro mode** — configurable cycles, focus duration, break duration
- **Stopwatch mode** — open-ended sessions
- **Custom countdowns** — set any time you want
- **Multiple simultaneous timers** — run parallel sessions
- **System notifications** — get pinged when a session ends
- **Session log** — every session is saved with name, duration, and date

### 🌸 Dashboard — Your day at a glance

A home screen that shows today's focus progress as a **blooming flower**. The flower starts as a bud and fully blooms as you hit your daily focus goal. Tap it — it bounces.

---

## Privacy

Everything is local. FrogDrop doesn't make any network requests except when you explicitly ask it to (AirDrop, Imgur, TinyURL). Your clipboard history lives at:

```
~/Library/Application Support/FrogDrop/history.json
```

It's never uploaded. It's never read by anyone else. It's just a JSON file on your Mac.

---

## Installation

### ⭐ Homebrew (Recommended — no security warning)

```bash
brew tap sarthak-SyntaxSamurai/tap
brew install --cask frogdrop
```

### One-liner installer

```bash
curl -fsSL https://raw.githubusercontent.com/sarthak-SyntaxSamurai/FrogDrop/main/install.sh | bash
```

### Manual DMG

Download from [Releases](https://github.com/sarthak-SyntaxSamurai/FrogDrop/releases) → drag to Applications → run once:

```bash
xattr -cr /Applications/FrogDrop.app
```

> **Why the security warning?** Apple charges $99/yr for app notarization. FrogDrop is free. Use Homebrew instead — it handles this automatically.

---

## Build from source

```bash
git clone https://github.com/sarthak-SyntaxSamurai/FrogDrop.git
cd FrogDrop
swift build -c release
```

Requires Xcode Command Line Tools and macOS 14+.

---

## Stack

| Layer | Tech |
|---|---|
| Language | Swift 5.9 |
| UI | SwiftUI + AppKit |
| Storage | JSON (local) + UserDefaults |
| Packaging | Swift Package Manager |
| Distribution | Homebrew Cask + DMG |

---

## Support

If FrogDrop saves you time, a coffee goes a long way:

<a href="https://www.buymeacoffee.com/sarthakanand">
  <img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-☕%20Donate-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me A Coffee">
</a>

---

MIT License · Made with 🐸 by [@sarthak-SyntaxSamurai](https://github.com/sarthak-SyntaxSamurai)
