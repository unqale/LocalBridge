# LocalDrop

Sending files between Windows/Android devices on the same Wi-Fi network (similar to LocalSend; MVP).

## Option A: If you have Flutter installed on your computer
In PowerShell, while in this folder, run:   .\setup.ps1
Then:   cd app ; flutter run -d windows     (For Android: flutter run -d <device>)

## Option B: Without installing anything (via GitHub) not work rn
1. Upload this folder to a new GitHub repository.
2. Once the "build" process runs under the Actions tab, download the APK and the Windows folder from the Artifacts section.
