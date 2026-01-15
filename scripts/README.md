# Firebase E2E Testing Scripts

## Overview

This directory contains scripts for testing Firebase functionality end-to-end.

## Scripts

### 1. `test_firebase_e2e.dart`

Comprehensive end-to-end test for all Firebase services.

**Features:**
- Tests Firebase Authentication
- Tests Firestore database operations
- Tests Firebase Storage
- Tests Firebase Analytics
- Tests Firebase Crashlytics
- Checks Functions deployment status

**Usage:**
```bash
dart scripts/test_firebase_e2e.dart
```

**Prerequisites:**
- `.env` file with Firebase configuration
- Firebase project initialized
- User authenticated (for Storage tests)

### 2. `verify_firebase_config.ps1`

PowerShell script to verify Firebase configuration files.

**Usage:**
```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify_firebase_config.ps1
```

**Checks:**
- Firebase CLI installation
- firebase.json configuration
- .firebaserc project settings
- Firestore rules
- Storage rules
- Functions code
- Firebase options
- Google Services configs

### 3. `verify_firebase_config.sh`

Bash script (alternative to PowerShell).

**Usage:**
```bash
bash scripts/verify_firebase_config.sh
```

## Test Results

All tests should pass when:
- ✅ Firebase is properly configured
- ✅ Environment variables are set
- ✅ User is authenticated (for Storage)
- ✅ Firestore API is enabled
- ✅ Functions are deployed (for Functions test)

## Troubleshooting

### Error: "Firebase initialization failed"
- Check `.env` file exists
- Verify Firebase configuration in `lib/firebase_options.dart`
- Ensure Firebase project is initialized

### Error: "Firestore API not enabled"
- Enable Firestore API in Google Cloud Console
- Visit: https://console.developers.google.com/apis/api/firestore.googleapis.com/overview?project=clutterzen-test

### Error: "Storage test skipped"
- Sign in to the app first
- Storage operations require authentication

### Error: "Functions not deployed"
- Upgrade Firebase plan to Blaze
- Deploy functions: `firebase deploy --only functions`

## Next Steps

1. Run configuration verification
2. Enable required APIs
3. Deploy security rules
4. Deploy functions (after plan upgrade)
5. Run E2E tests

