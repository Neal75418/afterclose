# AfterClose Release Build Guide

## 快速指令

```bash
# 清理 + 準備
flutter clean && flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Android
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info

# iOS
flutter build ipa --release --obfuscate --split-debug-info=build/debug-info
```

## Android 簽署設定

### 1. 產生金鑰 (首次)

```bash
cd android
keytool -genkey -v -keystore afterclose-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias afterclose
```

### 2. 設定 key.properties

```bash
cp key.properties.template key.properties
# 編輯填入：storePassword, keyPassword, keyAlias, storeFile
```

## iOS 設定

1. 開啟 `ios/Runner.xcworkspace`
2. 選擇 Team，Bundle ID: `com.neo.afterclose`
3. 啟用 "Automatically manage signing"
4. Product → Archive → Distribute App

## 版本管理

```yaml
# pubspec.yaml
version: 1.0.0+1  # major.minor.patch+buildNumber
```

## 發布檢查清單

- [ ] 更新 `pubspec.yaml` 版本
- [ ] `flutter test` 通過
- [ ] `flutter analyze` 無錯誤
- [ ] 實機測試 (Android + iOS)
- [ ] 移除 debug 程式碼

## 圖示與啟動畫面

```bash
dart run flutter_launcher_icons      # 更新 App 圖示
dart run flutter_native_splash:create  # 更新啟動畫面
```

## 注意事項

- 勿 commit `key.properties` 或 keystore 檔案
- 保留 `build/debug-info` 供 crash 解析
