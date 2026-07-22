// Shapes synced from the Flutter app. Kept in sync with the Dart models.

export type AlertDirection = 'above' | 'below';
export type AlertDenom = 'usd' | 'token';

export interface PriceAlert {
  id: string;
  symbol: string; // lowercase base, e.g. "btc"
  targetPrice: number;
  direction: AlertDirection;
  enabled: boolean;
}

export interface Holding {
  symbol: string; // lowercase base
  amount: number;
}

export interface PortfolioAlert {
  id: string;
  denom: AlertDenom;
  denomSymbol?: string | null; // lowercase base when denom === 'token'
  targetAmount: number;
  direction: AlertDirection;
  enabled: boolean;
}

/** Everything one device wants evaluated, synced from the app. */
export interface AlertBundle {
  priceAlerts: PriceAlert[];
  holdings: Holding[];
  portfolioAlerts: PortfolioAlert[];
}

/** A device registration: FCM token + its alert bundle + trigger state. */
export interface DeviceRecord {
  token: string; // FCM registration token (the id)
  bundle: AlertBundle;
  // Edge-trigger memory: which alert ids are currently "triggered" so we only
  // notify once per crossing and re-arm when the value crosses back.
  triggered: Record<string, boolean>;
  updatedAt: number;
}

/** Symbols this device needs prices for (holdings + all alert symbols). */
export function symbolsForBundle(b: AlertBundle): Set<string> {
  const s = new Set<string>();
  for (const a of b.priceAlerts) s.add(a.symbol.toLowerCase());
  for (const h of b.holdings) s.add(h.symbol.toLowerCase());
  for (const pa of b.portfolioAlerts) {
    if (pa.denom === 'token' && pa.denomSymbol) {
      s.add(pa.denomSymbol.toLowerCase());
    }
  }
  return s;
}
