import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/join_code_service.dart';
import '../../../features/onboarding/screens/post_join_setup_screen.dart';
import '../../../providers/home_group_join_provider.dart';

/// Child-side screen: enter a 6-character home-group code.
///
/// Step 1 of the join flow. The name / avatar / birth date / PIN are
/// collected on the next screen ([PostJoinSetupScreen]), so a back-button
/// cancel here leaves no partial profile in Firestore or Hive.
class JoinHomeGroupScreen extends ConsumerStatefulWidget {
  const JoinHomeGroupScreen({super.key});

  @override
  ConsumerState<JoinHomeGroupScreen> createState() =>
      _JoinHomeGroupScreenState();
}

class _JoinHomeGroupScreenState extends ConsumerState<JoinHomeGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(homeGroupJoinProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final group = await ref
        .read(homeGroupJoinProvider.notifier)
        .validateCode(_codeController.text.trim().toUpperCase());

    if (!mounted || group == null) return;
    context.push('/post-join-setup', extra: HomeGroupJoinContext(group));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeGroupJoinProvider);
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
                      isLoading ? 'Checking…' : 'Join group',
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
