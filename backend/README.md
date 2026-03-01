# Clutter Zen Backend

This folder contains a Firebase Cloud Functions backend that proxies Google Vision API and Replicate requests so API keys remain on the server.

## Prerequisites

- Firebase CLI (`npm install -g firebase-tools`)
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)
- Node.js 18+
- A Firebase project (e.g. `clutter-zen`)
- Google Cloud Vision API enabled for the project
- Replicate API token

## Initial setup

```bash
cd backend
firebase init functions   # choose JavaScript, Node 18, skip ESLint if preferred
```

If you used `firebase init` previously, you can keep your existing `.firebaserc` / `firebase.json`.

Copy the contents of `backend/functions` from this repository into the Firebase functions directory (overwrite the generated placeholder files).

## Configure secrets

Set the API keys as Firebase Functions environment config:

```bash
firebase functions:config:set vision.key="YOUR_VISION_API_KEY"
firebase functions:config:set replicate.token="YOUR_REPLICATE_API_TOKEN"
```

You can verify with `firebase functions:config:get`.

## Install dependencies

```bash
cd backend/functions
npm install
```

## Emulate locally (optional)

```bash
firebase emulators:start --only functions
```

The Express app is exposed at `http://localhost:5001/<project>/us-central1/api`.

## Deploy

```bash
firebase deploy --only functions
```

After deployment, the HTTPS endpoint is:

```
https://us-central1-<project-id>.cloudfunctions.net/api
```

Available routes:

- `POST /vision/analyze`
  - body: `{ "imageUrl": "https://..." }` or `{ "imageBase64": "<base64>" }`

- `POST /replicate/generate`
  - body: `{ "imageUrl": "https://..." }`
  - success response:
    - `data.outputUrl` (durable Firebase Storage download URL)
    - `data.predictionId`
    - `data.sourceOutputUrl` (original provider URL)
    - `data.storagePath` (Firebase Storage object path)

## Integrating with the Flutter app

1. Update the Flutter services to call your backend instead of the third-party APIs directly.
2. Store the backend base URL (e.g. via `--dart-define=BACKEND_BASE_URL=...`).
3. Add authentication (Firebase App Check, Firebase Auth ID token, etc.) if you want to restrict access.

## Notes

- All secrets remain on the server; the Flutter client never sees the raw API keys.
- You can extend this backend with additional endpoints (e.g., history storage, rate limiting).
