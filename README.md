<div align="center">

<img src="assets/logo.png" alt="LocalBridge logo" width="120" />

# LocalBridge

**Send files between your devices over the same Wi-Fi.**
No cloud. No account. No cables.

[![Latest release](https://img.shields.io/github/v/release/unqale/LocalBridge?style=for-the-badge&color=7C3AED)](https://github.com/unqale/LocalBridge/releases/latest)
![Platforms](https://img.shields.io/badge/platform-Windows%20%7C%20Android-7C3AED?style=for-the-badge)
[![License](https://img.shields.io/github/license/unqale/LocalBridge?style=for-the-badge)](LICENSE)
![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)

[**Download**](https://github.com/unqale/LocalBridge/releases/latest) · [How to use](#how-to-use) · [Build from source](#build-from-source) · [Troubleshooting](#troubleshooting)

</div>

---

## Why LocalBridge?

Moving a file from your phone to your PC (or the other way around) should not need a cable, a messaging app or an upload to someone else's server. LocalBridge talks directly between your devices on your own network, so transfers are fast and your files never leave your Wi-Fi.

## Features

**Send and receive**
- Nearby devices appear on a live **radar**. Tap one, pick files, done.
- The receiver always gets an **accept / decline** prompt, unless you turn on auto-accept.
- **Trusted devices** (tap the star) can send without asking.
- Receive limits: trusted-devices-only mode, incoming size limit, group files by sender, open the folder after receiving.

**Share with a link**
- Anyone on your Wi-Fi can download files from a **browser**, no app needed.
- Optional **PIN**, wrong-PIN lockout, **one-time download**, download limit, file type filter, auto-stop timer.
- Custom message on the download page, QR code, copy link automatically.

**Everything else**
- Transfer **history** with sent / received totals and filters.
- Smart, fast network scanning with a **Scan speed** setting (Balanced, Fast, Turbo). VPN and virtual adapters are skipped by default.
- A **power button** to switch LocalBridge off: it stops scanning and becomes invisible to other devices.
- **English, Türkçe and Русский**.
- Dark interface with 11 accent colors, hover effects, a side menu on big windows and a bottom bar on phones.

<!--
## Screenshots

Add your screenshots to a docs/screenshots folder and uncomment these lines:

| Devices | History | Settings |
| --- | --- | --- |
| ![Devices](docs/screenshots/devices.png) | ![History](docs/screenshots/history.png) | ![Settings](docs/screenshots/settings.png) |
-->

## Download

Get the latest version from the [**Releases**](https://github.com/unqale/LocalBridge/releases/latest) page.

| Platform | File | Notes |
| --- | --- | --- |
| Android (most phones) | `LocalBridge-...-android-arm64-v8a.apk` | Allow installing from unknown sources if asked |
| Android (older phones) | `LocalBridge-...-android-armeabi-v7a.apk` | 32-bit devices |
| Android (emulator / x86) | `LocalBridge-...-android-x86_64.apk` | |
| Windows 10 / 11 | `LocalBridge-...-windows.zip` | Extract the **whole** zip, then run `LocalBridge.exe` |

If Windows SmartScreen warns you, choose **More info → Run anyway**. If Windows Firewall asks, allow **Private networks**.

## How to use

1. Install and open LocalBridge on **both** devices, connected to the **same Wi-Fi**.
2. The other device shows up under **Nearby devices** (and on the radar).
3. Tap it, choose your files, and accept the request on the other device.

Files are saved to `Downloads/LocalBridge` by default. You can change the folder in **Settings → Receive**.

**No app on the other device?** Use **Share via link**. Pick files, then open the link (or scan the QR code) in any browser on the same Wi-Fi.

## How it works

Each device runs a tiny web server on your local network (default port `53317`). LocalBridge finds other devices by checking the addresses on your network for another LocalBridge. When you send a file, the sender asks the receiver for permission, and only after it is accepted the file is streamed directly to it. Nothing goes through the internet.

## Troubleshooting

**Devices do not see each other**
- Both devices must be on the same Wi-Fi network (not mobile data).
- On Windows, allow LocalBridge through the firewall on **Private networks**.
- Guest Wi-Fi and some public or hotel networks block device-to-device traffic.
- Both devices must use the same port (**Settings → Network → Port**).
- If you use a VPN or virtual machines, try turning on **Scan VPN and virtual networks**.
- Check that the power button in the top right says **Active**, and that **Visible to other devices** is on.

**Transfer is slow**
- Use a 5 GHz Wi-Fi network and stay close to the router.

## Known limitations

- Transfers use plain **HTTP**, not encrypted. Only use LocalBridge on networks you trust.
- The QR code image is created by an online service, so it needs internet. The link itself works without internet.
- On Android, keep the app open while receiving files.
- Android APKs are signed with a test key. When updating to a new version, uninstall the old one first if Android refuses to install.

## Build from source

You need [Flutter](https://docs.flutter.dev/get-started/install).

```bash
git clone https://github.com/unqale/LocalBridge.git
cd LocalBridge
flutter pub get

flutter run -d windows            # or: flutter run -d <android-device>

flutter build windows --release
flutter build apk --release --split-per-abi
```

Pushing a tag such as `v2.1.0` builds the Windows and Android files on GitHub and publishes them as a release.

## Roadmap

LocalBridge 2.1.0 is the last big update. From now on it will mostly get fixes and improvements. Support for more platforms such as macOS, Linux and iOS may come later.

## License

Released under the [MIT License](LICENSE).

Made by [unqale](https://github.com/unqale).
