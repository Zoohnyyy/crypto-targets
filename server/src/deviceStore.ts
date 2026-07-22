import { promises as fs } from 'node:fs';
import path from 'node:path';
import { config } from './config.js';
import type { AlertBundle, DeviceRecord } from './types.js';

/**
 * Persists device records (FCM token -> alert bundle + trigger state) to a JSON
 * file. Simple and dependency-free; fine for a personal deployment. Swap for a
 * real DB if this ever serves many users.
 */
export class DeviceStore {
  private devices = new Map<string, DeviceRecord>();
  private saveTimer: NodeJS.Timeout | null = null;

  async load(): Promise<void> {
    try {
      const raw = await fs.readFile(config.dataFile, 'utf8');
      const arr = JSON.parse(raw) as DeviceRecord[];
      for (const d of arr) this.devices.set(d.token, d);
      console.log(`[store] loaded ${this.devices.size} device(s)`);
    } catch {
      console.log('[store] no existing data file; starting empty');
    }
  }

  all(): DeviceRecord[] {
    return [...this.devices.values()];
  }

  /** Upsert a device's alert bundle, preserving trigger memory where possible. */
  upsert(token: string, bundle: AlertBundle): DeviceRecord {
    const existing = this.devices.get(token);
    const record: DeviceRecord = {
      token,
      bundle,
      triggered: existing?.triggered ?? {},
      updatedAt: Date.now(),
    };
    this.devices.set(token, record);
    this.scheduleSave();
    return record;
  }

  remove(token: string): void {
    if (this.devices.delete(token)) this.scheduleSave();
  }

  markTriggered(token: string, alertId: string, value: boolean): void {
    const d = this.devices.get(token);
    if (!d) return;
    d.triggered[alertId] = value;
    this.scheduleSave();
  }

  private scheduleSave(): void {
    if (this.saveTimer) return;
    this.saveTimer = setTimeout(() => {
      this.saveTimer = null;
      void this.save();
    }, 1000);
  }

  private async save(): Promise<void> {
    try {
      await fs.mkdir(path.dirname(config.dataFile), { recursive: true });
      await fs.writeFile(
        config.dataFile,
        JSON.stringify(this.all(), null, 2),
        'utf8',
      );
    } catch (e) {
      console.error('[store] save failed', e);
    }
  }
}
