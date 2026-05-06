import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/join_code_service.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/home_group_join_provider.dart';

/// Child-side screen: enter a 6-character home-group code + name to join
/// the family unit set up by a parent.
///
/// Mirrors the student `JoinClassScreen` UI so children get the same
/// familiar form, just labelled for the family context. If a Player-mode
/// profile is already active, joining upgrades that profile in place
/// (preserving the UUID and any local progress).
class JoinHomeGroupScreen extends ConsumerStatefulWidget {
  const JoinHomeGroupScreen({super.key});

  @override
  ConsumerState<JoinHomeGroupScreen> createState() =>
      _JoinHomeGroupScreenState();
}

class _JoinHomeGroupScreenState extends ConsumerState<JoinHomeGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  DateTime? _birthDate;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 7, now.month, now.day),
      firstDate: DateTime(now.year - 17),
      lastDate: DateTime(now.year - 3),
      helpText: 'Pick the child\'s birthday',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a birthday.')),
      );
      return;
    }

    final activeProfile = ref.read(profileProvider);
    final upgradingPlayer =
        activeProfile != null && activeProfile.isPlayerMode;

    await ref.read(homeGroupJoinProvider.notifier).joinByCode(
          code: _codeController.text.trim().toUpperCase(),
          name: _nameController.text.trim(),
          birthDate: _birthDate,
          existingProfile: upgradingPlayer ? activeProfile : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeGroupJoinProvider);

    ref.listen<HomeGroupJoinState>(homeGroupJoinProvider, (prev, next) {
      if (next is HomeGroupJoinSuccess && mounted) {
        context.go('/home');
      }
    });

    final isLoading = state is HomeGroupJoinLoading;
    final failure = state is HomeGroupJoinFailure ? state : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Home Group'),
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
                  'Enter the code your parent or guardian shared.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(6),
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9]')),
                    _UpperCaseFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Home-group code',
                    hintText: 'ABC123',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length != 6)
                      ? 'Code must be 6 characters'
                      : null,
                ),
                const SizedBox(height: 16),

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

                OutlinedButton.icon(
                  onPressed: _pickBirthDate,
                  icon: const Icon(Icons.cake_outlined),
                  label: Text(
                    _birthDate == null
                        ? 'Pick birthday'
                        : 'Birthday: ${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
                  ),
                ),
                const SizedBox(height: 16),

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

                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      isLoading ? 'Joining…' : 'Join group',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                if (failure?.error == JoinCodeError.network)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Tip: ask your parent to check their internet '
                      'connection, or try again in a moment.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
