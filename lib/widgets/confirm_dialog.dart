import 'package:flutter/material.dart';

enum ConfirmType { info, warn, danger }

Future<bool> showConfirmDialog(BuildContext context, String message, {ConfirmType type = ConfirmType.warn, String? confirmText}) async {
  final colors = {
    ConfirmType.info: Colors.blue,
    ConfirmType.warn: Colors.orange,
    ConfirmType.danger: Colors.red,
  };
  final icons = {
    ConfirmType.info: Icons.info_outline,
    ConfirmType.warn: Icons.warning_amber_rounded,
    ConfirmType.danger: Icons.delete_outline,
  };
  final labels = {
    ConfirmType.info: 'Confirmar',
    ConfirmType.warn: 'Continuar',
    ConfirmType.danger: 'Eliminar',
  };

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(icons[type], size: 48, color: colors[type]),
      content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: colors[type]),
          child: Text(confirmText ?? labels[type]!),
        ),
      ],
    ),
  );
  return result ?? false;
}
