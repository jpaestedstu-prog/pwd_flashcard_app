import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import 'accessibility_category_picker.dart';
import 'cloud_sync_error_view.dart';

/// Shared "single text field → submit → wait → success/error" dialog
/// used across the Manage Classes (teacher) and Manage Home Groups
/// (parent) screens. Drives every dialog that runs an async Firestore
/// write on a name string:
///
///   • Create class / Create home group
///   • Rename class / Rename home group
///   • Rename a roster member (classroom or home group)
///   • Add a manual student / Add a manual child
///
/// Replaces the per-screen dialogs that had three reliability bugs:
///   1. Dialog popped *before* the await ran, so transient errors
///      only surfaced as a brief SnackBar that was easy to miss.
///      Result: the user thought the action button was frozen.
///   2. Empty input was silently accepted (the outer code `return`ed
///      without feedback).
///   3. Several call sites leaked their `TextEditingController`.
///
/// The new contract:
///   • The dialog owns its `TextEditingController` and disposes it.
///   • Empty input shows an inline `errorText`; it never pops.
///   • If [initialValue] is provided and the typed text matches it
///     unchanged, tapping the action button closes silently — there's
///     nothing to write. (No misleading "saved!" SnackBar either, since
///     the caller only fires that on a `true` result.)
///   • The submit call runs *inside* the dialog. While in flight, the
///     text field is disabled and the action button shows a spinner.
///   • On success: pops with `true` so the caller can show a
///     confirmation SnackBar.
///   • On failure: stays open, renders a friendly, setup-aware error
///     using the same copy as [CloudSyncErrorView] (via
///     [cloudSyncErrorMessage]). The user can fix the issue and tap
///     the action button again without retyping.
class CloudAwareTextDialog extends ConsumerStatefulWidget {
  /// Dialog title — e.g. "Create class", "Rename class", "Add child".
  final String title;

  /// `labelText` for the input field.
  final String inputLabel;

  /// `hintText` shown when the input is empty.
  final String inputHint;

  /// Action button label — e.g. "Create", "Save", "Add".
  final String submitLabel;

  /// Validation message when the trimmed input is empty.
  final String emptyError;

  /// Optional pre-filled value. When set, this is treated as the
  /// "current" value for rename-style flows: if the user submits the
  /// same text unchanged, [onSubmit] is NOT called and the dialog
  /// pops with `null` (a no-op close) so the caller's success SnackBar
  /// doesn't fire on a non-action.
  final String? initialValue;

  /// Optional helper text shown under the field (e.g. the "A placeholder
  /// profile is created..." explainer used by the add-manual dialogs).
  final String? helperText;

  /// Called when the user taps the action button with a non-empty,
  /// changed name. Throws on failure; the dialog catches and displays
  /// the error inline without popping.
  ///
  /// Exactly one of [onSubmit] / [onSubmitWithAccessibility] is used: the
  /// latter takes precedence and is the path used by the create-class /
  /// create-home-group dialogs (which also collect an accessibility
  /// category). Plain rename / add-member dialogs keep using [onSubmit].
  final Future<void> Function(String name)? onSubmit;

  /// Like [onSubmit] but also passes the accessibility category the user
  /// picked. When set, [initialAccessibility] must be non-null so the
  /// picker is rendered.
  final Future<void> Function(String name, DisabilityType accessibility)?
      onSubmitWithAccessibility;

  /// When non-null, an [AccessibilityCategoryPicker] is shown under the
  /// name field, seeded with this value.
  final DisabilityType? initialAccessibility;

  const CloudAwareTextDialog({
    super.key,
    required this.title,
    required this.inputLabel,
    required this.inputHint,
    required this.submitLabel,
    required this.emptyError,
    this.onSubmit,
    this.onSubmitWithAccessibility,
    this.initialAccessibility,
    this.initialValue,
    this.helperText,
  }) : assert(
          (onSubmit != null) ^ (onSubmitWithAccessibility != null),
          'Provide exactly one of onSubmit / onSubmitWithAccessibility.',
        ),
        assert(
          onSubmitWithAccessibility == null || initialAccessibility != null,
          'onSubmitWithAccessibility requires initialAccessibility.',
        );

