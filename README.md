<div align="center">

# LocalBridge

**Send files between your phone and PC over Wi-Fi. No cloud, no cables, no accounts.**

[![Release](https://img.shields.io/github/v/release/unqale/localbridge?style=for-the-badge)](https://github.com/unqale/localbridge/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/unqale/localbridge/total?style=for-the-badge)](https://github.com/unqale/localbridge/releases)
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)

[Download](#download) | [Features](#features) | [How to use](#how-to-use) | [Settings](#settings) | [Build from source](#build-from-source) | [Troubleshooting](#troubleshooting)

</div>

<!-- Add screenshots here, e.g.
<p align="center">
  <img src="docs/screenshots/devices.png" width="260">
  <img src="docs/screenshots/history.png" width="260">
  <img src="docs/screenshots/settings.png" width="260">
</p>
-->

## What is LocalBridge?

LocalBridge finds other devices running LocalBridge on the same Wi-Fi network and lets you send files to them directly. Files travel straight from one device to the other over your local network. Nothing is uploaded to a server and you do not need an internet connection.

It also has a **Share via link** mode: pick some files, get a link, and anyone on your Wi-Fi can download them from a normal browser, even without the app.

## Project status

Version 3.0.0 is the last big update. From now on LocalBridge will only receive fixes and improvements. Support for more platforms such as macOS, Linux and iOS may be added later.

## Features

**Sending and receiving**
- Automatic device discovery on your local network
- Send multiple files at once with a live progress bar
- The receiver gets an accept or decline prompt before anything is saved
- Trusted devices: star a device to accept its files automatically
- Auto-accept mode for networks you fully trust
- Files never overwrite each other by default (`photo.jpg`, `photo (1).jpg`, ...)

**Share via link**
- Share files with any browser on your Wi-Fi, no app needed on the other side
- QR code for the link
- Optional PIN with an attempt limit
- Optional approval prompt for every browser that opens the link
- One-time downloads, extension filter, download limit
- Auto-stop timer (5 minutes to 3 hours) or share until you stop it

**Speed**
- Devices appear the moment they answer, without waiting for the whole scan
- Devices seen before are checked first
- VPN, virtual machine and Docker networks are skipped by default
- Adjustable scan speed (Balanced, Fast, Turbo)
- Parallel startup and an adjustable startup animation

**Interface**
- Dark Material 3 design with an animated radar that shows nearby devices
- Adapts to your screen: single column and bottom bar on phones, side menu and two-column pages on big windows and monitors
- Soft light that follows the mouse cursor on desktop, with adjustable strength
- Settings page with a category list and a search box on big windows, status bar at the bottom
- Redesigned What's new window
- English, Turkish and Russian
- 11 accent colors
- Adjustable text size, compact header, hide IP addresses
- Transfer history with filters and totals

## Download

Go to the [Releases](https://github.com/unqale/localbridge/releases/latest) page and download the file for your device:

| Platform | File | Notes |
|----------|------|-------|
| Android | `LocalBridge-vX.Y.Z-android-arm64-v8a.apk` | Works on almost all modern phones. Use `armeabi-v7a` for older 32-bit phones. |
| Windows | `LocalBridge-vX.Y.Z-windows.zip` | Unzip and run `localbridge.exe`. No installer needed. |

### Installing on Android
1. Download the APK on your phone.
2. Open it. Android will ask you to allow installing apps from your browser or file manager. Allow it for this install.
3. Open LocalBridge.

### Installing on Windows
1. Unzip the folder anywhere (keep all the files together).
2. Run the `.exe`.
3. If Windows Defender SmartScreen shows a warning, click **More info**, then **Run anyway**. The app is not code-signed.
4. When Windows Firewall asks, allow access on **Private networks**. Without this, other devices cannot reach your PC.

## How to use

### Send files to another device
1. Open LocalBridge on both devices and connect them to the same Wi-Fi.
2. The other device appears under **Nearby devices** within a few seconds.
3. Tap **Send** and choose your files.
4. The other device taps **Accept**. The transfer starts.

### Share files with a link
1. On the **Devices** tab, tap **Share** on the Share via link card and choose your files.
2. Copy the link (or scan the QR code) and open it in any browser on the same Wi-Fi.
3. If approval is on, accept the request that pops up in LocalBridge.
4. Tap **Stop sharing** when you are done.

### Where do received files go?
- **Windows:** your Downloads folder, in a `LocalBridge` subfolder
- **Android:** `Download/LocalBridge`, or the app's own folder if Android does not allow writing there

You can change the folder in **Settings > Receive > Save folder**.

## Settings

| Setting | What it does |
|---------|--------------|
| Scan speed | Balanced, Fast or Turbo. Faster scans find devices sooner but use more network and battery. |
| Scan VPN and virtual networks | Off by default. Turn it on only if your devices are on a VPN or virtual network. |
| Scan interval | How often LocalBridge looks for devices automatically. |
| Port | Must be the same on both devices (default `53317`). |
| Visible to other devices | Turn off to hide yourself from other devices. |
| Start turned on | Off: LocalBridge stays hidden until you press Turn on. |
| Startup animation | Off, Quick or Full. |
| Status bar, hover effects, mouse light, glow strength | Look and feel of the desktop layout. |
| Sort devices | By name, address or the order they were found. |
| Confirm before sending | Ask before files are sent to a device. |
| Sound when a transfer ends | Play a short sound after sending or receiving. |
| 24-hour clock | Choose how times are shown in the history. |
| Confirm before clearing history | Ask before the transfer list is deleted. |

## Build from source

You only need this if you want to modify the app. Regular users should use the [downloads](#download) above.

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
git tag v3.0.0
git push origin v3.0.0
```

## Troubleshooting

**The other device does not show up**
- Both devices must be on the same Wi-Fi network.
- Some routers have AP isolation or client isolation turned on, which blocks devices from talking to each other. Turn it off in your router settings, or try a phone hotspot.
- On Windows, allow LocalBridge through the firewall on Private networks.
- Make sure **Settings > Network > Visible to other devices** is on.
- The port must be the same on both devices (default `53317`).
- If you use a VPN, either turn it off or enable **Scan VPN and virtual networks**.
- Try **Scan speed: Fast** or **Turbo** in Settings > Network.
- If you use a VPN, try turning it off.

**"Could not start server" message**
Another app is using the port. LocalSend uses the same default port (`53317`), so close it or change the port in **Settings > Network > Port** on both devices.

**Android says it cannot save to Download**
Newer Android versions restrict writing to shared folders. LocalBridge then falls back to its own app folder. You can set another path under **Settings > Receive > Save folder**.

**A shared link does not open**
The link only works on the same local network and only while sharing is on. It stops when you tap Stop sharing, when the auto-stop timer ends, or when you close the app.

## Privacy and security

- No accounts, no analytics, no servers. Everything stays on your local network.
- Transfers use plain HTTP on your local network and are **not encrypted**. Anyone who can sniff traffic on the same Wi-Fi could see them. Use LocalBridge on networks you trust, not on public Wi-Fi.
- Trusted devices are matched by device name, which can be imitated by someone else on the same network. Only star your own devices, and keep Auto-accept off on shared networks.
- Link sharing: use the PIN and approval options if others are on your network.

## Changelog

The full history is also available in the app under **Settings > About > What's new**.

**3.0.0** - Last update: faster scanning, new settings, new look
- This is the last big update. From now on only fixes and improvements. macOS, Linux and iOS support may come later
- Faster startup: app, server and history load at the same time, shorter logo animation by default, new Startup animation setting
- Much faster device scanning: devices appear as soon as they answer, known devices are checked first, no waiting for the slowest address
- New Scan speed setting (Balanced, Fast, Turbo) and smarter scanning that skips VPN, virtual machine and Docker networks
- Settings page redesigned for big windows: category list, settings search and a Reset preferences button
- New status bar at the bottom of the window
- Eleven new settings: status bar, mouse light, glow strength, 24-hour clock, sort devices, sound when a transfer ends, confirm before sending, start turned on, confirm before clearing history, hover effects and side menu statistics
- New look: redesigned What's new window, nicer Devices header, What's new and Made by links in the side menu, Turn on / Turn off button at the top right of the Devices page, scroll bar at the edge of the window
- Receive settings: accept only from trusted devices, incoming size limit, open the folder after receiving
- New bridge logo, also used as the app icon of the .exe and .apk

**2.0.0** - Big update: new UI, desktop layout and side menu
- Redesigned dark UI built for full screen and big monitors
- Devices page with radar, share options and sharing settings
- History with filter chips, totals and a multi-column grid on wide windows
- Power switch to turn LocalBridge off
- Hover animations on desktop
- Inline QR code and more sharing settings
- Fixes: layout shifts, a rare crash while scanning, memory use on large transfers, translations, UI freeze when clearing history

**1.4.0** - Languages and extra sharing settings
English, Turkish and Russian. One-time downloads and allowed file extension filter.

**1.3.0** - Trusted devices and custom save folders
Trusted devices with auto-accept, custom save folder, better scan stability.

**1.2.0** - History and progress
Persistent transfer history, live progress bars and speed.

**1.1.0** - Share via link
Browser downloads over a link, optional PIN, configurable port.

**1.0.0** - Initial release
Local network device discovery and fast file transfer.

## Platforms

Tested on **Android** and **Windows**. The code is Flutter, so Linux, macOS and iOS builds may be added in the future.

## Contributing

Issues and pull requests are welcome. If you found a bug, please include your platform, the app version (Settings > About), and what you expected to happen.

## License

Add a license file before publishing (for example [MIT](https://choosealicense.com/licenses/mit/)) and put its name here.

---

<div align="center">
LocalBridge is an independent project and is not affiliated with LocalSend or any other file transfer app.
</div>
