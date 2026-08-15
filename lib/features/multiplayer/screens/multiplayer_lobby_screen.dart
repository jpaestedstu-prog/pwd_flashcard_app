import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/flashcard_emojis.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../messaging/models/friend_models.dart';
import '../../messaging/services/friend_service.dart';
import '../../messaging/services/profile_directory_service.dart';
import '../../gaze_control/widgets/gaze_dpad_scope.dart';
import '../../messaging/widgets/friend_ui.dart';
import '../models/multiplayer_models.dart';
import '../models/race_presentation.dart';
import '../services/multiplayer_service.dart';
import 'local_race_screen.dart';
import 'online_race_screen.dart';

/// The "Play Together" lobby. Pick a game, then either invite a friend to play
/// online or hand the tablet to a second player on the same device. Friends are
/// added with the exact same flow as Messages (see [showAddFriendDialog]).
///
/// Everything here is star-free and runs on the free Firestore tier; if there
/// is no connection, the online section steps aside and same-device play
/// remains fully available.
class MultiplayerLobbyScreen extends ConsumerStatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  ConsumerState<MultiplayerLobbyScreen> createState() =>
      _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState
    extends ConsumerState<MultiplayerLobbyScreen> {
  MpGameMode _mode = MpGameMode.quizRace;

  List<_FriendEntry> _friends = const [];
  List<GameRoom> _invites = const [];
  int _requestCount = 0;

  StreamSubscription? _friendsSub;
  StreamSubscription<List<GameRoom>>? _invitesSub;
  StreamSubscription<List<FriendRequest>>? _requestsSub;
  String? _watchedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _invitesSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final profile = ref.read(profileProvider);
    if (profile == null || _watchedId == profile.id) return;
    await _friendsSub?.cancel();
    await _invitesSub?.cancel();
    await _requestsSub?.cancel();
    _watchedId = profile.id;

    _friendsSub =
        FriendService.instance.watchFriends(profile.id).listen((list) async {
      final ids = list.map((f) => f.otherProfileFor(profile.id)).toList();
      final resolved =
          await ProfileDirectoryService.instance.lookupMany(ids);
      if (!mounted) return;
      setState(() {
        _friends = ids.map((id) {
          final e = resolved[id];
          final di = e?.disabilityIndex;
          return _FriendEntry(
            id: id,
            name: e?.name ?? 'Friend',
            // Null for a peer whose build predates the field — [InviteFit]
            // treats that as "assume nothing".
            access: di != null && di >= 0 && di < DisabilityType.values.length
                ? DisabilityType.values[di]
                : null,
          );
        }).toList()
          ..sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });
    });

    _requestsSub = FriendService.instance
        .watchIncomingRequests(profile.id)
        .listen((reqs) {
      if (!mounted) return;
      setState(() => _requestCount = reqs.length);
    });

    _invitesSub = MultiplayerService.instance
        .watchIncomingInvites(profile.id)
        .listen((rooms) {
      if (!mounted) return;
      setState(() => _invites = rooms);
    });
  }

  // ─── Content building (shared by online + local) ───────

  ({
    int rounds,
    List<MpQuestion> questions,
    List<MemoryCardSpec> layout,
    List<MpScrambleItem> scramble,
  })? _buildContent(MpGameMode mode) {
    final pool = ref.read(allFlashcardsProvider);
    final rng = Random();
    final isFilipino = ref.read(settingsProvider).locale == 'fil';
    // Match length follows the learner's policy — a shorter match for
    // profiles where sustained attention is the barrier.
    final policy = ref.read(racePresentationProvider);
    final quizRounds = policy.rounds;
    final memoryPairs = policy.memoryPairs;
    const noQ = <MpQuestion>[];
    const noLayout = <MemoryCardSpec>[];
    const noScramble = <MpScrambleItem>[];

    switch (mode) {
      case MpGameMode.quizRace:
        if (pool.length < 4) return null;
        return (
          rounds: quizRounds,
          questions: buildQuizQuestions(pool, quizRounds, rng),
          layout: noLayout,
          scramble: noScramble,
        );
      case MpGameMode.pictureRace:
        if (pool.length < 4) return null;
        return (
          rounds: quizRounds,
          questions: buildPictureQuestions(pool, quizRounds, rng,
              emojiFor: FlashcardEmojis.forId),
          layout: noLayout,
          scramble: noScramble,
        );
      case MpGameMode.trueFalseRace:
        if (pool.length < 2) return null;
        return (
          rounds: quizRounds,
          questions: buildTrueFalseQuestions(pool, quizRounds, rng,
              yesLabel: isFilipino ? 'Tama' : 'True',
              noLabel: isFilipino ? 'Mali' : 'False'),
          layout: noLayout,
          scramble: noScramble,
        );
      case MpGameMode.memoryRace:
        if (pool.length < memoryPairs) return null;
        return (
          rounds: memoryPairs,
          questions: noQ,
          layout: buildMemoryLayout(pool, memoryPairs, rng,
              emojiFor: FlashcardEmojis.forId),
          scramble: noScramble,
        );
      case MpGameMode.scrambleRace:
        final items = buildScrambleItems(pool, policy.scrambleCount, rng,
            emojiFor: FlashcardEmojis.forId);
        if (items.isEmpty) return null;
        return (
          rounds: items.length,
          questions: noQ,
          layout: noLayout,
          scramble: items,
        );
    }
  }

  // ─── Actions ───────────────────────────────────────────

  /// [_mode] clamped to the roster this learner is actually offered — the
  /// selection outlives a profile switch, so it can point at a game the new
  /// profile doesn't get.
  MpGameMode get _selectedMode {
    final modes = ref.read(racePresentationProvider).modes;
    return modes.contains(_mode) ? _mode : modes.first;
  }

  void _playLocal() {
    final mode = _selectedMode;
    if (_buildContent(mode) == null) {
      _warnNotEnoughWords();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LocalRaceScreen(mode: mode),
    ));
  }

  Future<void> _pickFriendAndHost() async {
    final profile = ref.read(profileProvider);
    final isFilipino = ref.read(settingsProvider).locale == 'fil';
    if (profile == null) return;

    if (_friends.isEmpty) {
      final added = await showAddFriendDialog(context,
          me: profile, isFilipino: isFilipino);
      if (!added) return;
      // Friends list updates via the stream; the user can tap again.
      return;
    }

    final friend = await showModalBottomSheet<_FriendEntry>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FriendPickerSheet(
        friends: _friends,
        isFilipino: isFilipino,
        myAccess: profile.disabilityType,
        selectedMode: _selectedMode,
        myNeedsFairPlay: ref.read(racePresentationProvider).needsFairPlay,
        onAddFriend: () async {
          Navigator.of(ctx).pop();
          await showAddFriendDialog(context,
              me: profile, isFilipino: isFilipino);
        },
      ),
    );
    if (friend == null || !mounted) return;
    await _hostWithFriend(friend);
  }

  Future<void> _hostWithFriend(_FriendEntry friend) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    final isFilipino = ref.read(settingsProvider).locale == 'fil';

    // Host the closest game *both* learners are offered. Sending an invite the
    // friend's own roster excludes would arrive unplayable, and they have no
    // way to hand it back.
    final fit = InviteFit.between(
      host: profile.disabilityType,
      guest: friend.access,
      selected: _selectedMode,
      hostNeedsFairPlay: ref.read(racePresentationProvider).needsFairPlay,
    );
    final mode = fit.resolve(_selectedMode);
    if (mode != _selectedMode) {
      setState(() => _mode = mode);
      AppSnackBar.info(
        context,
        message: isFilipino
            ? 'Hindi naglalaro ng ${_selectedMode.labelFilipino} si ${friend.name} — '
                '${mode.labelFilipino} na lang.'
            : "${friend.name} doesn't play "
                '${_selectedMode.label} — switched to ${mode.label}.',
      );
    }

    final content = _buildContent(mode);
    if (content == null) {
      _warnNotEnoughWords();
      return;
    }
    try {
      final room = await MultiplayerService.instance.createRoom(
        me: profile,
        mode: mode,
        invitedProfileId: friend.id,
        rounds: content.rounds,
        questions: content.questions,
        memoryLayout: content.layout,
        scrambleItems: content.scramble,
        // Seed the shared no-clock rule from my own needs; the guest ORs
        // theirs in when they join.
        fairPlay: ref.read(racePresentationProvider).needsFairPlay,
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OnlineRaceScreen(room: room, asHost: true),
      ));
    } on MpActionException catch (e) {
      if (mounted) AppSnackBar.error(context, message: e.message);
    }
  }

  void _acceptInvite(GameRoom room) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OnlineRaceScreen(room: room, asHost: false),
    ));
  }

  void _warnNotEnoughWords() {
    AppSnackBar.warning(context,
        message:
            'Not enough words to play yet — add a few flashcards first!');
  }

  // ─── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';
    final online = MultiplayerService.instance.isOnlineAvailable;
    final pad = context.pagePadding;
    final policy = ref.watch(racePresentationProvider);
    // A profile switch can drop the selected game out of the roster; fall back
    // to the first one this learner is offered rather than rendering nothing.
    final modes = policy.modes;
    final selected = modes.contains(_mode) ? _mode : modes.first;

    // Hands-free rows, in the order they are drawn: the pending invites, then
    // the game roster, then the two ways to play. Without this the lobby is a
    // door a motor learner can't open — the race behind it is hands-free, but
    // getting into one still needed a tap.
    final dpadRows = <List<GazeDpadCell>>[
      for (final r in _invites)
        [
          GazeDpadCell(
            label: 'Play with ${r.hostName}',
            onActivate: () => _acceptInvite(r),
          ),
        ],
      [
        for (final m in modes)
          GazeDpadCell(
            label: isFilipino ? m.labelFilipino : m.label,
            onActivate: () => setState(() => _mode = m),
          ),
      ],
      [
        if (online)
          GazeDpadCell(
            label: isFilipino ? 'Kaibigan' : 'Play with a Friend',
            onActivate: _pickFriendAndHost,
          ),
        GazeDpadCell(
          label: isFilipino ? 'Dito' : 'Play on This Device',
          onActivate: _playLocal,
        ),
      ],
    ];

    return GazeDpadScope(
      rows: dpadRows,
      onExit: () => Navigator.of(context).maybePop(),
      builder: (context, gaze) =>
          _scaffold(context, gaze, profile, isFilipino, online, pad, policy,
              modes, selected),
    );
  }

  Widget _scaffold(
    BuildContext context,
    GazeDpadState gaze,
    UserProfile? profile,
    bool isFilipino,
    bool online,
    double pad,
    RacePresentation policy,
    List<MpGameMode> modes,
    MpGameMode selected,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? '🎮 Maglaro Tayo' : '🎮 Play Together'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (profile != null)
            FriendRequestsBadgeButton(
              count: _requestCount,
              onTap: () => showFriendRequestsSheet(
                context,
                myProfileId: profile.id,
                isFilipino: isFilipino,
                initialRequests: const [],
              ),
            ),
        ],
      ),
      floatingActionButton: profile != null
          ? FloatingActionButton.extended(
              onPressed: () => showAddFriendDialog(context,
                  me: profile, isFilipino: isFilipino),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(isFilipino ? 'Magdagdag' : 'Add Friend'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 96),
          children: [
            if (profile?.username != null)
              UsernameHeaderCard(
                username: profile!.username!,
                isFilipino: isFilipino,
              ),
            if (_invites.isNotEmpty) ...[
              const SizedBox(height: 8),
              _sectionTitle(
                  isFilipino ? 'Mga Imbitasyon' : 'Game Invites', '✉️'),
              const SizedBox(height: 8),
              for (var i = 0; i < _invites.length; i++)
                _InviteCard(
                  room: _invites[i],
                  isFilipino: isFilipino,
                  focused: gaze.isFocused(i, 0),
                  onPlay: () => _acceptInvite(_invites[i]),
                ),
            ],
            const SizedBox(height: 12),
            _sectionTitle(isFilipino ? 'Pumili ng laro' : 'Choose a game', '🎲'),
            const SizedBox(height: 8),
            // A vertical list of full-width selectable rows — overflow-proof at
            // any width / font scale (no fixed-height grid cells). The roster
            // is curated for this learner's accessibility profile.
            for (var i = 0; i < modes.length; i++)
              _modeRow(modes[i], selected, isFilipino,
                  focused: gaze.isFocused(_invites.length, i)),
            ?_AdaptationNote.maybe(policy, isFilipino),
            const SizedBox(height: 16),
            _sectionTitle(isFilipino ? 'Paano maglaro?' : 'How to play', '👥'),
            const SizedBox(height: 8),
            if (online)
              _PlayOptionButton(
                emoji: '🌐',
                title: isFilipino ? 'Laro kasama ang kaibigan' : 'Play with a Friend',
                subtitle: isFilipino
                    ? 'Mag-imbita ng kaibigan online'
                    : 'Invite a friend to play online',
                color: AppColors.primary,
                focused: gaze.isFocused(_invites.length + 1, 0),
                onTap: _pickFriendAndHost,
              )
            else
              _OfflineNote(isFilipino: isFilipino),
            const SizedBox(height: 12),
            _PlayOptionButton(
              emoji: '📱',
              title: isFilipino ? 'Laro sa iisang tablet' : 'Play on This Device',
              subtitle: isFilipino
                  ? 'Magpalitan kayo ng dalawa'
                  : 'Pass and play with someone next to you',
              color: AppColors.playerAccent,
              // The local button is the row's only cell when there is no
              // network, and its second cell when there is.
              focused: gaze.isFocused(_invites.length + 1, online ? 1 : 0),
              onTap: _playLocal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, String emoji) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTypography.titleMedium
              .copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Color _modeColor(MpGameMode mode) => switch (mode) {
        MpGameMode.quizRace => AppColors.info,
        MpGameMode.pictureRace => AppColors.primary,
        MpGameMode.trueFalseRace => AppColors.success,
        MpGameMode.memoryRace => AppColors.playerAccent,
        MpGameMode.scrambleRace => AppColors.warning,
      };

  Widget _modeRow(MpGameMode mode, MpGameMode current, bool isFilipino,
      {bool focused = false}) {
    final selected = current == mode;
    final color = _modeColor(mode);
    final hc = HCColor.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _mode = mode),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.12) : hc.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                // The hands-free ring outranks the "chosen" border — it says
                // where a blink lands, which is the more urgent fact.
                color: focused
                    ? AppColors.warning
                    : selected
                        ? color
                        : AppColors.border,
                width: focused
                    ? 4
                    : selected
                        ? 2
                        : 1,
              ),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(mode.emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFilipino ? mode.labelFilipino : mode.label,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: selected ? color : hc.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isFilipino
                            ? mode.descriptionFilipino
                            : mode.description,
                        style: AppTypography.bodySmall
                            .copyWith(color: hc.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? color : AppColors.border,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendEntry {
  final String id;
  final String name;

  /// The friend's published accessibility category, or null when their build
  /// predates the field. Drives [InviteFit].
  final DisabilityType? access;

  const _FriendEntry({required this.id, required this.name, this.access});
}

/// Tells the learner, in one line, what Play Together changed for them.
///
/// Silent adaptation is the failure mode here: a child whose match has no
/// timer should know their score is not being docked, and an educator glancing
/// at the tablet should be able to see the accommodation is on.
class _AdaptationNote extends StatelessWidget {
  final String text;
  const _AdaptationNote({required this.text});

  /// The note for [policy], or null when nothing was adapted (a Player
  /// profile, or a learner with no accessibility category).
  static Widget? maybe(RacePresentation policy, bool isFilipino) {
    final note = policy.adaptationNote(isFilipino: isFilipino);
    return note == null ? null : _AdaptationNote(text: note);
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.accessibility_new_rounded,
              size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final GameRoom room;
  final bool isFilipino;
  final bool focused;
  final VoidCallback onPlay;
  const _InviteCard({
    required this.room,
    required this.isFilipino,
    required this.onPlay,
    this.focused = false,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focused
              ? AppColors.warning
              : AppColors.primary.withValues(alpha: 0.2),
          width: focused ? 4 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(room.mode.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFilipino
                      ? '${room.hostName} ang nag-imbita sa iyo!'
                      : '${room.hostName} invited you!',
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isFilipino ? room.mode.labelFilipino : room.mode.label,
                  style: AppTypography.bodySmall
                      .copyWith(color: hc.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onPlay,
            child: Text(isFilipino ? 'Sali' : 'Play'),
          ),
        ],
      ),
    );
  }
}

class _PlayOptionButton extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final bool focused;
  final VoidCallback onTap;
  const _PlayOptionButton({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.focused = false,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: focused ? AppColors.warning : color.withValues(alpha: 0.3),
              width: focused ? 4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium
                          .copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall
                          .copyWith(color: hc.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: hc.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  final bool isFilipino;
  const _OfflineNote({required this.isFilipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isFilipino
                  ? 'Kumonekta sa internet para makalaro kasama ang kaibigan. Pwede pa ring maglaro sa iisang tablet!'
                  : 'Connect to the internet to play with friends. You can still play on this device!',
              style:
                  AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendPickerSheet extends StatelessWidget {
  final List<_FriendEntry> friends;
  final bool isFilipino;

  /// The host's own category + current pick, so each row can say what
  /// inviting that friend would change. See [InviteFit].
  final DisabilityType myAccess;
  final MpGameMode selectedMode;
  final bool myNeedsFairPlay;

  final VoidCallback onAddFriend;
  const _FriendPickerSheet({
    required this.friends,
    required this.isFilipino,
    required this.myAccess,
    required this.selectedMode,
    required this.myNeedsFairPlay,
    required this.onAddFriend,
  });

  /// What changes about the match if this friend is the one invited — the
  /// chosen game being swapped, or the clock coming off. Null when nothing
  /// changes, which is the common case and deserves no noise.
  String? _fitNote(_FriendEntry f) {
    final fit = InviteFit.between(
      host: myAccess,
      guest: f.access,
      selected: selectedMode,
      hostNeedsFairPlay: myNeedsFairPlay,
    );
    final parts = <String>[];
    if (!fit.selectedIsShared) {
      final swap = fit.resolve(selectedMode);
      parts.add(isFilipino
          ? '${swap.labelFilipino} na lang'
          : 'plays ${swap.label} instead');
    }
    // Only worth saying when *they* are the reason — the host already knows
    // about their own clock from the lobby's adaptation note.
    if (fit.dropsTheClock && !myNeedsFairPlay) {
      parts.add(isFilipino ? 'walang orasan' : 'untimed match');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isFilipino ? 'Pumili ng kaibigan' : 'Pick a friend',
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAddFriend,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(isFilipino ? 'Magdagdag' : 'Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: friends.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final f = friends[i];
                  final note = _fitNote(f);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        f.name.isNotEmpty ? f.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                    title: Text(f.name),
                    subtitle: note == null
                        ? null
                        : Text(
                            note,
                            style: AppTypography.bodySmall.copyWith(
                              color: HCColor.of(context).textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: const Icon(Icons.play_circle_fill_rounded,
                        color: AppColors.primary),
                    onTap: () => Navigator.of(ctx).pop(f),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isFilipino
                  ? 'Mag-iimbita ka sa napiling kaibigan.'
                  : 'Your chosen friend will get an invite.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
