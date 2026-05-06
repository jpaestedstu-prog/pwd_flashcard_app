import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/app_providers.dart';
import '../../../providers/join_code_provider.dart';

/// Student-side screen: enter a 6-character classroom code + name to join.
///
/// If a profile is already active and is a guest (`isGuestPlayer == true`),
/// joining upgrades that profile in place — keeping the UUID and progress.
class JoinClassScreen extends ConsumerStatefulWidget {
  const JoinClassScreen({super.key});

  @override
  ConsumerState<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends ConsumerState<JoinClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final activeProfile = ref.read(profileProvider);
    final upgradingPlayer =
        activeProfile != null && activeProfile.isGuestPlayer;

    await ref.read(joinCodeProvider.notifier).joinByCode(
          code: _codeController.text.trim().toUpperCase(),
          name: _nameController.text.trim(),
          existingProfile: upgradingPlayer ? activeProfile : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(joinCodeProvider);

    ref.listen<JoinCodeState>(joinCodeProvider, (prev, next) {
      if (next is JoinCodeSuccess && mounted) {
        context.go('/home');
      }
    });

    final isLoading = state is JoinCodeLoading;
    final failure = state is JoinCodeFailure ? state : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a Class'),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter the code your teacher gave you.',
                  style: TextStyle(fontSize: 16),
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
                  decoration: const InputDecoration(
                    labelText: 'Class code',
                    hintText: 'ABC123',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length != 6)
                      ? 'Code must be 6 characters'
                      : null,
                ),
                const SizedBox(height: 16),

                // ─── Name ──────────────────────────────
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Please enter your name'
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
                      failure.message,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),

                // ─── Submit ────────────────────────────
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      isLoading ? 'Joining…' : 'Join class',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
