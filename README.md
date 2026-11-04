# LocalDrop

Aynı Wi-Fi'deki Windows/Android cihazlar arasında dosya gönderme (LocalSend benzeri, MVP).

## Yol A: Bilgisayarında Flutter kuruluysa
PowerShell'de bu klasörde:   .\setup.ps1
Sonra:   cd app ; flutter run -d windows     (Android için: flutter run -d <cihaz>)

## Yol B: Hiçbir şey kurmadan (GitHub)
1. Bu klasörü yeni bir GitHub reposuna yükle.
2. Actions sekmesinde "build" çalışınca Artifacts bölümünden APK ve Windows klasörünü indir.
