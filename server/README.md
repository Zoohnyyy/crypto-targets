# Crypto Prices — push backend

A small Node/TypeScript service that watches Binance + Bybit prices 24/7 and
pushes **instant** FCM notifications when a device's price or portfolio alerts
cross their thresholds.

See [`../DEPLOY_PUSH.md`](../DEPLOY_PUSH.md) for full setup + deployment.

## Run locally

```bash
npm install
npm run build
# provide env vars (see .env.example), then:
node dist/index.js
# or during development:
npm run dev
```

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/health` | none | liveness + device/price counts |
| POST | `/sync` | `x-api-key` | upsert a device's FCM token + alert bundle |
| POST | `/unregister` | `x-api-key` | drop a device token |

`POST /sync` body:
```json
{
  "token": "<fcm-registration-token>",
  "bundle": {
    "priceAlerts": [{ "id": "...", "symbol": "btc", "targetPrice": 70000, "direction": "above", "enabled": true }],
    "holdings": [{ "symbol": "btc", "amount": 0.5 }],
    "portfolioAlerts": [{ "id": "...", "denom": "token", "denomSymbol": "eth", "targetAmount": 100, "direction": "above", "enabled": true }]
  }
}
```

## Design notes

- **Price feed:** one Binance combined WebSocket + one Bybit WebSocket for the
  union of all symbols across all devices; REST snapshot on (re)subscribe.
- **Evaluation:** edge-triggered per alert (fires once on crossing, re-arms when
  it crosses back), identical to the app's on-device logic.
- **Storage:** a JSON file (`DATA_FILE`). Fine for personal use; swap for a DB
  to scale.
- **Dead tokens:** FCM "not registered" errors auto-remove the device.
