# Ledgerly

A privacy-first, offline-only freelance invoice & client manager. Part of the
`secure_suite` monorepo. All data lives encrypted on the device; there are no
network calls and no analytics.

**v1.2** — encrypted backup & restore, expenses & profit tracking, estimates
/ quotes with one-tap conversion, recurring invoices with catch-up, and a
one-time onboarding intro.

**v1.1** — payments & partial payments, three PDF templates, business logo,
client statements, CSV export, and a full visual refresh on the shared
indigo-accented suite theme (light + dark).

## Features

- **Business profile** — name, business name, address, email, tax ID, default
  currency, default tax rate, invoice number prefix, and an optional **logo**
  (downscaled to ≤512 px and stored inside the encrypted vault).
- **Clients** — full CRUD with search; client detail shows their invoices plus
  total billed / outstanding (per currency, using open balances), and a
  shareable **statement PDF**.
- **Invoices** — auto-numbered per year (`INV-2026-0001`, max+1 semantics),
  line items with fractional quantities (e.g. 1.5 hours), per-invoice tax
  rate, percent or fixed discount, notes/payment terms, per-invoice **PDF
  template**.
- **Payments & partial payments** — record payments (date, amount, method,
  note) against an invoice. Balance due = total − payments, never negative;
  overpayment is rejected with validation. The invoice flips to `paid`
  automatically when the balance hits zero; until then it shows a
  "Partially paid X of Y" badge. Long-press a payment to remove it (a settled
  invoice reverts to `sent` if money is owed again).
- **Status lifecycle** — draft → sent → paid with timestamps recorded on each
  transition; `overdue` is *derived* (sent + past due date), never stored.
- **Invoice detail** — hero card with live balance, quick actions (record
  payment, send reminder, duplicate, share PDF), payment history, an
  **activity timeline** (created / sent / payments / paid), and a template
  picker.
- **PDF export** — three A4 templates rendered with `pdf` and shared/printed
  via `printing`:
  - **Classic** — letterhead masthead, double rule, fully ruled table;
  - **Modern** — indigo band header, airy zebra table, tinted balance card;
  - **Minimal** — typographic and monochrome, hairline rules.
  All templates include business + client blocks, invoice meta, line items,
  subtotal/discount/tax/total (plus paid/balance rows when payments exist),
  payment history, notes, logo, a removable "Generated with Ledgerly" footer,
  page numbers, and a **PAID stamp** watermark on settled invoices. Inter is
  embedded, so far more of Unicode renders than the built-in Latin-1 fonts.
  Rendering (~100 ms for a 2-page invoice) runs on a background isolate via
  `compute`, so the UI never janks.
- **Reminders** — one tap builds a friendly reminder message (amount due +
  due date) and opens the system share sheet.
- **CSV export** — share a spreadsheet-ready summary of all invoices
  (number, client, dates, status, currency, total, paid, balance), RFC-4180
  escaped, ISO dates.
- **Estimates / quotes** — own per-year numbering (`EST-2026-0001`,
  independent of the invoice sequence), the *same* line items / tax /
  discount math as invoices (shared calculator), status lifecycle
  draft → sent → accepted / declined with timestamps, and a validity date
  with a **derived Expired** state (never stored). **Convert to invoice** in
  one tap: a draft invoice is created copying client, line items (fresh ids),
  tax, discount, notes and template; the invoice records `estimateId`, the
  estimate flips to accepted and remembers the invoice number. Estimate PDFs
  reuse all three templates with an "ESTIMATE" title, a "VALID UNTIL" date,
  no payments section, and an "Estimate EST-… → Invoice INV-…" note after
  conversion. Reached from the Invoices tab (quote icon).
- **Expenses & profit** — record business costs (date, category with icons:
  supplies / software / travel / fees / other, description, exact `Money`
  amount, optional client link, note) in their own tab: month-grouped list
  with subtotals, category filter chips, add/edit bottom sheet, and CSV
  export via the share sheet. The dashboard adds **Expenses this month** and
  **Profit this month = paid revenue − expenses** cards (profit can go
  negative and is highlighted when it does).
- **Recurring invoices** — templates with client, line items, tax/discount,
  PDF template, notes, and a schedule: **weekly**, **monthly on day N**, or
  **every N months on day N**; a start date, optional end date, "due in N
  days", and pause/resume. Managed from the Invoices tab (⟳ icon) or via
  **"Make recurring"** on any invoice (pre-fills everything).
- **Dashboard** — outstanding (open balances), overdue count + amount,
  paid-this-month, expenses-this-month, profit-this-month, and a 6-month
  **revenue vs expenses** bar chart (`fl_chart`).
