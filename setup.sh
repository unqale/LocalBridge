#!/usr/bin/env bash
set -e
flutter create --platforms=windows,android --org com.localdrop --project-name localdrop app
cp src/main.dart app/lib/main.dart
cp AndroidManifest.xml app/android/app/src/main/AndroidManifest.xml
cd app
flutter pub add file_picker:^8.3.7 path_provider path
