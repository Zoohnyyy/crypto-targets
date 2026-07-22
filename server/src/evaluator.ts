import type { DeviceStore } from './deviceStore.js';
import type { PriceWatcher } from './priceWatcher.js';
import { sendPush } from './push.js';
import type {
  AlertBundle,
  AlertDirection,
  PortfolioAlert,
  PriceAlert,
} from './types.js';

/**
 * Evaluates every device's alerts against the latest prices and pushes FCM
 * notifications on threshold crossings. Edge-triggered: fires once when a
 * condition first becomes true, re-arms only after it crosses back — matching
 * the app's on-device logic so behaviour is identical whether or not the app
 * is open.
 */
export class Evaluator {
  private running = false;

  constructor(
    private readonly store: DeviceStore,
    private readonly prices: PriceWatcher,
  ) {}

  /** Evaluate all devices once. Safe to call frequently; self-throttles. */
  async evaluateAll(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      for (const device of this.store.all()) {
        await this.evaluateDevice(device.token, device.bundle, device.triggered);
      }
    } finally {
      this.running = false;
    }
  }

  private async evaluateDevice(
    token: string,
    bundle: AlertBundle,
    triggered: Record<string, boolean>,
  ): Promise<void> {
    let tokenAlive = true;

    // Price alerts.
    for (const a of bundle.priceAlerts) {
      if (!a.enabled) continue;
      const price = this.prices.getPrice(a.symbol);
      if (price === undefined) continue;
      const met = meets(price, a.targetPrice, a.direction);
      tokenAlive = await this.applyEdge(
        token,
        a.id,
        met,
        triggered,
        () => priceAlertBody(a, price),
        `${a.symbol.toUpperCase()} price alert`,
      );
      if (!tokenAlive) return;
    }

    // Portfolio alerts.
    for (const pa of bundle.portfolioAlerts) {
      if (!pa.enabled) continue;
      const value = this.portfolioValueFor(bundle, pa);
      if (value === undefined) continue;
      const met = meets(value, pa.targetAmount, pa.direction);
      tokenAlive = await this.applyEdge(
        token,
        pa.id,
        met,
        triggered,
        () => portfolioAlertBody(pa, value),
        'Portfolio alert',
      );
      if (!tokenAlive) return;
    }
  }

  /** Fire once on rising edge; re-arm on falling edge. Returns token validity. */
  private async applyEdge(
    token: string,
    id: string,
    met: boolean,
    triggered: Record<string, boolean>,
    body: () => string,
    title: string,
  ): Promise<boolean> {
    const was = triggered[id] ?? false;
    if (met && !was) {
      const alive = await sendPush(token, title, body());
      if (!alive) {
        this.store.remove(token);
        return false;
      }
      this.store.markTriggered(token, id, true);
    } else if (!met && was) {
      this.store.markTriggered(token, id, false);
    }
    return true;
  }

  private portfolioValueFor(
    bundle: AlertBundle,
    pa: PortfolioAlert,
  ): number | undefined {
    let usd = 0;
    for (const h of bundle.holdings) {
      const p = this.prices.getPrice(h.symbol);
      if (p === undefined) continue;
      usd += h.amount * p;
    }
    if (pa.denom === 'usd') return usd;
    const denomPrice = pa.denomSymbol
      ? this.prices.getPrice(pa.denomSymbol)
      : undefined;
    if (!denomPrice || denomPrice === 0) return undefined;
    return usd / denomPrice;
  }
}

function meets(value: number, target: number, dir: AlertDirection): boolean {
  return dir === 'above' ? value >= target : value <= target;
}

function fmt(v: number, digits: number): string {
  return v.toLocaleString('en-US', {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  });
}

function priceAlertBody(a: PriceAlert, price: number): string {
  const dir = a.direction === 'above' ? 'above' : 'below';
  const d = a.targetPrice >= 1 ? 2 : 6;
  return `${a.symbol.toUpperCase()} is now $${fmt(price, d)} — ${dir} your target of $${fmt(a.targetPrice, d)}`;
}

function portfolioAlertBody(pa: PortfolioAlert, value: number): string {
  const dir = pa.direction === 'above' ? 'above' : 'below';
  const label = (v: number) =>
    pa.denom === 'usd'
      ? `$${fmt(v, 2)}`
      : `${fmt(v, v >= 1 ? 4 : 6)} ${(pa.denomSymbol ?? '').toUpperCase()}`;
  return `Your portfolio is now ${label(value)} — ${dir} your target of ${label(pa.targetAmount)}`;
}
