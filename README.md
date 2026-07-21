# Alarm

A Flutter alarm clock & timer app for Android and iOS, built for reliability: alarms are designed to ring through Do Not Disturb / silent mode, support flexible repeat schedules (including "every other week"), and keep ringing even if the app was killed.

## Features

- Multiple independent alarms, each with its own label, sound, vibration and snooze duration.
- Repeat modes: never, daily, on selected weekdays, or **every other week** on selected weekdays.
- Alarms ring at full, enforced volume through Android's Do Not Disturb mode, using a full-screen alarm UI even when the device is locked.
- Countdown timers, multiple running at once, each backed by a real scheduled system alarm so it still rings if the app is backgrounded.
- Light / dark / system theme.
- Dutch and English UI (system, or pick one explicitly in Settings).
- A Settings screen with shortcuts to the Android permissions that matter most for alarms actually firing: notifications, exact alarms, Do Not Disturb access, and battery-optimization exemption.

## Reliability notes

Getting an alarm to reliably ring is mostly an OS-permissions problem, not a code problem:

- **Android**: alarms use the `alarm` package, which schedules via `AlarmManager` + a foreground service and plays audio on the `STREAM_ALARM` channel (exempt from Do Not Disturb by default). The Settings screen links directly to the Do Not Disturb access, exact-alarm, and battery-optimization system screens, since Android requires the user to grant these manually.
- **iOS**: truly ringing through the mute switch and Focus/Do Not Disturb requires Apple's **Critical Alerts** entitlement, which only Apple can grant per app (a manual request through Apple Developer support — not something achievable purely in code). Without it, alarms fall back to **Time Sensitive** notifications, which can still break through most Focus modes but not the hardware mute switch.

## Getting started

```bash
flutter pub get
flutter gen-l10n   # regenerates lib/l10n/gen from lib/l10n/*.arb (also runs automatically on `pub get`)
flutter analyze
flutter test
flutter run
```

### Android signing for local release builds

Release builds look for `android/key.properties` (git-ignored) pointing at a keystore:

```properties
storeFile=release.jks
storePassword=...
keyAlias=...
keyPassword=...
```

Without that file, release builds fall back to debug signing so `flutter build apk --release` still works locally without any setup.

## CI/CD

- **`.github/workflows/test.yml`** — runs on every push/PR to `main`: `flutter analyze` + `flutter test`.
- **`.github/workflows/release.yml`** — runs on pushing a `vX.Y.Z` tag (or manually via workflow dispatch): builds signed, split-per-ABI release APKs and attaches them to a GitHub Release. It expects these repository secrets:
  - `ANDROID_KEYSTORE_BASE64` — base64-encoded release keystore file.
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`

## Project structure

```
lib/
  models/       Alarm, RepeatRule (incl. the biweekly logic), TimerSession, AppSettings
  services/      OS alarm scheduling, local storage, permissions
  providers/     Riverpod state (alarms, timers, settings)
  screens/       Alarms, Timer, Settings, and the full-screen ringing UI
  widgets/       Shared UI pieces (weekday picker, formatting helpers)
  l10n/          ARB translation source files (English is the template)
test/
  unit/          Pure logic: repeat-rule occurrence calculation, model (de)serialization
  widget/        Screen-level behavior, with fakes standing in for platform plugins
```
