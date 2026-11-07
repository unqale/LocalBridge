# LocalBridge

Send files between your devices over the same Wi-Fi. No cloud, no account, no cables.

Available for **Windows** and **Android**.

## Features

- **Fast transfers** between devices on the same network
- **Automatic discovery**: nearby devices show up on a radar, tap one to send
- **Share via link**: let anyone on your Wi-Fi download files from a browser
  - optional PIN, one-time download, download limit, file type filter, QR code
- **Trusted devices** and optional auto-accept
- **Transfer history** with sent / received totals
- Languages: **English, Türkçe, Русский**
- Dark UI with accent colors, desktop side menu, phone-friendly layout

## Download

Get the latest version from the [Releases](../../releases) page.

| Platform | File |
| --- | --- |
| Android | `LocalBridge-...-android-arm64-v8a.apk` (most modern phones) |
| Windows | `LocalBridge-...-windows.zip` |

**Windows:** extract the whole zip into a folder, then run `LocalBridge.exe`.
If Windows Firewall asks, allow **Private networks**.

**Android:** open the `.apk` and allow installing from unknown sources if asked.

## How to use

1. Open LocalBridge on both devices (same Wi-Fi).
2. The other device appears in **Nearby devices**.
3. Tap it, pick files, and accept the request on the other side.

To share with a device that does not have the app, use **Share via link** and open the link or QR code in any browser.

## Build from source

You need [Flutter](https://docs.flutter.dev/get-started/install).

```bash
flutter pub get
flutter run -d windows     # or: flutter run -d <android-device>

flutter build windows --release
flutter build apk --release --split-per-abi
```

Pushing a tag like `v2.1.0` builds the Windows and Android files on GitHub and attaches them to a new release.

## Notes

- Transfers use plain HTTP on your local network (default port `53317`). Only use LocalBridge on networks you trust.
- Both devices must use the same port (Settings > Network).

## License

[MIT](LICENSE)
