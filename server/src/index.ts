import express from 'express';
import { config, assertConfig } from './config.js';
import { DeviceStore } from './deviceStore.js';
import { Evaluator } from './evaluator.js';
import { initFirebase } from './push.js';
import { PriceWatcher } from './priceWatcher.js';
import { symbolsForBundle, type AlertBundle } from './types.js';

async function main() {
  assertConfig();
  initFirebase();

  const store = new DeviceStore();
  await store.load();

  const watcher = new PriceWatcher();
  const evaluator = new Evaluator(store, watcher);

  // Recompute the union of all symbols across devices and update the watcher.
  const refreshSymbols = () => {
    const all = new Set<string>();
    for (const d of store.all()) {
      for (const s of symbolsForBundle(d.bundle)) all.add(s);
    }
    watcher.updateSymbols(all);
  };
  refreshSymbols();

  // Evaluate on price updates, throttled to at most once per second so a burst
  // of ticks doesn't cause a burst of evaluations.
  let pending = false;
  watcher.setOnUpdate(() => {
    if (pending) return;
    pending = true;
    setTimeout(() => {
      pending = false;
      void evaluator.evaluateAll();
    }, 1000);
  });

  // Safety net: also evaluate on a fixed interval (covers the case where prices
  // are static but an alert was just added).
  setInterval(() => void evaluator.evaluateAll(), 15000);

  // ---- HTTP API ---------------------------------------------------------

  const app = express();
  app.use(express.json({ limit: '256kb' }));

  // Simple API-key gate for mutating endpoints.
  const requireKey: express.RequestHandler = (req, res, next) => {
    if (config.apiKey && req.header('x-api-key') !== config.apiKey) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }
    next();
  };

  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      devices: store.all().length,
      prices: Object.keys(watcher.priceMap()).length,
    });
  });

  // The app calls this on launch and whenever alerts/portfolio change.
  app.post('/sync', requireKey, (req, res) => {
    const { token, bundle } = req.body as {
      token?: string;
      bundle?: AlertBundle;
    };
    if (!token || !bundle) {
      res.status(400).json({ error: 'token and bundle required' });
      return;
    }
    const safeBundle: AlertBundle = {
      priceAlerts: bundle.priceAlerts ?? [],
      holdings: bundle.holdings ?? [],
      portfolioAlerts: bundle.portfolioAlerts ?? [],
    };
    store.upsert(token, safeBundle);
    refreshSymbols();
    // Evaluate right away so a just-added alert that's already met fires now.
    void evaluator.evaluateAll();
    res.json({ ok: true });
  });

  // Optional: app can unregister on logout / disable-push.
  app.post('/unregister', requireKey, (req, res) => {
    const { token } = req.body as { token?: string };
    if (token) {
      store.remove(token);
      refreshSymbols();
    }
    res.json({ ok: true });
  });

  app.listen(config.port, () => {
    console.log(`[http] listening on :${config.port}`);
  });
}

main().catch((e) => {
  console.error('fatal', e);
  process.exit(1);
});
