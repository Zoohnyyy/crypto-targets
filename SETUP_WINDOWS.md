# Windows setup notes

Everything needed to build this app is already installed on this machine. The
only thing that was missing was **PATH configuration** — the tools existed but
weren't on the PATH. This file records the working setup.

## What's installed

| Tool | Location | Version |
|---|---|---|
| Flutter SDK | `C:\flutter\flutter` | 3.44.2 (stable) |
| Dart | bundled with Flutter | 3.12.2 |
| Android Studio | `C:\Program Files\Android\Android Studio` | — |
| Android SDK | `C:\Users\Owner\AppData\Local\Android\Sdk` | platforms 34–36 |
| JDK | `C:\Program Files\Android\Android Studio\jbr` | 21 |
| Git | `C:\Program Files\Git\cmd` | — |

## PATH (already made permanent for your user)

These two entries were added to your **user** `Path` so any new terminal works:

```
C:\flutter\flutter\bin
C:\Program Files\Git\cmd
```

> If a brand-new terminal still can't find `flutter`, sign out/in once (Windows
> reloads PATH on login), or run the commands below which set PATH for the
> current session.

## Building / running (works today)

Open a **new** PowerShell window and run:

```powershell
# (Only needed if this session's PATH isn't picked up yet)
$env:Path = "C:\flutter\flutter\bin;C:\Program Files\Git\cmd;$env:Path"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"

cd C:\flutter\crypto-prices
flutter pub get
flutter build apk --debug      # already verified working
```

## Running on a device

There's currently **no Android device or emulator connected** — `flutter
devices` only shows Windows/Chrome/Edge. To run the app:

### Option A — physical phone (recommended for the widget)
1. On the phone: Settings → About → tap *Build number* 7× to unlock Developer
   options, then enable **USB debugging**.
2. Plug it in via USB, accept the "Allow USB debugging" prompt.
3. `flutter run --release`

### Option B — Android emulator
```powershell
flutter emulators                 # list installed AVDs
flutter emulators --launch <id>   # start one
# or create one in Android Studio → Device Manager
flutter run
```

> The home screen **widget** is best tested on a real phone — emulators support
> widgets but the experience is more representative on device.

## Installing the built APK directly

```powershell
$adb = "C:\Users\Owner\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb install -r C:\flutter\crypto-prices\build\app\outputs\flutter-apk\app-debug.apk
```