- **Encrypted backup & restore** — see the backup guide below.
- **Onboarding** — a skippable 3-page intro shown exactly once; an empty
  dashboard then guides you to set up the business profile first.
- **Nice touches** — duplicate invoice/estimate, swipe an invoice to mark it
  paid, status filter chips, semantic status badges, animated status changes,
  empty states everywhere, system light/dark theme.

## Recurring invoices — catch-up semantics

Ledgerly has no background process; recurring invoices are **materialized
when the app opens** (a pure `RecurringMaterializer` run before the first
frame):

- Every period due since the last run is generated — if the app was closed
  past several periods, *each* missed period becomes a real draft invoice
  with the **correct historical issue date** and the next sequential number
  (per-year numbering restarts across a year boundary, exactly as manual
  invoices do). A snackbar reports "N invoices generated from recurring
  schedules".
- Month-day anchoring: "monthly on the 31st" clamps to short months
  (Jan 31 → Feb 28, or Feb 29 in leap years) while **preserving the anchor**,
  so March lands back on the 31st.
- The schedule stops at the optional end date (inclusive) and never runs
  while paused. **Resuming skips periods missed while paused** — generation
  restarts at the first occurrence after today, so no surprise catch-up.
- A safety cap (60 invoices per template per run) guards against corrupt
  dates.

## Backup guide (`.lybackup`)

Settings → **Backup & restore**.

- **Export** — choose a backup passphrase (min 8 chars; it is *not* your app
  lock and is never stored). The whole ledger — profile, clients, invoices,
  estimates, expenses, recurring templates — is encrypted and handed to the
  system share sheet as `ledgerly-YYYY-MM-DD.lybackup`.
- **Format** — a JSON envelope
  `{formatVersion, app, appVersion, createdAt, clientCount, invoiceCount,
  salt, nonce, ciphertext}`; the ciphertext is the AppData JSON encrypted
  with **AES-256-GCM** under an **Argon2id** key derived from the
  passphrase. Files from newer format versions are rejected with a clear
  message; wrong passphrase and tampering are indistinguishable by design
  (GCM authentication).
- **Import** — pick a file → enter its passphrase → a preview shows the
  client/invoice counts → choose:
  - **Merge** — by id; records only in the backup are added, id clashes keep
    whichever side was touched more recently (invoice activity timestamps,
    estimate status timestamps, a recurring template's `nextRunDate`); ties
    keep the device's copy, and the business profile is never overwritten.
  - **Replace** — the backup becomes the entire ledger, profile included.
- Backups created by older app versions load fine: every field added after
  v1.1 is optional with a sensible default (fixture-tested).

## Money is done right

`Money` (`lib/src/core/money/money.dart`) is an immutable value type storing
**integer minor units** (cents) plus an ISO 4217 currency code. Doubles are
never used for money — parsing, arithmetic, and formatting are all exact
integer operations (chart bar heights are the only doubles, display-only).

- **Rounding policy: half-up, away from zero** (0.5¢ → 1¢, −0.5¢ → −1¢),
  applied at every division: per line item, then on the discount, then on the
  tax. The printed rows therefore always sum exactly to the printed total.
- Rates (tax, percent discount) are integers in **basis points** (750 = 7.5%).
- Quantities are integers in **thousandths** (1500 = 1.5 hours).
- Currency minor-unit exponents are respected (USD 2, JPY 0, KWD 3, …).

`InvoiceCalculator` computes subtotal → discount (clamped to [0, subtotal]) →
tax on the discounted base → total, as pure functions. `PaymentMath` layers
payments on top: exact integer sums, balance clamped at zero, and a settled
invoice's balance is *defined* as zero (so legacy "marked paid" invoices
without payment records stay consistent).

**Dashboard multi-currency policy:** stats are computed in the profile's
default currency only; invoices in other currencies are excluded and surfaced
as a count, so no fake FX conversion ever happens. (Client detail and
statements show exact per-currency totals instead.)

## Architecture

Feature-first, deliberately lean — no DDD ceremony:

