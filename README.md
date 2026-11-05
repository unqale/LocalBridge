<div align="center">

# LocalBridge

**Send files between your phone and PC over Wi-Fi. No cloud, no cables, no accounts.**

[![Release](https://img.shields.io/github/v/release/unqale/LocalBridge?style=for-the-badge)](https://github.com/unqale/LocalBridge/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/unqale/LocalBridge/total?style=for-the-badge)](https://github.com/unqale/LocalBridge/releases)
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)

[Download](#-download) · [Features](#-features) · [How to use](#-how-to-use) · [Build from source](#-build-from-source) · [FAQ](#-troubleshooting)

</div>

<!-- Add screenshots here, e.g.
<p align="center">
  <img src="docs/screenshots/devices.png" width="260">
  <img src="docs/screenshots/history.png" width="260">
  <img src="docs/screenshots/settings.png" width="260">
</p>
-->

## What is LocalBridge?

LocalBridge finds other devices running LocalBridge on the same Wi-Fi network and lets you send files to them directly. Files travel straight from one device to the other over your local network. Nothing is uploaded to a server and you don't need an internet connection.

It also has a **Share via link** mode: pick some files, get a link, and anyone on your Wi-Fi can download them from a normal browser, even if they don't have the app.

## ✨ Features

**Sending and receiving**
- Automatic device discovery on your local network
- Send multiple files at once with a live progress bar
- The receiver gets an accept / decline prompt before anything is saved
- Trusted devices: star a device to accept its files automatically
- Auto-accept mode for networks you fully trust
- Files never overwrite each other by default (`photo.jpg`, `photo (1).jpg`, ...)

**Share via link**
- Share files with any browser on your Wi-Fi, no app needed on the other side
- Optional PIN
- Optional approval prompt for every browser that opens the link
- Auto-stop timer (5 min to 3 hours) or share until you stop it

**Interface**
- Material 3 design with an animated radar header
- Light, dark and pure black (AMOLED) themes
- 11 accent colors
- Adjustable text size, compact header, hide IP addresses
- Transfer history

**Settings**
- Device name, save folder, group received files by sender
- Overwrite behaviour, request timeout
- Scan interval, port, visibility to other devices
- History size, haptic feedback, reset to defaults

## 📥 Download

Go to the [**Releases**](https://github.com/unqale/LocalBridge/releases/latest) page and download the file for your device:

| Platform | File | Notes |
|----------|------|-------|
| Android | `LocalBridge-v1.3.0-android-arm64-v8a.apk` | Works on almost all modern phones. Use `armeabi-v7a` for older 32-bit phones. |
| Windows | `LocalBridge-v1.3.0-windows.zip` | Unzip and run `localbridge.exe`. No installer needed. |

### Installing on Android
1. Download the APK on your phone.
2. Open it. Android will ask you to allow installing apps from your browser or file manager. Allow it for this install.
3. Open LocalBridge.

### Installing on Windows
1. Unzip the folder anywhere (keep all the files together).
2. Run the `.exe`.
3. If **Windows Defender SmartScreen** shows a warning, click **More info → Run anyway**. The app isn't code-signed.
4. When **Windows Firewall** asks, allow access on **Private networks**. Without this, other devices can't reach your PC.

## 🚀 How to use

### Send files to another device
1. Open LocalBridge on both devices and connect them to the **same Wi-Fi**.
2. The other device appears under **Nearby devices** within a few seconds.
3. Tap **Send** and choose your files.
4. The other device taps **Accept**. The transfer starts.

### Share files with a link
1. On the **Devices** tab, tap **Share** on the *Share via link* card and choose your files.
2. Copy the link and open it in any browser on the same Wi-Fi.
3. If approval is on, accept the request that pops up in LocalBridge.
4. Tap **Stop sharing** when you're done.

### Where do received files go?
- **Windows:** your Downloads folder, in a `LocalBridge` subfolder
- **Android:** `Download/LocalBridge`, or the app's own folder if Android doesn't allow writing there

You can change the folder in **Settings → Receive → Save folder**.

## 🛠 Build from source

You only need this if you want to modify the app. Regular users should use the [downloads](#-download) above.

**Requirements:** [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)

```bash
git clone https://github.com/unqale/localbridge.git
cd localbridge
flutter pub get
flutter run
```

Build release versions:

```bash
flutter build apk --release --split-per-abi   # Android
flutter build windows --release               # Windows
```

### Automatic releases
Pushing a version tag builds the Android APKs and the Windows zip on GitHub Actions and attaches them to a new release:

```bash
git tag v1.3.0
git push origin v1.3.0
```

## 🔧 Troubleshooting

**The other device doesn't show up**
- Both devices must be on the same Wi-Fi network.
- Some routers have *AP isolation* / *client isolation* turned on, which blocks devices from talking to each other. Turn it off in your router settings, or try a phone hotspot.
- On Windows, allow LocalBridge through the firewall on **Private networks**.
- Make sure *Settings → Network → Visible to other devices* is on.
- The **port** must be the same on both devices (default `53317`).

**"Could not start server" message**
Another app is using the port. We uses the same default port (`53317`), so close it or change the port in **Settings → Network → Port** on both devices.

**Android says it can't save to Download**
Newer Android versions restrict writing to shared folders. LocalBridge then falls back to its own app folder. You can set another path under *Settings → Receive → Save folder*.

**A shared link doesn't open**
The link only works on the same local network and only while sharing is on. It stops when you tap *Stop sharing*, when the auto-stop timer ends, or when you close the app.

## 🔒 Privacy and security

- No accounts, no analytics, no servers. Everything stays on your local network.
- Transfers use plain HTTP on your local network and are **not encrypted**. Anyone who can sniff traffic on the same Wi-Fi could see them. Use LocalBridge on networks you trust, not on public Wi-Fi.
- Trusted devices are matched by **device name**, which can be imitated by someone else on the same network. Only star your own devices, and keep *Auto-accept* off on shared networks.
- Link sharing: use the PIN and approval options if others are on your network.

## 📋 Changelog

The full history is also available in the app under **Settings → About → What's new**.

### `1.3.0` — More Settings
- 🎨 AMOLED mode, 11 accent colors & text size
- 📡 Radar, header & visibility options
- 🔒 Hidden IPs & trusted devices
- 📳 Haptic feedback
- 👥 Sender grouping & overwrite option
- ⚙️ Request timeout & link auto-stop
- 📜 History size & in-app changelog

### `1.2.0` — Link Sharing
- 🔗 Share files via links with PIN protection
- ✅ Access approval system
- 🌍 English interface

### `1.1.0` — LocalBridge Redesign
- ✨ Material 3 interface
- 🗂️ Tab navigation & transfer history
- ⚙️ Initial settings

### `1.0.0` — LocalBridge
- 📡 Device discovery
- 📤 Local file transfers
- ✅ Accept / decline requests

---

<sub>More improvements, refinements and features are on the way.</sub>

## 🗺 Platforms

Tested on **Android** and **Windows**. The code is Flutter, so Linux and macOS builds may work with little or no change but haven't been tested.

## 🤝 Contributing

Issues and pull requests are welcome. If you found a bug, please include your platform, the app version (*Settings → About*), and what you expected to happen.

## 📄 License

([MIT](https://choosealicense.com/licenses/mit/))

---

<div align="center">
LocalBridge is an independent project and is not affiliated with LocalSend or any other file transfer app.
</div>
