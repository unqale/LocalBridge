$ErrorActionPreference = "Stop"
flutter create --platforms=windows,android --org com.localdrop --project-name localdrop app
Copy-Item src\main.dart app\lib\main.dart -Force
Copy-Item AndroidManifest.xml app\android\app\src\main\AndroidManifest.xml -Force
Set-Location app
flutter pub add file_picker:^8.3.7 path_provider path
Write-Host "Hazir. Calistirmak icin: flutter run -d windows"
