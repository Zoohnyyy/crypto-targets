# Instant push notifications — setup guide

This adds **instant** price/portfolio alerts that fire even when the app is fully
closed, via a 24/7 backend + Firebase Cloud Messaging (FCM).

**The app already works without this** — it falls back to on-device ~15-minute
background checks. Push is fully optional and inert until you complete these
steps. Nothing here changes existing behavior until you add the config.

There are **three parts**, and some steps only you can do (they need your Google
account and hosting account):

1. **Firebase project** (you) — creates the push credentials
2. **Deploy the backend** (you, guided) — the 24/7 watcher
3. **Rebuild the app with config** (you, guided) — points it at the backend

---

## Part 1 — Firebase project (~10 min)

1. Go to <https://console.firebase.google.com> → **Add project**. Name it
   anything (e.g. "crypto-prices"). You can disable Google Analytics.
2. In the project, click **Add app → Android**.
   - **Android package name:** `com.example.crypto_prices` (must match exactly)
   - Register the app.
3. **Download `google-services.json`** and place it at:
   ```
   android/app/google-services.json
   ```
   (This file is gitignored — it contains keys. Don't commit it.)
4. Get the **service account** for the backend:
   - Firebase Console → ⚙ **Project settings** → **Service accounts** tab
   - **Generate new private key** → downloads a JSON file. Keep it secret.

That's the Firebase side done.

---

## Part 2 — Deploy the backend (~15 min, Railway)

The backend lives in [`server/`](server/). It watches Binance/Bybit prices over
WebSocket and pushes FCM notifications the instant an alert crosses.

### Option A — Railway (recommended)

1. Create an account at <https://railway.app> and install the CLI, or use the
   web UI. Easiest: push this repo to GitHub, then in Railway **New Project →
   Deploy from GitHub repo**, and set the **root directory** to `server`.
2. Railway auto-detects Node. Confirm the build/start commands:
   - Build: `npm install && npm run build`
   - Start: `npm start`
3. Add **environment variables** (Railway → your service → Variables):

   | Variable | Value |
   |---|---|
   | `API_KEY` | a long random string you invent (save it — the app needs it) |
   | `FIREBASE_SERVICE_ACCOUNT` | the **entire** service-account JSON from Part 1, **minified to one line** |
   | `BYBIT_SYMBOLS` | `hype` (comma-separated list of Bybit-only coins) |
   | `DATA_FILE` | `/data/devices.json` |

   > To minify the service-account JSON to one line: open it in an editor and
   > remove newlines, or run `node -e "console.log(JSON.stringify(require('./key.json')))"`.

4. (Optional but recommended) Add a **Volume** mounted at `/data` so device
   registrations survive redeploys. Without it, devices simply re-sync next time
   the app opens — not fatal.
5. Deploy. Railway gives you a public URL like
   `https://crypto-prices-production.up.railway.app`. **Save it.**
6. Verify it's alive: open `https://<your-url>/health` in a browser — you should
   see `{"ok":true,...}`.

### Option B — any other host / your own VPS

The backend is a plain Node 20+ app. On any server:
```bash
cd server
npm install
npm run build
API_KEY=... FIREBASE_SERVICE_ACCOUNT='...' node dist/index.js
```
Use `pm2` or a systemd unit to keep it running. Put it behind HTTPS.

---

## Part 3 — Rebuild the app pointed at the backend

The backend URL and API key are passed at build time via `--dart-define` (so no
secrets are hardcoded in source):

```bash
cd c:\flutter\crypto-prices

flutter build apk --release \
  --dart-define=PUSH_BACKEND_URL=https://<your-railway-url> \
  --dart-define=PUSH_API_KEY=<the-same-API_KEY-you-set-on-the-server>
```

Or to run on a device with hot reload:
```bash
flutter run \
  --dart-define=PUSH_BACKEND_URL=https://<your-railway-url> \
  --dart-define=PUSH_API_KEY=<same-key>
```

> Make sure `android/app/google-services.json` (from Part 1) is in place before
> building, otherwise Firebase init is skipped and push stays off.

---

## How it works

```
App ──register FCM token + sync alerts──►  Backend (Railway)
App ◄──────── instant FCM push ─────────   - watches Binance/Bybit WS 24/7
                                           - evaluates your alerts on every tick
                                           - pushes the moment one crosses
```

- On launch and whenever you change an alert/holding, the app POSTs your alert
  bundle to `POST /sync` (keyed by your device's FCM token).
- The backend evaluates continuously and calls FCM on a crossing. Edge-triggered
  (fires once, re-arms when it crosses back) — same logic as on-device.
- The app shows the push as a notification in both foreground and background
  (and when killed, Android delivers it directly).

## Testing it end to end

1. Complete Parts 1–3 and install the rebuilt app on a phone.
2. Open the app once (this registers the token + syncs your alerts).
3. Create a price alert that's already true (e.g. "BTC ≥ $1") or a portfolio
   alert you know is met.
4. Within a second or two you should get a push — **even with the app swiped
   away**. Check the backend `/health` shows `devices: 1` and the Railway logs
   show `[fcm]` activity.

## Troubleshooting

- **No push:** confirm `/health` is reachable and returns `devices ≥ 1` after
  opening the app. Check Railway logs for `[fcm] send error`.
- **Build fails after adding Firebase:** ensure `google-services.json` is valid
  and the package name matches `com.example.crypto_prices`.
- **Token missing:** the app needs notification permission granted (Android 13+).

## Costs

- Firebase Cloud Messaging: **free**.
- Railway: has a small free/hobby tier; a single always-on Node service is
  inexpensive. Any Node host works.
