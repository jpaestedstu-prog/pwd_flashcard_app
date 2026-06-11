import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/sync_status_widget.dart';

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
    if (v.isEmpty) return 'Enter an email';
    final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRe.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  /// Translate Firebase Auth error codes into messages parents/teachers
  /// can act on. We deliberately do NOT distinguish `user-not-found` from
  /// `wrong-password` to avoid account-enumeration on the sign-in path.
  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email already has an account. Choose "I already have '
            'an account" instead.';
      case 'weak-password':
        return 'That password is too easy to guess. Use 8+ characters.';
      case 'invalid-email':
        return 'That doesn\'t look like a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'user-disabled':
        return 'That account has been disabled.';
      case 'network-request-failed':
        return 'No internet connection. Try again when you\'re online.';
      case 'too-many-requests':
        return 'Too many tries. Wait a minute and try again.';
      case 'provider-already-linked':
        return 'This device is already linked to a different account.';
      default:
        return e.message ?? 'Sign-in failed (${e.code}).';
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
        message: 'Account linked! Your data is now backed up to '
            '${_emailController.text.trim()}.',
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
            ? 'Signed in. No backup data was found for this account.'
            : 'Signed in. Restored $restored '
                '${restored == 1 ? 'profile' : 'profiles'} from the cloud.',
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
          message: 'Enter your email above before requesting a reset.');
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseService.sendPasswordReset(email);
      if (!mounted) return;
      AppSnackBar.success(
        context,
        message: 'Password reset email sent to $email.',
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
        title: const Text('Sign out of linked account?'),
        content: const Text(
          'The app will keep working offline, but new cloud writes will '
          'use a fresh anonymous session. Your local profiles stay on '
          'this device — they are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await FirebaseService.signOut();
      if (!mounted) return;
      AppSnackBar.success(context, message: 'Signed out.');
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
        title: const Text('Backup & Link Account'),
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
                  linked ? 'Backup is active' : 'No backup yet',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  linked
                      ? 'Linked to ${email ?? '(unknown email)'}. Sign in '
                          'with this email on a new device to restore '
                          'your profiles and progress.'
                      : 'Your data is stored on this device only. Link '
                          'an email below so you can recover everything '
                          'if the device is lost or reset.',
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
                ? 'Sign in to restore'
                : 'Create a backup',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            signInMode
                ? 'Use the email and password you set on your other device.'
                : 'Pick an email and password to back up this device. '
                    'No verification email required.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
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
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(passwordVisible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
                onPressed: onTogglePasswordVisible,
                tooltip: passwordVisible ? 'Hide password' : 'Show password',
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
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
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
            label: Text(signInMode ? 'Sign in & restore' : 'Link this device'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: busy ? null : onToggleMode,
            child: Text(
              signInMode
                  ? "Don't have an account yet? Create one"
                  : 'I already have an account — sign in',
            ),
          ),
          if (signInMode)
            TextButton(
              onPressed: busy ? null : onPasswordReset,
              child: const Text('Forgot password? Send reset email'),
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
          label: const Text('Send password reset email'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : onSignOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out of linked account'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}
