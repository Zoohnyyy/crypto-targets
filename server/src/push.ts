import admin from 'firebase-admin';
import { config } from './config.js';

/** Initialises firebase-admin from the service-account env var. */
export function initFirebase(): void {
  const serviceAccount = JSON.parse(config.firebaseServiceAccount);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('[fcm] firebase-admin initialised');
}

/**
 * Send a data+notification push to one device. Returns false if the token is
 * no longer valid (caller should drop it).
 */
export async function sendPush(
  token: string,
  title: string,
  body: string,
): Promise<boolean> {
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      android: {
        priority: 'high',
        notification: {
          channelId: 'price_alerts',
          priority: 'high',
        },
      },
      data: { title, body },
    });
    return true;
  } catch (e: unknown) {
    const code = (e as { errorInfo?: { code?: string } })?.errorInfo?.code;
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token'
    ) {
      return false; // token dead — caller removes it
    }
    console.error('[fcm] send error', code ?? e);
    return true; // transient; keep the token
  }
}
