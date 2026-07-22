// Runtime configuration from environment variables.

export const config = {
  port: parseInt(process.env.PORT ?? '8080', 10),

  // A shared secret the app sends in the `x-api-key` header. Set this to a
  // random string on the server AND in the app so randoms can't register.
  apiKey: process.env.API_KEY ?? '',

  // Firebase service account JSON, provided as a single-line env var. Get this
  // from Firebase Console → Project settings → Service accounts → Generate key.
  firebaseServiceAccount: process.env.FIREBASE_SERVICE_ACCOUNT ?? '',

  // Where the device store is persisted (JSON file). On Railway/Render, mount a
  // volume or accept that it resets on redeploy (devices re-sync on app open).
  dataFile: process.env.DATA_FILE ?? './data/devices.json',

  // How which symbols map to which exchange. Symbols not listed default to
  // Binance; anything here is served from Bybit (e.g. HYPE).
  bybitSymbols: (process.env.BYBIT_SYMBOLS ?? 'hype')
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean),
};

export function assertConfig(): void {
  if (!config.firebaseServiceAccount) {
    throw new Error(
      'FIREBASE_SERVICE_ACCOUNT env var is required (service account JSON).',
    );
  }
  if (!config.apiKey) {
    console.warn(
      '[config] API_KEY is empty — the sync endpoint is UNPROTECTED. ' +
        'Set API_KEY in production.',
    );
  }
}
