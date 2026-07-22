import WebSocket from 'ws';
import { config } from './config.js';

/**
 * Maintains a live USD price map for a dynamic set of symbols, using Binance
 * and Bybit public WebSockets (plus a REST warm-up). Prices are quoted in
 * USDT (~USD).
 *
 * The watched symbol set is updated as devices sync their alerts; the watcher
 * reconnects only when the set actually changes.
 */
export class PriceWatcher {
  private prices = new Map<string, number>(); // lowercase base -> USD price
  private binanceSymbols: string[] = [];
  private bybitSymbols: string[] = [];
  private binanceWs: WebSocket | null = null;
  private bybitWs: WebSocket | null = null;
  private binanceBackoff = 1000;
  private bybitBackoff = 1000;
  private onUpdate: (() => void) | null = null;

  /** Register a callback fired (throttled by caller) when prices change. */
  setOnUpdate(cb: () => void): void {
    this.onUpdate = cb;
  }

  getPrice(symbol: string): number | undefined {
    return this.prices.get(symbol.toLowerCase());
  }

  priceMap(): Record<string, number> {
    return Object.fromEntries(this.prices);
  }

  /** Partition symbols into Binance vs Bybit and (re)subscribe as needed. */
  updateSymbols(symbols: Set<string>): void {
    const bybit: string[] = [];
    const binance: string[] = [];
    for (const s of symbols) {
      if (config.bybitSymbols.includes(s)) bybit.push(s);
      else binance.push(s);
    }
    binance.sort();
    bybit.sort();

    if (!eq(binance, this.binanceSymbols)) {
      this.binanceSymbols = binance;
      this.connectBinance();
      void this.snapshotBinance();
    }
    if (!eq(bybit, this.bybitSymbols)) {
      this.bybitSymbols = bybit;
      this.connectBybit();
      void this.snapshotBybit();
    }
  }

  // ---- Binance ----------------------------------------------------------

  private connectBinance(): void {
    this.binanceWs?.removeAllListeners();
    this.binanceWs?.close();
    this.binanceWs = null;
    if (this.binanceSymbols.length === 0) return;

    const streams = this.binanceSymbols.map((s) => `${s}usdt@ticker`).join('/');
    const url = `wss://stream.binance.com:9443/stream?streams=${streams}`;
    const ws = new WebSocket(url);
    this.binanceWs = ws;

    ws.on('message', (raw) => {
      this.binanceBackoff = 1000;
      try {
        const msg = JSON.parse(raw.toString());
        const data = msg?.data;
        if (!data?.s) return;
        const base = String(data.s).toLowerCase().replace(/usdt$/, '');
        const price = parseFloat(data.c);
        if (!Number.isNaN(price)) {
          this.prices.set(base, price);
          this.onUpdate?.();
        }
      } catch {
        /* ignore */
      }
    });
    ws.on('close', () => this.scheduleBinanceReconnect());
    ws.on('error', () => ws.close());
  }

  private scheduleBinanceReconnect(): void {
    if (this.binanceSymbols.length === 0) return;
    setTimeout(() => this.connectBinance(), this.binanceBackoff);
    this.binanceBackoff = Math.min(this.binanceBackoff * 2, 30000);
  }

  private async snapshotBinance(): Promise<void> {
    if (this.binanceSymbols.length === 0) return;
    try {
      const syms = this.binanceSymbols.map((s) => `${s.toUpperCase()}USDT`);
      const url =
        'https://api.binance.com/api/v3/ticker/price?symbols=' +
        encodeURIComponent(JSON.stringify(syms));
      const res = await fetch(url);
      if (!res.ok) return;
      const list = (await res.json()) as { symbol: string; price: string }[];
      for (const t of list) {
        const base = t.symbol.toLowerCase().replace(/usdt$/, '');
        const p = parseFloat(t.price);
        if (!Number.isNaN(p)) this.prices.set(base, p);
      }
      this.onUpdate?.();
    } catch {
      /* ignore */
    }
  }

  // ---- Bybit ------------------------------------------------------------

  private connectBybit(): void {
    this.bybitWs?.removeAllListeners();
    this.bybitWs?.close();
    this.bybitWs = null;
    if (this.bybitSymbols.length === 0) return;

    const ws = new WebSocket('wss://stream.bybit.com/v5/public/spot');
    this.bybitWs = ws;

    ws.on('open', () => {
      const args = this.bybitSymbols.map((s) => `tickers.${s.toUpperCase()}USDT`);
      ws.send(JSON.stringify({ op: 'subscribe', args }));
    });
    ws.on('message', (raw) => {
      this.bybitBackoff = 1000;
      try {
        const msg = JSON.parse(raw.toString());
        if (typeof msg?.topic !== 'string' || !msg.topic.startsWith('tickers.'))
          return;
        const d = msg.data;
        if (!d?.symbol) return;
        const base = String(d.symbol).toLowerCase().replace(/usdt$/, '');
        const price = parseFloat(d.lastPrice);
        if (!Number.isNaN(price)) {
          this.prices.set(base, price);
          this.onUpdate?.();
        }
      } catch {
        /* ignore */
      }
    });
    ws.on('close', () => this.scheduleBybitReconnect());
    ws.on('error', () => ws.close());
  }

  private scheduleBybitReconnect(): void {
    if (this.bybitSymbols.length === 0) return;
    setTimeout(() => this.connectBybit(), this.bybitBackoff);
    this.bybitBackoff = Math.min(this.bybitBackoff * 2, 30000);
  }

  private async snapshotBybit(): Promise<void> {
    if (this.bybitSymbols.length === 0) return;
    try {
      const res = await fetch(
        'https://api.bybit.com/v5/market/tickers?category=spot',
      );
      if (!res.ok) return;
      const body = (await res.json()) as {
        result?: { list?: { symbol: string; lastPrice: string }[] };
      };
      const wanted = new Set(
        this.bybitSymbols.map((s) => `${s.toUpperCase()}USDT`),
      );
      for (const t of body.result?.list ?? []) {
        if (!wanted.has(t.symbol)) continue;
        const base = t.symbol.toLowerCase().replace(/usdt$/, '');
        const p = parseFloat(t.lastPrice);
        if (!Number.isNaN(p)) this.prices.set(base, p);
      }
      this.onUpdate?.();
    } catch {
      /* ignore */
    }
  }
}

function eq(a: string[], b: string[]): boolean {
  return a.length === b.length && a.every((v, i) => v === b[i]);
}
