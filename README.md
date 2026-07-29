# Crypto Targets

A Flutter (Android) app showing **real-time cryptocurrency prices** with:

- ⚡ **Live streaming prices** from Binance WebSocket (sub-second updates in-app), plus Bybit for coins Binance doesn't list (e.g. HYPE)
- 🏠 **Home screen widgets** — one for up to 4 watchlist coins, one for your total portfolio value, both refreshed in the background
- ⭐ **Customizable watchlist** — search and add any Binance USDT pair, reorder, remove
- 📊 **Change over 24h / 7d / 30d / 90d** on every coin, with 1D/1W/1M/3M charts
- 💼 **Portfolio tracking** — holdings, live total value, and pull-to-refresh
- 🔔 **Price alerts** — get a local notification when a coin crosses a target price

## Architecture

| Concern | Approach |
|---|---|
| Real-time prices (app open) | Binance combined WebSocket ticker stream, single socket, auto-reconnect |
| Prices (app closed / widget) | REST snapshot fetched by a `WorkManager` periodic task (~15 min, Android minimum) |
| Watchlist & alerts storage | `shared_preferences` |
| Home widgets | `home_widget` package + native `CryptoWidgetProvider` / `PortfolioWidgetProvider` (Kotlin) |
| Notifications | `flutter_local_notifications`, fired from the background task |
| State management | `provider` |

### Why 15-minute background updates?

Android's `WorkManager` enforces a **15-minute minimum** interval for periodic background work, and the OS throttles more aggressive attempts to protect battery. So:

- **While the app is open**, prices update in real time via WebSocket (as fast as the market ticks).
- **The home widget and price-alert checks** run in the background roughly every 15 minutes. This is the reliable, battery-friendly ceiling without running a backend server.

If you later want *instant* alerts while the app is closed, the upgrade path is a small backend that watches prices 24/7 and sends FCM push notifications.

## Project layout

```
lib/
  main.dart                     App entry, theme, background/task init
  models/
    coin.dart                   Coin + PriceTick models
    price_alert.dart            PriceAlert model
  services/
    binance_service.dart        WebSocket stream + REST snapshots
    storage_service.dart        Persistence + coin catalog
    notification_service.dart   Local notifications
    widget_service.dart         Push data to the home widget
    background_service.dart     WorkManager periodic task (widget + alerts)
  providers/
    app_state.dart              Central ChangeNotifier state
  ui/
    home_screen.dart            Live watchlist
    add_coin_screen.dart        Search + add coins
    alerts_screen.dart          Manage price alerts
    coin_tile.dart, format.dart UI helpers
android/                        Native Android config + widget provider
```

## Setup & run

> Requires the **Flutter SDK**. Your machine already has Android Studio, the
> Android SDK, and JDK 21 — only Flutter needs installing. See
> `SETUP_WINDOWS.md` for step-by-step install instructions.

Once Flutter is installed and on your PATH:

```bash
cd c:\Flutter\crypto-prices

# One-time: regenerate platform boilerplate (gradlew, wrapper jar) WITHOUT
# overwriting the code in lib/ or the android/ config already committed.
flutter create . --platforms=android

flutter pub get

# Plug in an Android phone (USB debugging on) or start an emulator, then:
flutter run                 # debug
flutter run --release       # release build (smoother, real-world perf)
```

### Adding a widget to your home screen

1. Install and open the app once (so it writes initial data).
2. Long-press your Android home screen → **Widgets**.
3. Find **Crypto Targets** — there are two widgets to choose from:
   - **Crypto Targets — Prices**: your first 4 watchlist coins.
   - **Crypto Targets — Portfolio**: total portfolio value, its 24h change, and your largest holdings.
4. Drag either (or both) to the home screen; they refresh automatically.

### Notifications

On first launch (Android 13+) the app requests notification permission. Grant
it so price alerts can be delivered. Create alerts via the 🔔 icon.

## Notes & tuning

- **Data source:** Binance public market data — no API key required. Prices are
  quoted against **USDT** (≈ USD).
- **Widget refresh cadence:** controlled in `background_service.dart`
  (`Duration(minutes: 15)`) and `crypto_widget_info.xml`
  (`updatePeriodMillis`). 15 min is the practical minimum.
- **Battery savers:** aggressive OEM battery managers (Xiaomi, Samsung, etc.)
  may delay background work. If the widget seems stale, exclude the app from
  battery optimization in Android settings.
- **Release signing:** `android/app/build.gradle.kts` uses the debug signing
  config so `flutter run --release` works immediately. Add your own keystore
  before publishing to the Play Store.
