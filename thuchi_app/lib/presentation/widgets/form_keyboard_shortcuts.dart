import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Define Intents
class SaveIntent extends Intent { const SaveIntent(); }
class CancelIntent extends Intent { const CancelIntent(); }
class DeleteIntent extends Intent { const DeleteIntent(); }

/// A reusable widget to provide standard keyboard shortcuts
/// Ctrl+S / Cmd+S: Save
/// Esc: Cancel/Back
/// Delete: Delete (optional)
class FormKeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  const FormKeyboardShortcuts({
    super.key,
    required this.child,
    this.onSave,
    this.onCancel,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        if (onSave != null)
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SaveIntent(),
        if (onCancel != null)
          LogicalKeySet(LogicalKeyboardKey.escape): const CancelIntent(),
        if (onDelete != null)
           LogicalKeySet(LogicalKeyboardKey.delete): const DeleteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          if (onSave != null)
            SaveIntent: CallbackAction<SaveIntent>(
              onInvoke: (_) {
                onSave!();
                return null;
              },
            ),
          if (onCancel != null)
            CancelIntent: CallbackAction<CancelIntent>(
              onInvoke: (_) {
                onCancel!();
                return null;
              },
            ),
          if (onDelete != null)
            DeleteIntent: CallbackAction<DeleteIntent>(
              onInvoke: (_) {
                onDelete!();
                return null;
              },
            ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
