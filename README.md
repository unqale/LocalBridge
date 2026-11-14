<div align="center">

<img src="assets/brand/logo.png" width="96" height="96" alt="LocalBridge Logo" />

# LocalBridge

**Direct file sharing and chat over your local network for Windows and Android.**

[![Release](https://img.shields.io/github/v/release/unqale/localbridge?style=for-the-badge)](https://github.com/unqale/localbridge/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/unqale/localbridge/total?style=for-the-badge)](https://github.com/unqale/localbridge/releases)
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)

[Download](#download) | [Features](#key-capabilities) | [Quick start](#quick-start) | [Build & test](#build-from-source) | [Security](#security--reliability)

</div>

---

## What is LocalBridge?

LocalBridge discovers nearby devices, transfers files directly and lets approved peers exchange messages in Bridge Chat. Share via Link lets someone on the same network download files in a browser without installing the app. Local features work without an account, cloud storage or an internet connection.

> [!IMPORTANT]
> **3.0.6 Beta** is a Windows and Android preview for local-network use. Internet connections are experimental. This release does not include a hosted relay, public Desk Code lookup or remote desktop control. Linux desktop support is unverified and there is no Linux download.

## Download

Use [GitHub Releases](https://github.com/unqale/LocalBridge/releases) and select **LocalBridge 3.0.6 Beta**. The **Latest** badge identifies the stable release.

| Platform | Beta download |
| --- | --- |
| Windows x64 | `LocalBridge-v3.0.6-beta-windows.zip` |
| Android ARM64 | `LocalBridge-v3.0.6-beta-android-arm64-v8a.apk` |
| Android ARMv7 | `LocalBridge-v3.0.6-beta-android-armeabi-v7a.apk` |
| Android x86-64 | `LocalBridge-v3.0.6-beta-android-x86_64.apk` |
| Android universal | `LocalBridge-v3.0.6-beta-android-universal.apk` |

On Windows, extract the ZIP and run `LocalBridge.exe` from the extracted folder alongside its DLLs and `data` directory. On Android, pick ARM64 for a compatible phone or use the universal APK if you are unsure. The beta APKs use a debug signing certificate. Android requires the same signing certificate for an in-place upgrade.

## Quick start

1. Open LocalBridge on both devices and connect them to the same local network.
2. Pick a device in **Devices**. Select **Send** to stage files or **Bridge Chat** to open a conversation. The receiving device can approve incoming transfers and chat connections.
3. To share with a browser, use **Share via Link** and open the link or QR code on the same network.
4. If discovery fails, check that both devices use the same app port (default `53317`), allow LocalBridge through the Windows firewall for private networks, and check whether the router isolates Wi-Fi clients.

## Key Capabilities

- **Windows sidebar and radar**: Top-aligned navigation, compact network controls, live scan state and device actions. Known devices are probed first.
- **Cross-Platform File Staging Flow (Windows & Android)**:
  - **Windows Native Drag-and-Drop**: Drag files or folders directly from Windows Explorer into the LocalBridge window (`WM_DROPFILES`) or pick via the native file dialog.
  - **Android Native Picker + Bottom Sheet Staging**: Uses the native Android system file picker and opens a dedicated staging view before any network transfer begins.
  - **Pre-Transfer Inspection**: Review target device, file names, categorized file badges, individual sizes, lightweight image thumbnails (capped at ≤ 25 MB with `ResizeImage`), remove single items, add more files, or clear the queue before pressing **Send**.
  - **Transfer recovery**: Cancel an active send or retry after a failure. The queue retains files whose delivery has not been acknowledged.
- **Validated incoming files**:
  - Incoming uploads stream to temporary `.lbpart` files first.
  - Verifies the exact byte length and checks the optional FNV-1a checksum when supplied. Then renames the temporary file to the final destination.
  - The upload session is tied to the sender and prevents concurrent or repeated use of a file index. Incomplete uploads leave existing files intact and attempt to remove their temporary files.
- **Offline On-Device QR Code Generation**:
  - Link sharing (`Share via Link`) generates QR codes locally on-device using `qr_flutter` (`QrImageView`). Works completely offline without sending local network URLs to third-party QR servers.
- **Trusted devices and chat**: Automatic acceptance for a trusted peer requires an approved connection. A legacy name-only trust entry needs to be marked again. Chat also requires an approved connection. LAN traffic uses plain HTTP and the connection token does not provide cryptographic device identity.
- **Searchable Transfer History**:
  - Filter by `All`, `Sent`, or `Received`, search by file name or peer name, inspect transfer status (`Completed`, `Failed`, `Cancelled`), and reveal saved files directly in the system folder with missing-file detection.
- **6-Language Localization**:
  - Available in **English**, **Turkish**, **Russian**, **German**, **Spanish**, and **French**. Some diagnostics and browser download text remain in English.

## Architecture

```text
lib/
├── main.dart                          # Core app shell, HTTP transfer engine, radar, pages & settings
├── localization/
│   └── extra_strings.dart             # Additional localization strings in six languages
├── models/
│   └── file_staging.dart              # Testable FileStagingController & StagedFileItem model
└── widgets/
    └── file_staging_view.dart         # Responsive Desktop Dialog & Mobile Bottom Sheet staging UI

windows/runner/
└── flutter_window.cpp                 # Win32 custom frame, DPI scaling & WM_DROPFILES drag-and-drop

android/
├── settings.gradle.kts                # AGP 9.1.1 & Kotlin 2.4.10 toolchain configuration
└── app/build.gradle.kts               # Android release & ABI split build configuration

test/
├── widget_test.dart                   # Core layout, radar, localization & navigation widget tests
├── desk_connection_test.dart          # End-to-end Desk Code consent, chat & file transfer tests
└── overhaul_quality_test.dart         # Staging, atomic upload integrity, anti-spoofing & QR tests
```

## Build from Source

**Requirements:** Flutter SDK (3.50+ / Dart 3.13+)

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Static analysis & automated test suite
flutter analyze
flutter test

# 3. Windows Release build
flutter build windows --release

# 4. Android Release APK build (split per ABI)
flutter build apk --release --split-per-abi
```

### Experimental Linux test

The repository includes a manual GitHub Actions workflow named **Experimental Linux smoke test**. It runs Flutter analysis and tests on Ubuntu, generates a Linux desktop runner in the job workspace, builds it and attempts a short launch under Xvfb. It publishes a launch log for inspection. Real desktop use and discovery between physical devices require additional testing.

## Security & Reliability

- **Explicit consent**: Incoming connections require approval. File reception follows the configured approval, auto-accept and trusted-device settings.
- **Browser sharing**: PINs are submitted in the request body. Approval is per browser session and download slots count transfers already in progress.
- **Local Network Privacy**: Link sharing stays on your local network interfaces (`192.168.x.x`, `10.x.x.x`, `172.16-31.x.x`, or Carrier-Grade NAT/VPN `100.64-127.x.x`), with optional PIN protection, attempt limits, extension filters, and auto-expiry timers.
- **Android signing**: Local test APKs use the debug certificate by default. To use a release certificate, supply `LOCALBRIDGE_KEYSTORE`, `LOCALBRIDGE_STORE_PASSWORD`, `LOCALBRIDGE_KEY_ALIAS` and `LOCALBRIDGE_KEY_PASSWORD` in the build environment. The release certificate must match the one used on devices that will receive an in-place update.

## Credits & License

- Created by [unqale](https://github.com/unqale)
- Contributor: [eratis-hq](https://github.com/eratis-hq)
- License: [MIT](LICENSE)
