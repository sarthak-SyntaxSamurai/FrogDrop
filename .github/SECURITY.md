# Security Policy

## Supported Versions

We provide security updates and patches for the following versions of **FrogDrop**:

| Version | Supported          | macOS Compatibility |
| ------- | ------------------ | ------------------- |
| 2.2.x   | :white_check_mark: | macOS 14.0+ (Sonoma, Sequoia, 26+) |
| 2.1.x   | :white_check_mark: | macOS 14.0+         |
| < 2.0   | :x:                | Deprecated          |

---

## Reporting a Vulnerability

The FrogDrop team takes the security and privacy of our users very seriously. If you discover a security vulnerability, please report it responsibly:

1. **Private Reporting**: Please do **NOT** open a public issue on GitHub.
2. **Email**: Send detailed information to:
   **[sarthaksyntax@gmail.com](mailto:sarthaksyntax@gmail.com)**
3. **GitHub Security Advisory**: You can also use the [GitHub Security Advisory Private Vulnerability Reporting](https://github.com/sarthak-SyntaxSamurai/FrogDrop/security/advisories/new) tool.

### What to Include in Your Report
* Description of the vulnerability and its potential impact.
* Step-by-step reproduction instructions or a minimal proof-of-concept.
* macOS version and hardware architecture (Apple Silicon / Intel).

### Response Timeline
* **Initial Acknowledgment**: Within **24 to 48 hours**.
* **Triage & Status Assessment**: Within **5 business days**.
* **Public Fix & Disclosure**: Coordinated patch released via GitHub Releases and Homebrew.

---

## Security & Privacy Architecture

FrogDrop is architected with a strict **local-first, zero-telemetry** philosophy:

1. **100% Offline Processing**:
   * OCR text recognition is performed entirely on-device using Apple's Vision Framework (`VNRecognizeTextRequest`). No screenshots or text are ever uploaded to cloud servers.
   * Procedural ambient audio is generated locally using `AVAudioEngine` without streaming external media.
2. **Local Storage**:
   * Clipboard history and app preferences are stored exclusively on your local machine at:
     `~/Library/Application Support/FrogDrop/`
3. **Password & Sensitive App Protection**:
   * FrogDrop includes built-in exclusion rules that automatically ignore or temporarily auto-purge clipboard items from password managers (such as 1Password, Bitwarden, KeePassXC, and Apple Keychain).
4. **Network Access**:
   * Network calls are only initiated upon explicit user action (e.g. manual update checks, uploading to Imgur, or shortening a URL).

---

## Installer & Binary Verification

* **Homebrew Cask (Recommended)**:
  `brew tap sarthak-SyntaxSamurai/tap && brew install --cask frogdrop`
  Homebrew installations pull directly from verified GitHub releases.
* **Installer Script (`install.sh`)**:
  FrogDrop's optional convenience script runs entirely with standard user privileges (`$HOME` / `/Applications`) and **never requests `sudo` or root permissions**. Users can inspect `install.sh` directly before execution.
* **Checksum Verification**:
  Official release DMGs and ZIP archives include SHA256 hashes published on the [Releases](https://github.com/sarthak-SyntaxSamurai/FrogDrop/releases) page for independent verification.
