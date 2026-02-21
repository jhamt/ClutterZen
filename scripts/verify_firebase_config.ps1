# Firebase Configuration Verification Script (PowerShell)

Write-Host "Firebase Configuration Verification" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

Write-Host "1. Checking Firebase CLI... " -NoNewline
try {
    $firebaseVersion = firebase --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK ($firebaseVersion)" -ForegroundColor Green
    } else {
        Write-Host "FAILED: firebase CLI not found. Install with npm install -g firebase-tools" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "FAILED: firebase CLI not found. Install with npm install -g firebase-tools" -ForegroundColor Red
    exit 1
}

Write-Host "2. Checking firebase.json... " -NoNewline
if (Test-Path "firebase.json") {
    Write-Host "OK" -ForegroundColor Green
    $firebaseJson = Get-Content "firebase.json" | ConvertFrom-Json
    Write-Host "   Services configured:" -ForegroundColor Gray
    if ($firebaseJson.firestore) { Write-Host "   - Firestore" -ForegroundColor Gray }
    if ($firebaseJson.storage) { Write-Host "   - Storage" -ForegroundColor Gray }
    if ($firebaseJson.functions) { Write-Host "   - Functions" -ForegroundColor Gray }
} else {
    Write-Host "FAILED: firebase.json not found" -ForegroundColor Red
    exit 1
}

Write-Host "3. Checking .firebaserc... " -NoNewline
if (Test-Path ".firebaserc") {
    Write-Host "OK" -ForegroundColor Green
    $firebaserc = Get-Content ".firebaserc" | ConvertFrom-Json
    Write-Host "   Project ID: $($firebaserc.projects.default)" -ForegroundColor Gray
} else {
    Write-Host "FAILED: .firebaserc not found" -ForegroundColor Red
    exit 1
}

Write-Host "4. Checking Firestore rules... " -NoNewline
if (Test-Path "firebase/firestore.rules") {
    Write-Host "OK" -ForegroundColor Green
    $ruleCount = (Select-String -Path "firebase/firestore.rules" -Pattern "match /").Count
    Write-Host "   Rules defined: $ruleCount" -ForegroundColor Gray
} else {
    Write-Host "FAILED: firebase/firestore.rules not found" -ForegroundColor Red
}

Write-Host "5. Checking Storage rules... " -NoNewline
if (Test-Path "firebase/storage.rules") {
    Write-Host "OK" -ForegroundColor Green
} else {
    Write-Host "FAILED: firebase/storage.rules not found" -ForegroundColor Red
}

Write-Host "6. Checking Functions... " -NoNewline
if (Test-Path "backend/functions/index.js") {
    Write-Host "OK" -ForegroundColor Green
    $endpointCount = (Select-String -Path "backend/functions/index.js" -Pattern "app\.").Count
    Write-Host "   Endpoints defined: $endpointCount" -ForegroundColor Gray
} else {
    Write-Host "FAILED: backend/functions/index.js not found" -ForegroundColor Red
}

Write-Host "7. Checking Firebase options... " -NoNewline
if (Test-Path "lib/firebase_options.dart") {
    Write-Host "OK" -ForegroundColor Green
} else {
    Write-Host "WARN: lib/firebase_options.dart not found (may need: flutterfire configure)" -ForegroundColor Yellow
}

Write-Host "8. Checking Google Services configs... " -NoNewline
$androidConfig = "android/app/google-services.json"
$iosConfig = "ios/Runner/GoogleService-Info.plist"
if (Test-Path $androidConfig) {
    Write-Host "Android OK" -ForegroundColor Green
} else {
    Write-Host "Android MISSING" -ForegroundColor Yellow
}
if (Test-Path $iosConfig) {
    Write-Host "   iOS OK" -ForegroundColor Green
} else {
    Write-Host "   iOS MISSING" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Configuration check complete" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Deploy rules: firebase deploy --only firestore:rules,storage:rules"
Write-Host "2. Deploy functions: firebase deploy --only functions"
Write-Host "3. Run E2E test: dart scripts/test_firebase_e2e.dart"
