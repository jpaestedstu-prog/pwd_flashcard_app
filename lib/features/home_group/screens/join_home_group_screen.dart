import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/join_code_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/safe_scaffold.dart';
import '../../../data/remote/firestore_repository.dart';
import '../../../data/models/enums.dart';
import '../../../features/onboarding/screens/post_join_setup_screen.dart';
import '../../../providers/home_group_join_provider.dart';
import '../../../providers/app_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/fit_label.dart';

/// Child-side screen: enter a 6-character home-group code.
///
/// Step 1 of the join flow. The name / avatar / birth date / PIN are
/// collected on the next screen ([PostJoinSetupScreen]), so a back-button
/// cancel here leaves no partial profile in Firestore or Hive.
class JoinHomeGroupScreen extends ConsumerStatefulWidget {
  const JoinHomeGroupScreen({super.key});

  /// Stands in for the cloud in tests.
  @visibleForTesting
  static Future<String?> Function(String profileId)? debugMemberLookup;

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
      if (!mounted) return;
      ref.read(homeGroupJoinProvider.notifier).reset();
      unawaited(_relinkIfStillAMember());
    });
  }

  /// A child whose group still lists them needs no code: this tablet's copy
  /// lost the link (a parent opening them from a list erased it, until 1.4.4).
  /// When it cannot be told (offline), the page stays as it is.
  Future<void> _relinkIfStillAMember() async {
    final child = ref.read(profileProvider);
    if (child == null ||
        child.role != UserRole.child ||
        child.homeGroupId != null) {
      return;
    }
    final String? groupId;
    try {
      final lookup = JoinHomeGroupScreen.debugMemberLookup ??
          (FirebaseService.isConfigured
              ? const FirestoreRepository().homeGroupIdOfMember
              : null);
      groupId = await lookup?.call(child.id);
    } catch (e) {
      debugPrint('JoinHomeGroup: could not look for the group: $e');
      return;
    }
    if (groupId == null || !mounted) return;
    await ref.read(profileProvider.notifier).restoreHomeGroupLink(groupId);
    if (mounted) context.go('/home');
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

    return SafeScaffold(
      appBar: AppBar(
        title: AppBarTitle(_t(context).joinGroupTitle),
        leading: IconButton(
          tooltip: _t(context).back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/profile-switcher');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account_rounded),
            tooltip: _t(context).childSwitchProfile,
            // The list of profiles: it opened the page for making a new one.
            onPressed: () => context.go('/profile-switcher'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                Text(
                  _t(context).joinGroupIntro,
                  style: const TextStyle(fontSize: 16),
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
                  decoration: InputDecoration(
                    label: FitLabel(_t(context).joinGroupCode),
                    hintText: 'ABC123',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length != 6)
                      ? _t(context).joinCodeLength
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
                      _joinError(_t(context), failure.error),
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),

                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      isLoading ? _t(context).joinChecking : _t(context).playerJoinGroup,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                if (failure?.error == JoinCodeError.network)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _t(context).joinGroupTip,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  JoinCodeError.notFound => t.jcNoGroup,
  JoinCodeError.network => t.jcNetwork,
  JoinCodeError.collision || JoinCodeError.unknown => t.jcUnknown,
};