```
lib/
  main.dart                     # runApp only
  src/
    app.dart                    # MaterialApp.router + suite theme (indigo)
    core/
      money/money.dart          # Money value type + currency metadata
      data/                     # AppData snapshot + AsyncNotifier (mutations)
      storage/                  # IVaultFile, DataKeyStore, LedgerStore
      providers.dart            # Riverpod wiring (overridable for tests)
      router.dart               # go_router: shell with 5 tabs + editors
      security/                 # device auth + Argon2id key derivation
      share_service.dart        # system share sheet (text / CSV)
      widgets/                  # StatusChip, AsyncView
    features/
      dashboard/                # DashboardStats (pure) + screen + chart
      invoices/
        models/                 # Invoice, LineItem, Payment, template enum
        services/               # calculator, payments, numbering, CSV,
                                #   reminder, PDF (pdf/ = 3 templates)
        screens/ widgets/       # list, editor, detail + payment sheet,
                                #   timeline, history
      estimates/                # Estimate model, math/PDF services, screens
      expenses/                 # Expense model, stats/CSV services, screens
      recurring/                # RecurringTemplate + pure materializer
      backup/                   # encrypted .lybackup codec + screen
      onboarding/               # one-time intro gate + pages
      clients/                  # model + screens + statement PDF service
      settings/                 # BusinessProfile, logo service, settings UI
      shell/                    # bottom navigation shell
```

State: a single `AsyncNotifierProvider<AppDataNotifier, AppData>` holds the
decrypted snapshot; every mutation produces a new immutable `AppData`, updates
state, and persists. Shared packages (`core_crypto`, `core_storage`,
`core_theme`, `core_ui`) are reused via path dependencies.

## Security model

- On first launch a random **256-bit data key** is generated
  (`Random.secure`) and stored in the platform keychain/keystore via
  `core_storage`'s `flutter_secure_storage` wrapper.
- The entire app state — including the logo image — is serialized to JSON,
  encrypted with **AES-256-GCM** (`core_crypto`'s `CipherService`), and
  written to a single file (`ledgerly.vault`) in the app documents directory.
  Writes are atomic (temp file + rename).
- Repository layer: load–decrypt–cache on start, encrypt–write on every
  mutation. GCM authentication means tampered or foreign-key ciphertext fails
  loudly.
- File system and secure storage sit behind small interfaces (`IVaultFile`,
  `ISecureStorage`), so unit tests inject in-memory fakes — no platform
  channels in tests.
- Offline-only: no network calls anywhere. Sharing (PDF/CSV/reminders) goes
  through the system share sheet, so nothing leaves the device unless the
  user picks a destination.

## Run

```sh
flutter pub get
flutter run            # iOS or Android
```

Launcher icons are generated with `dart run flutter_launcher_icons`.

## Test

```sh
dart analyze           # zero issues
flutter test           # 237 tests
```

Coverage highlights: exhaustive `Money` tests (parsing, arithmetic, the
rounding matrix, formatting), `InvoiceCalculator` tax × discount matrix, a
`PaymentMath` matrix (balances, clamping, overpayment validation, legacy
paid invoices), notifier payment flows against the real encrypted store
(record → auto-paid, overpayment rejection, removal reverting status),
per-year invoice numbering, status/overdue logic, `DashboardStats` (incl.
year-boundary buckets and multi-currency exclusion), encrypted store
round-trip + tamper detection with fakes, PDF byte generation for **all
three templates** (unicode client names, 60-item multi-page invoices, logo,
PAID stamp, footer toggle), client statement PDFs, CSV escaping, logo
downscaling, and widget tests for the dashboard, invoice editor, the invoice
detail payment flow, and onboarding.

v1.2 additions: backup codec (documented envelope, round-trip incl. unicode,
ciphertext leaks nothing, wrong passphrase, tampered ciphertext, garbage
input, future-version gate, merge both directions + tie semantics), a
**v1.1 state fixture** proving live data loads with defaults for every new
field, `ExpenseStats` month buckets + currency exclusion, expense CSV,
estimate numbering / status–expiry matrix / conversion field mapping /
estimate PDFs for all three templates, and exhaustive `RecurringMaterializer`
date math with a fake clock (Jan 31 → Feb 28/29 clamping with anchor
preservation, catch-up across a year boundary with correct numbering,
endDate stop, pause/resume-skip, runaway cap, cold-start integration).

## Known limitations

- No multi-currency FX conversion on the dashboard (by design — documented
  above); the same policy applies to expenses and profit.
- Recurring invoices are generated on app open only (no background jobs /
  push — offline-only constraint). Numbers are assigned at generation time,
  so a manual invoice created before opening the app can take a number a
  catch-up invoice would otherwise have received (sequences stay gap-free
  and unique either way).
- Backup merge resolves id clashes by "most recent observable activity";
  edits that don't touch any timestamp (e.g. rewording a client note) keep
  the device's copy on a tie. Use Replace to take a backup wholesale.
- PDF text uses the bundled Inter faces: broad Latin/Cyrillic/Greek coverage,
  but right-to-left scripts (Arabic, Hebrew) and CJK are not covered
  (offline constraint: no font downloads).
- Deleting a client deletes their invoices (after an explicit confirmation).
- Removing a payment from a settled invoice reverts it to `sent` (not to
  `draft`), keeping the original `sentAt`.