  /// Convenience launcher. Returns `true` when the submit succeeded
  /// (caller can show a confirmation SnackBar), `null` if the user
  /// cancelled, dismissed, or submitted an unchanged [initialValue].
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String inputLabel,
    required String inputHint,
    required String submitLabel,
    required String emptyError,
    Future<void> Function(String name)? onSubmit,
    Future<void> Function(String name, DisabilityType accessibility)?
        onSubmitWithAccessibility,
    DisabilityType? initialAccessibility,
    String? initialValue,
    String? helperText,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CloudAwareTextDialog(
        title: title,
        inputLabel: inputLabel,
        inputHint: inputHint,
        submitLabel: submitLabel,
        emptyError: emptyError,
        onSubmit: onSubmit,
        onSubmitWithAccessibility: onSubmitWithAccessibility,
        initialAccessibility: initialAccessibility,
        initialValue: initialValue,
        helperText: helperText,
      ),
    );
  }

  @override
  ConsumerState<CloudAwareTextDialog> createState() =>
      _CloudAwareTextDialogState();
}

class _CloudAwareTextDialogState extends ConsumerState<CloudAwareTextDialog> {
  late final TextEditingController _controller;
  late DisabilityType _accessibility;
  bool _busy = false;
  String? _validationError;
  Object? _submitError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _accessibility = widget.initialAccessibility ?? DisabilityType.none;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_busy) return;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _validationError = widget.emptyError);
      return;
    }
    // Unchanged rename → no-op close. Caller's success SnackBar will
    // not fire because we pop with null, not true.
    if (widget.initialValue != null && name == widget.initialValue) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = true;
      _validationError = null;
      _submitError = null;
    });
    try {
      final withAccessibility = widget.onSubmitWithAccessibility;
      if (withAccessibility != null) {
        await withAccessibility(name, _accessibility);
      } else {
        await widget.onSubmit!(name);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _submitError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitErr = _submitError;
    return AlertDialog(
      title: Text(widget.title),
      // Scrollable so the optional accessibility picker (6 chips) can't
      // overflow the dialog on a small screen or at a large font scale.
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleSubmit(),
            onChanged: (_) {
              if (_validationError != null) {
                setState(() => _validationError = null);
              }
            },
            decoration: InputDecoration(
              labelText: widget.inputLabel,
              hintText: widget.inputHint,
              errorText: _validationError,
            ),
          ),
          if (widget.helperText != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.helperText!,
              style: AppTypography.bodySmall.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
          ],
          if (widget.initialAccessibility != null) ...[
            const SizedBox(height: 16),
            AccessibilityCategoryPicker(
              selected: _accessibility,
              enabled: !_busy,
              onChanged: (type) => setState(() => _accessibility = type),
            ),
          ],
          if (submitErr != null) ...[
            const SizedBox(height: 16),
            _InlineCloudError(
              error: submitErr,
              onResetDone: () async {
                if (!mounted) return;
                setState(() => _submitError = null);
              },
            ),
          ],
        ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _handleSubmit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}

/// Compact, inline version of [CloudSyncErrorView] tailored for use
/// inside a dialog (no full-screen scaffold, smaller icon, no Retry
/// button — the dialog's own action button IS the retry).
///
/// Reuses [cloudSyncErrorMessage] so the copy stays in lockstep with
/// the full-screen renderer.
class _InlineCloudError extends StatelessWidget {
  final Object error;
  final Future<void> Function() onResetDone;

  const _InlineCloudError({
    required this.error,
    required this.onResetDone,
  });

  @override
  Widget build(BuildContext context) {
    final msg = cloudSyncErrorMessage(error);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: msg.color.withValues(alpha: 0.08),
        border: Border.all(color: msg.color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(msg.icon, color: msg.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  msg.title,
                  style: AppTypography.labelLarge.copyWith(
                    color: msg.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(msg.body, style: AppTypography.bodySmall),
          if (msg.profileId != null) ...[
            const SizedBox(height: 12),
            ResetForThisDeviceButton(
              profileId: msg.profileId!,
              onDone: onResetDone,
            ),
          ],
        ],
      ),
    );
  }
}
