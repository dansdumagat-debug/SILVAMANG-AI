import 'package:flutter/material.dart';

Future<bool> confirmDeleteOfflineMaps(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete downloaded maps?'),
        content: const Text(
          'Saved maps do not expire. Delete all downloaded maps from this device? '
          'You will need internet to download them again. Your scan and transect records will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep maps'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete maps'),
          ),
        ],
      ),
    ) ??
    false;
