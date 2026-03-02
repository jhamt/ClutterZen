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
firebase functions:config:set google.places.key="YOUR_GOOGLE_PLACES_API_KEY"
```

Optional quota guard (recommended to stay in free tier averages):

```bash
export MAPS_DAILY_NEARBY_CAP=24
export MAPS_DAILY_TEXT_CAP=8
export MAPS_DAILY_DETAILS_CAP=28
export MAPS_DAILY_GEOCODE_CAP=300
export MAPS_DAILY_PREMIUM_CAP=30
export MAPS_ENABLE_PLACE_PHOTOS=false
```

These are read from Functions environment variables and can be tuned.
`MAPS_DAILY_PREMIUM_CAP` protects free-tier usage by capping combined nearby/text/details calls per day.
`MAPS_ENABLE_PLACE_PHOTOS=false` avoids accidental Places Photo SKU costs by default.

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

- `POST /professionals/nearby`
  - body: `{ "latitude": 37.77, "longitude": -122.42, "detectedObjects": ["desk"] }`
  - or: `{ "locationQuery": "San Francisco, CA", "labels": ["office"] }`
  - success response:
    - `data.services` (normalized nearby professionals)
    - `data.meta` (source, resolved location, radius, quality diagnostics)

## Integrating with the Flutter app

1. Update the Flutter services to call your backend instead of the third-party APIs directly.
2. Store the backend base URL (e.g. via `--dart-define=BACKEND_BASE_URL=...`).
3. Add authentication (Firebase App Check, Firebase Auth ID token, etc.) if you want to restrict access.

## Notes

- All secrets remain on the server; the Flutter client never sees the raw API keys.
- You can extend this backend with additional endpoints (e.g., history storage, rate limiting).
