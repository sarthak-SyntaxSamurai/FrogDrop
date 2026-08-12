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
  <a href="https://github.com/sponsors/sarthak-SyntaxSamurai">
  <img src="https://img.shields.io/badge/GitHub%20Sponsors-♥%20Sponsor-EA4AAA?style=for-the-badge&logo=github-sponsors&logoColor=white" alt="GitHub Sponsors"></a>
</p>

---

## 👀 Preview

<p align="center">
  <img src="https://raw.githubusercontent.com/sarthak-SyntaxSamurai/FrogDrop/main/media/collage.png" alt="FrogDrop — Clipboard, Timer, Dropzone" width="100%">
</p>

<p align="center">
  📸 <a href="https://github.com/sarthak-SyntaxSamurai/FrogDrop/tree/main/media">For more previews, go to media →</a>
</p>

---

## Why I built this

My menu bar already had **Clipboard manager, Dropzone, focus timer, and a file shelf** — four separate apps, four icons, four subscriptions.

I wanted one thing that does all of it, stays out of the way, and doesn't cost $10/month. So I built FrogDrop — a single animated frog that replaces all four.

**One icon. No clutter. No subscriptions.**

---

## What it does

### 🐸 The Menu Bar Frog
A hand-drawn frog lives in your menu bar. It **blinks**, **winks**, and **changes expression** based on what you're doing — relaxed when idle, focused brows when a timer's running, pink tongue out when something drops in. It's alive.

### 📦 Dropzone & Floating Shelf — Drag files anywhere, transform instantly

Shake your cursor while dragging files to summon a floating shelf, or drop files directly onto the menu bar frog.

- **🔍 Spacebar QuickLook** — Hover any card in the shelf or grid and press `Spacebar` (or tap the eye icon) for instant full-size native macOS previews.
- **👁️ On-Device Vision OCR** — Drag any screenshot, photo, or receipt → 1-click extract formatted text directly to your clipboard.
- **⚡ Modern WebP & Lossless Optimizer** — 1-click convert JPG/PNG to WebP, shrink file sizes by 70%, or strip GPS/EXIF metadata for privacy.
- **📄 PDF Toolkit** — Drop multiple PDFs or images to merge them into a single PDF document in seconds.
- **🎨 1-Click Screen Eyedropper** — Sample any pixel on screen and instantly copy formatted `#HEX` / `RGB` color codes.
- **Custom folder grid** — Add your most-used folders, move files in one drag with duplicate collision protection.
- **Built-in sharing** — AirDrop, Email, Imgur upload, URL shortener, Zip archives.
- **Fallback dialogs** — Clicking any action when no file is shelved opens a native file picker.
- Works with single files, bulk selections, anything Finder can drag.

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

## 🤔 Is this a virus?

Totally fair question. macOS shows a security warning on any app that isn't paid-notarized by Apple ($99/yr). FrogDrop is free and open-source, so it triggers that warning.

**You can verify it yourself in 30 seconds:**

> Copy this repo link → paste it into ChatGPT, Gemini, or any AI → ask *"Is this a legit open-source app or a virus?"*
> 
> 🔗 `https://github.com/sarthak-SyntaxSamurai/FrogDrop`

Every line of code is public. The app makes zero network calls on its own. Use Homebrew to install — it clears the warning automatically.

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

> **Why the warning?** Apple charges $99/yr for app notarization. FrogDrop is free. Use Homebrew instead — it handles this automatically.

---

## Build from source

```bash
git clone https://github.com/sarthak-SyntaxSamurai/FrogDrop.git
cd FrogDrop
swift build -c release
```

Requires Xcode Command Line Tools and macOS 14+.

---

## 💬 Feedback & Ideas

Found a bug? Have a feature idea? Just want to say hi?

**[Open an Issue](https://github.com/sarthak-SyntaxSamurai/FrogDrop/issues)** — all feedback welcome. If something feels off, broken, or annoying, I genuinely want to know. And if you have an idea, there's a good chance it'll end up in the app.

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

## 💖 Support FrogDrop

FrogDrop is proudly **100% free, open-source, and strictly local** (no tracking, no hidden network calls). Building and maintaining native macOS apps takes significant time. 

If FrogDrop helps your daily workflow, consider dropping a small tip to keep the updates coming:

<a href="https://github.com/sponsors/sarthak-SyntaxSamurai">
  <img src="https://img.shields.io/badge/Sponsor-💖-FF69B4?style=for-the-badge&logo=githubsponsors&logoColor=white" alt="GitHub Sponsors">
</a>

No pressure. A ⭐ star on this repo means just as much.

---

MIT License · Made with 🐸 by [@sarthak-SyntaxSamurai](https://github.com/sarthak-SyntaxSamurai)
