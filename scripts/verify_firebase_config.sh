#!/bin/bash

# Firebase Configuration Verification Script
# This script verifies all Firebase configurations are in place

echo "🔥 Firebase Configuration Verification"
echo "========================================"

# Check Firebase CLI
echo -n "1. Checking Firebase CLI... "
if command -v firebase &> /dev/null; then
    FIREBASE_VERSION=$(firebase --version)
    echo "✅ Found: $FIREBASE_VERSION"
else
    echo "❌ Firebase CLI not found. Install with: npm install -g firebase-tools"
    exit 1
fi

# Check firebase.json
echo -n "2. Checking firebase.json... "
if [ -f "firebase.json" ]; then
    echo "✅ Found"
    echo "   Contents:"
    cat firebase.json | grep -E "(firestore|storage|functions)" | sed 's/^/   /'
else
    echo "❌ firebase.json not found"
    exit 1
fi

# Check .firebaserc
echo -n "3. Checking .firebaserc... "
if [ -f ".firebaserc" ]; then
    echo "✅ Found"
    PROJECT_ID=$(cat .firebaserc | grep -o '"default": "[^"]*"' | cut -d'"' -f4)
    echo "   Project ID: $PROJECT_ID"
else
    echo "❌ .firebaserc not found"
    exit 1
fi

# Check Firestore rules
echo -n "4. Checking Firestore rules... "
if [ -f "firebase/firestore.rules" ]; then
    echo "✅ Found"
    RULE_COUNT=$(grep -c "match /" firebase/firestore.rules || echo "0")
    echo "   Rules defined: $RULE_COUNT"
else
    echo "❌ firebase/firestore.rules not found"
fi

# Check Storage rules
echo -n "5. Checking Storage rules... "
if [ -f "firebase/storage.rules" ]; then
    echo "✅ Found"
else
    echo "❌ firebase/storage.rules not found"
fi

# Check Functions
echo -n "6. Checking Functions... "
if [ -f "backend/functions/index.js" ]; then
    echo "✅ Found"
    ENDPOINT_COUNT=$(grep -c "app\." backend/functions/index.js || echo "0")
    echo "   Endpoints defined: $ENDPOINT_COUNT"
else
    echo "❌ backend/functions/index.js not found"
fi

# Check Firebase options
echo -n "7. Checking Firebase options... "
if [ -f "lib/firebase_options.dart" ]; then
    echo "✅ Found"
else
    echo "⚠️  lib/firebase_options.dart not found (may need: flutterfire configure)"
fi

# Check Google Services files
echo -n "8. Checking Google Services configs... "
ANDROID_CONFIG="android/app/google-services.json"
IOS_CONFIG="ios/Runner/GoogleService-Info.plist"

if [ -f "$ANDROID_CONFIG" ]; then
    echo "✅ Android config found"
else
    echo "⚠️  Android config not found"
fi

if [ -f "$IOS_CONFIG" ]; then
    echo "   ✅ iOS config found"
else
    echo "   ⚠️  iOS config not found"
fi

echo ""
echo "========================================"
echo "✅ Configuration check complete!"
echo ""
echo "Next steps:"
echo "1. Deploy rules: firebase deploy --only firestore:rules,storage:rules"
echo "2. Deploy functions: firebase deploy --only functions"
echo "3. Run E2E test: dart scripts/test_firebase_e2e.dart"

