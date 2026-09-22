import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/safe_scaffold.dart';
import '../../../features/onboarding/screens/post_join_setup_screen.dart';
import '../../../core/services/join_code_service.dart';
import '../../../providers/join_code_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Student-side screen: enter a 6-character classroom code.
///
/// This is step 1 of the join flow. On success it routes to the
/// [PostJoinSetupScreen] where the student picks a name, avatar, birth
/// date, and optional PIN — no profile is written until that step
/// completes, so a back-button cancel here leaves nothing behind.
class JoinClassScreen extends ConsumerStatefulWidget {
  const JoinClassScreen({super.key});

  @override
  ConsumerState<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends ConsumerState<JoinClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reset any leftover state from a previous attempt so the failure
    // banner from a prior wrong code doesn't linger.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(joinCodeProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final classroom = await ref
        .read(joinCodeProvider.notifier)
        .validateCode(_codeController.text.trim().toUpperCase());

    if (!mounted || classroom == null) return;
    context.push('/post-join-setup', extra: ClassJoinContext(classroom));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(joinCodeProvider);
    final isLoading = state is JoinCodeLoading;
    final failure = state is JoinCodeFailure ? state : null;

    return SafeScaffold(
      appBar: AppBar(
        title: Text(_t(context).joinClassTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                Text(
                  _t(context).joinClassIntro,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),

                // ─── Class code ─────────────────────────
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(6),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    _UpperCaseFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: _t(context).joinClassCode,
                    hintText: 'ABC123',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length != 6)
                      ? _t(context).joinCodeLength
                      : null,
                ),
                const SizedBox(height: 16),

                // ─── Error ─────────────────────────────
                if (failure != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _joinError(_t(context), failure.error),
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),

                // ─── Submit ────────────────────────────
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      isLoading ? _t(context).joinChecking : _t(context).playerJoinClass,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

/// The failure in the reader's language. The provider's own message is
/// written for developers (it names Firestore paths and deploy commands).
String _joinError(AppLocalizations t, JoinCodeError error) => switch (error) {
  JoinCodeError.notFound => t.jcNoClass,
  JoinCodeError.network => t.jcNetwork,
  JoinCodeError.collision || JoinCodeError.unknown => t.jcUnknown,
};
