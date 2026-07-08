import 'package:flutter/material.dart';

/// How an imported backup is applied.
enum ImportMode { merge, replace }

/// Passphrase prompt used when opening a backup file.
Future<String?> promptBackupPassphrase(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Backup passphrase'),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'Passphrase for this file'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Open'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Shows what the backup contains and asks how to apply it.
Future<ImportMode?> showImportPreviewDialog(
  BuildContext context, {
  required int clientCount,
  required int invoiceCount,
}) {
  String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
  return showDialog<ImportMode>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restore backup'),
      content: Text(
        'This backup contains ${plural(clientCount, 'client')} and '
        '${plural(invoiceCount, 'invoice')}.\n\n'
        'Merge keeps your current data and adds the backup (on conflicts '
        'the newer version wins). Replace overwrites everything on this '
        'device — including your business profile — with the backup.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ImportMode.replace),
          child: const Text('Replace'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ImportMode.merge),
          child: const Text('Merge'),
        ),
      ],
    ),
  );
}
