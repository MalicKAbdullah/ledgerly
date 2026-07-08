import 'dart:convert';
import 'dart:typed_data';

import 'package:core_storage/core_storage.dart';
import 'package:ledgerly/src/core/clock.dart';
import 'package:ledgerly/src/core/security/device_auth.dart';
import 'package:ledgerly/src/core/security/key_derivation.dart';
import 'package:ledgerly/src/core/storage/vault_file.dart';
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/invoices/models/payment.dart';

/// In-memory [ISecureStorage] — no platform channels.
final class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> store = <String, String>{};

  @override
  Future<void> write({required String key, required String value}) async {
    store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => store[key];

  @override
  Future<void> delete({required String key}) async {
    store.remove(key);
  }

  @override
  Future<void> deleteAll() async => store.clear();

  @override
  Future<Map<String, String>> readAll() async => Map.of(store);
}

/// In-memory [IVaultFile].
final class FakeVaultFile implements IVaultFile {
  Uint8List? bytes;
  int writeCount = 0;

  @override
  Future<Uint8List?> read() async => bytes;

  @override
  Future<void> write(Uint8List bytes) async {
    this.bytes = Uint8List.fromList(bytes);
    writeCount++;
  }
}

/// Scriptable [IDeviceAuth] — flip [available] / [authResult] per test, or
/// set [onAuthenticate] to control timing (e.g. via a Completer).
final class FakeDeviceAuth implements IDeviceAuth {
  FakeDeviceAuth({this.available = true, this.authResult = true});

  bool available;
  bool authResult;
  int authCalls = 0;
  String? lastReason;
  Future<bool> Function()? onAuthenticate;

  @override
  Future<bool> canAuthenticate() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    authCalls++;
    lastReason = reason;
    final handler = onAuthenticate;
    if (handler != null) return handler();
    return authResult;
  }
}

/// Deterministic, fast [IKeyDerivation] — no Argon2id in unit tests.
/// Different passphrases or salts yield different 32-byte keys.
final class FakeKeyDerivation implements IKeyDerivation {
  @override
  Future<Uint8List> deriveKey({
    required String passphrase,
    required Uint8List salt,
  }) async {
    final seed = utf8.encode(passphrase);
    final key = Uint8List(32);
    for (var i = 0; i < key.length; i++) {
      final p = seed.isEmpty ? 0 : seed[i % seed.length];
      final s = salt.isEmpty ? 0 : salt[i % salt.length];
      key[i] = (p * 31 + s * 17 + i * 7) & 0xFF;
    }
    return key;
  }
}

/// Manually advanced [Clock].
final class FakeClock implements Clock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime(2026, 7, 1, 9);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);
}

// -- Sample data builders ---------------------------------------------------

Client makeClient({
  String id = 'client-1',
  String name = 'Ada Lovelace',
  String company = 'Analytical Engines Ltd',
}) {
  return Client(
    id: id,
    name: name,
    company: company,
    email: 'ada@example.com',
    address: '12 Byron Terrace, London',
    createdAt: DateTime(2026, 1, 10),
  );
}

Invoice makeInvoice({
  String id = 'inv-1',
  String number = 'INV-2026-0001',
  String clientId = 'client-1',
  String currency = 'USD',
  DateTime? issueDate,
  DateTime? dueDate,
  List<LineItem>? items,
  int taxRateBp = 0,
  DiscountType discountType = DiscountType.none,
  int discountValue = 0,
  InvoiceStatus status = InvoiceStatus.draft,
  List<Payment> payments = const <Payment>[],
  InvoiceTemplateId template = InvoiceTemplateId.classic,
  DateTime? createdAt,
  DateTime? sentAt,
  DateTime? paidAt,
  String notes = '',
}) {
  return Invoice(
    id: id,
    number: number,
    clientId: clientId,
    currency: currency,
    issueDate: issueDate ?? DateTime(2026, 6, 1),
    dueDate: dueDate ?? DateTime(2026, 6, 15),
    items:
        items ??
        const [
          LineItem(
            id: 'item-1',
            description: 'Design work',
            quantityMilli: 1000,
            unitPriceMinor: 10000,
          ),
        ],
    taxRateBp: taxRateBp,
    discountType: discountType,
    discountValue: discountValue,
    notes: notes,
    status: status,
    payments: payments,
    template: template,
    createdAt: createdAt ?? DateTime(2026, 6, 1, 9),
    sentAt: sentAt,
    paidAt: paidAt,
  );
}

Payment makePayment({
  String id = 'pay-1',
  DateTime? date,
  int amountMinor = 5000,
  PaymentMethod method = PaymentMethod.bankTransfer,
  String note = '',
}) {
  return Payment(
    id: id,
    date: date ?? DateTime(2026, 6, 10),
    amountMinor: amountMinor,
    method: method,
    note: note,
  );
}
