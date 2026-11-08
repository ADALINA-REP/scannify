$ErrorActionPreference = "Stop"

$SymbolsDir = "build/app/outputs/symbols"
New-Item -ItemType Directory -Force -Path $SymbolsDir | Out-Null

# 1. Clean project and fetch dependencies
flutter clean
flutter pub get

# 2. Build Play Store App Bundle (AAB) with obfuscation & stripped debug symbols
flutter build appbundle --release `
  --obfuscate `
  --split-debug-info="$SymbolsDir" `
  --tree-shake-icons

# 3. Build Split-ABI APKs for local device testing
flutter build apk --release `
  --split-per-abi `
  --obfuscate `
  --split-debug-info="$SymbolsDir" `
  --tree-shake-icons

Get-ChildItem "build/app/outputs/flutter-apk/*-release.apk" | Select-Object Name, @{Name="SizeMB";Expression={[math]::Round($_.Length / 1MB, 2)}}

