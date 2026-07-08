import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/app.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/security/device_auth.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        // The only place the real platform authenticator is constructed;
        // everything else depends on IDeviceAuth (tests inject fakes).
        deviceAuthProvider.overrideWithValue(LocalAuthDeviceAuth()),
      ],
      child: const LedgerlyApp(),
    ),
  );
}
