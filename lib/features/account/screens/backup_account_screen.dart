import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/sync_status_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Settings entry for **Backup & Link Account**.
///
/// Adds Firebase Auth email/password on top of the anonymous session that
/// already powers cloud sync. After linking, the same uid can be restored
/// on any device by signing in with the email/password — the rehydration
/// pulls every `owner_uid`-stamped Firestore doc back into local Hive.
///
/// Free-tier note: Firebase Auth email/password is unlimited on Spark.
/// No Cloud Functions or Blaze billing required.
///
/// Router-gated to teacher / parent profiles (see `_educatorOnlyRoutes`
/// in [app_router.dart]) so a child profile cannot accidentally link the
/// device's anonymous session to an unrelated email.
class BackupAccountScreen extends ConsumerStatefulWidget {
  const BackupAccountScreen({super.key});

  @override
  ConsumerState<BackupAccountScreen> createState() =>
      _BackupAccountScreenState();
}

class _BackupAccountScreenState extends ConsumerState<BackupAccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _busy = false;
  bool _signInMode = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return _t(context).baEnterEmail;
    final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRe.hasMatch(v)) return _t(context).baValidEmail;
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.length < 8) return _t(context).baPwLength;
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value != _passwordController.text) return _t(context).baPwMismatch;
    return null;
  }

  /// Translate Firebase Auth error codes into messages parents/teachers
  /// can act on. We deliberately do NOT distinguish `user-not-found` from
  /// `wrong-password` to avoid account-enumeration on the sign-in path.
  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return _t(context).baEmailInUse;
      case 'weak-password':
        return _t(context).baWeakPw;
      case 'invalid-email':
        return _t(context).baBadEmail;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return _t(context).baWrongCreds;
      case 'user-disabled':
        return _t(context).baDisabled;
      case 'network-request-failed':
        return _t(context).baOffline;
      case 'too-many-requests':
        return _t(context).baTooMany;
      case 'provider-already-linked':
        return _t(context).baLinkedElsewhere;
      default:
        return _t(context).baSignInFailed(e.code);
    }
  }

  Future<void> _linkAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await FirebaseService.linkAnonymousToEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      AppSnackBar.success(
        context,
        message: _t(context).baLinked(_emailController.text.trim()),
      );
      setState(() {});
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: _friendlyAuthError(e));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await FirebaseService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Pull this uid's profiles + progress + cards back into Hive.
      final sync = ref.read(syncServiceProvider);
      final restored = await sync?.rehydrateFromCloud() ?? 0;

      if (!mounted) return;
      AppSnackBar.success(
        context,
        message: restored == 0
            ? _t(context).baSignedInNone
            : _t(context).baSignedInRestored(restored),
      );
      setState(() => _signInMode = false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: _friendlyAuthError(e));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseService.linkedEmail ?? _emailController.text.trim();
    if (email.isEmpty) {
      AppSnackBar.error(context,
          message: _t(context).baEnterEmailFirst);
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseService.sendPasswordReset(email);
      if (!mounted) return;
      AppSnackBar.success(
        context,
        message: _t(context).baResetSent(email),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(context).baSignOutTitle),
        content: Text(
          _t(context).baSignOutBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(_t(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_t(context).baSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await FirebaseService.signOut();
      if (!mounted) return;
      AppSnackBar.success(context, message: _t(context).baSignedOut);
      setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linked = FirebaseService.hasLinkedAccount;
    final linkedEmail = FirebaseService.linkedEmail;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(_t(context).baTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StatusCard(linked: linked, email: linkedEmail),
          const SizedBox(height: 20),
          if (linked)
            _LinkedAccountActions(
              busy: _busy,
              onPasswordReset: _sendPasswordReset,
              onSignOut: _signOut,
            )
          else
            _LinkForm(
              formKey: _formKey,
              emailController: _emailController,
              passwordController: _passwordController,
              confirmController: _confirmController,
              busy: _busy,
              signInMode: _signInMode,
              passwordVisible: _passwordVisible,
              onTogglePasswordVisible: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
              onToggleMode: () => setState(() => _signInMode = !_signInMode),
              onSubmit: _signInMode ? _signIn : _linkAccount,
              onPasswordReset: _sendPasswordReset,
              validateEmail: _validateEmail,
              validatePassword: _validatePassword,
              validateConfirm: _validateConfirm,
            ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool linked;
  final String? email;
  const _StatusCard({required this.linked, this.email});

  @override
  Widget build(BuildContext context) {
    final color = linked ? AppColors.success : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            linked ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: color,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  linked ? _t(context).baActive : _t(context).baNone,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  linked
                      ? _t(context).baLinkedTo(email ?? _t(context).baUnknownEmail)
                      : _t(context).baLocalOnly,
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool busy;
  final bool signInMode;
  final bool passwordVisible;
  final VoidCallback onTogglePasswordVisible;
  final VoidCallback onToggleMode;
  final VoidCallback onSubmit;
  final VoidCallback onPasswordReset;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;
  final FormFieldValidator<String> validateConfirm;

  const _LinkForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.busy,
    required this.signInMode,
    required this.passwordVisible,
    required this.onTogglePasswordVisible,
    required this.onToggleMode,
    required this.onSubmit,
    required this.onPasswordReset,
    required this.validateEmail,
    required this.validatePassword,
    required this.validateConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            signInMode
                ? _t(context).baSignInRestore
                : _t(context).baCreateBackup,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            signInMode
                ? _t(context).baUseOther
                : _t(context).baPickCreds,
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _t(context).baEmail,
              prefixIcon: const Icon(Icons.email_outlined),
              border: const OutlineInputBorder(),
            ),
            validator: validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            obscureText: !passwordVisible,
            textInputAction:
                signInMode ? TextInputAction.done : TextInputAction.next,
            decoration: InputDecoration(
              labelText: _t(context).baPassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(passwordVisible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
                onPressed: onTogglePasswordVisible,
                tooltip: passwordVisible ? _t(context).baHidePw : _t(context).baShowPw,
              ),
              border: const OutlineInputBorder(),
            ),
            validator: validatePassword,
          ),
          if (!signInMode) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmController,
              obscureText: !passwordVisible,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: _t(context).baConfirmPw,
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
              ),
              validator: validateConfirm,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy ? null : onSubmit,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(signInMode
                    ? Icons.login_rounded
                    : Icons.cloud_upload_rounded),
            label: Text(signInMode ? _t(context).baSignInRestoreBtn : _t(context).baLinkDevice),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: busy ? null : onToggleMode,
            child: Text(
              signInMode
                  ? _t(context).baCreateOne
                  : _t(context).baHaveOne,
            ),
          ),
          if (signInMode)
            TextButton(
              onPressed: busy ? null : onPasswordReset,
              child: Text(_t(context).baForgot),
            ),
        ],
      ),
    );
  }
}

class _LinkedAccountActions extends StatelessWidget {
  final bool busy;
  final VoidCallback onPasswordReset;
  final VoidCallback onSignOut;
  const _LinkedAccountActions({
    required this.busy,
    required this.onPasswordReset,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          onPressed: busy ? null : onPasswordReset,
          icon: const Icon(Icons.lock_reset_rounded),
          label: Text(_t(context).baSendReset),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : onSignOut,
          icon: const Icon(Icons.logout_rounded),
          label: Text(_t(context).baSignOutLinked),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: HCColor.of(context).errorText,
            side: const BorderSide(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
