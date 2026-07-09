<div align="center">

# 📄 Ledgerly

### Freelance invoicing, done right.

Professional invoices, payments, and expenses — private, offline, and yours.

![License](https://img.shields.io/badge/License-MIT-4F46E5?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-4F46E5?style=flat-square)
![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-027DFD?style=flat-square&logo=flutter)
![Privacy](https://img.shields.io/badge/Data-Offline%20%26%20Encrypted-34D399?style=flat-square)
![Trackers](https://img.shields.io/badge/Trackers-0-34D399?style=flat-square)

</div>

> ### 🔒 Private by design
> Ledgerly works **completely offline**. Your clients, invoices, and earnings are **encrypted on your device and never leave it** — no account, no servers, no analytics. Your business is nobody else's business.

Ledgerly turns the admin side of freelancing into a few taps: send a polished invoice, record a payment, track an expense, and always know exactly where you stand — no subscription, no cloud, no data mining.

## ✨ Features

**Invoices that look the part**
- Auto-numbered invoices with line items, tax, and discounts
- **Three professional PDF templates** with your logo and a "PAID" stamp
- Share as PDF straight from the app

**Get paid, stay on top**
- Record full or **partial payments** and track the balance due
- **Estimates & quotes** that convert to an invoice in one tap
- **Recurring invoices** that generate themselves on schedule

**Know your numbers**
- Track **expenses** and see real **profit** — not just revenue
- Dashboard with outstanding, overdue, and paid-this-month at a glance
- Client statements and CSV export

**Peace of mind**
- **Biometric app lock** (fingerprint / face) — prompts automatically every time Ledgerly opens, with a graceful fallback (your data stays encrypted at rest) on devices with no biometrics or screen lock set up
- **Encrypted backup & restore** — a passphrase-protected file you control

## 💰 Money done right

Ledgerly never uses floating-point for money. Every amount is stored as exact integer minor units (cents) with its currency, so totals **always add up** — no rounding surprises on the invoice your client receives.

## 🔒 Privacy & Security

- **Offline-only.** No network code, nothing to leak.
- **Encrypted at rest.** All data lives in a single file encrypted with **AES-256-GCM**; the key is generated on-device and held in the platform keystore (Android Keystore / iOS Keychain).
- **Your backups, your key.** Backups are encrypted with a separate passphrase only you know.
- **No accounts, no telemetry, no ads.**

## 📸 Screenshots

| Dashboard | Invoice | PDF templates | Expenses |
| :---: | :---: | :---: | :---: |
| _coming soon_ | _coming soon_ | _coming soon_ | _coming soon_ |

## 🚀 Getting Started

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel) and Android Studio / Xcode.

```sh
# 1. Clone
git clone https://github.com/MalicKAbdullah/ledgerly.git
cd ledgerly

# 2. Install dependencies (also fetches secure-suite-core)
flutter pub get

# 3. Run on a connected device or emulator
flutter run
```

**Build a release APK:**

```sh
flutter build apk --release
```

Run the checks the way CI does:

```sh
flutter analyze
flutter test
```

## 🧱 Built With

- **Flutter** & **Dart** — one codebase, Android & iOS
- **Riverpod** (state) · **go_router** (navigation) · **pdf** + **printing** (documents) · **fl_chart** (dashboard)
- [**secure-suite-core**](https://github.com/MalicKAbdullah/secure-suite-core) — shared encryption, storage & design system

## 📄 License

[MIT](LICENSE) © 2026 Abdullah Malik — part of the [Secure Suite](https://github.com/MalicKAbdullah/secure-suite-core).
