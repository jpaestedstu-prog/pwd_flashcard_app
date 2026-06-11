import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../games/widgets/pause_overlay.dart';
import '../models/multiplayer_models.dart';
import '../services/multiplayer_service.dart';
import '../widgets/memory_race_player.dart';
import '../widgets/quiz_race_player.dart';
import '../widgets/race_result_view.dart';
import '../widgets/scramble_race_player.dart';

/// Online "Play with a Friend" race over Firestore.
///
/// Both players race the identical content the host wrote into the room; each
/// device drives only its own [QuizRacePlayer] / [MemoryRacePlayer] and writes
/// only its own player doc, while watching the room + player docs for live
/// opponent progress. When both players finish, the winner is computed
/// client-side. Star-free.
///
/// The host arrives with a freshly created [room] (already `waiting`). The
/// guest arrives from a tapped invite and [joinRoom]s on mount, flipping the
/// room to `active`.
class OnlineRaceScreen extends ConsumerStatefulWidget {
  final GameRoom room;
  final bool asHost;
  const OnlineRaceScreen({
    super.key,
    required this.room,
    required this.asHost,
  });

  @override
  ConsumerState<OnlineRaceScreen> createState() => _OnlineRaceScreenState();
}

class _OnlineRaceScreenState extends ConsumerState<OnlineRaceScreen>
    with WidgetsBindingObserver {
  final _svc = MultiplayerService.instance;

  GameRoom? _room;
  List<MpPlayerState> _players = const [];
  StreamSubscription<GameRoom?>? _roomSub;
  StreamSubscription<List<MpPlayerState>>? _playersSub;

  bool _everLoaded = false;
  bool _started = false;
  bool _myFinished = false;
  bool _matchComplete = false;
  bool _paused = false;
  bool _cleanedUp = false;
  int _myScore = 0;
  int _playerSeq = 0;
  String? _error;

  String get _roomId => widget.room.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _room = widget.room;
    _everLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final me = ref.read(profileProvider);
    if (me == null) {
      setState(() => _error = 'No active profile.');
      return;
    }

    _roomSub = _svc.watchRoom(_roomId).listen((room) {
      if (!mounted) return;
      setState(() {
        _room = room;
        if (room != null) _everLoaded = true;
        if (room != null &&
            room.status == GameRoomStatus.active &&
            !_started) {
          _started = true;
        }
      });
    });

    _playersSub = _svc.watchPlayers(_roomId).listen((players) {
      if (!mounted) return;
      final opp = _opponentOf(players, me.id);
      setState(() {
        _players = players;
        if (_myFinished && (opp?.finished ?? false)) _matchComplete = true;
      });
    });

    // Guest accepts the invite by joining (flips the room to active).
    if (!widget.asHost) {
      try {
        await _svc.joinRoom(room: widget.room, me: me);
      } on MpActionException catch (e) {
        if (mounted) setState(() => _error = e.message);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    _roomSub?.cancel();
    _playersSub?.cancel();
    super.dispose();
  }

  /// Tidy up the room exactly once, whether the user leaves via the pause menu
  /// ([_leave]), the back gesture, or the screen being disposed.
  ///
  /// Role-aware to avoid the racy double-write that caused a permission-denied
  /// error: the **host** simply deletes the room (which also signals "ended"
  /// to the guest, whose room stream emits null), while the **guest** flags
  /// the room cancelled so the host is notified. The guest can't delete it
  /// (delete is host-only by the security rules).
  void _cleanup() {
    if (_cleanedUp) return;
    _cleanedUp = true;
    if (widget.asHost) {
      // ignore: discarded_futures
      _svc.purgeRoom(_roomId);
    } else if (!_matchComplete) {
      // ignore: discarded_futures
      _svc.cancelRoom(_roomId);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-pause my own view when the app is backgrounded mid-race. (The
    // opponent keeps playing — online play can't freeze the other device.)
    if (state != AppLifecycleState.resumed &&
        _started &&
        !_myFinished &&
        !_paused) {
      setState(() => _paused = true);
    }
  }

  MpPlayerState? _opponentOf(List<MpPlayerState> players, String myId) {
    for (final p in players) {
      if (p.profileId != myId) return p;
    }
    return null;
  }

  int get _total => (_room ?? widget.room).totalSteps;

  /// Restart my own attempt at the same shared content (online can't reset the
  /// shared room). Resets my score/progress and replays from scratch.
  void _restartMine() {
    final me = ref.read(profileProvider);
    setState(() {
      _paused = false;
      _myFinished = false;
      _myScore = 0;
      _playerSeq++;
    });
    if (me != null) {
      // ignore: discarded_futures
      _svc.submitProgress(roomId: _roomId, me: me, score: 0, progress: 0);
    }
  }

  bool _inPlay(GameRoom? room, UserProfile? me) {
    if (_error != null || me == null || room == null) return false;
    if (room.status == GameRoomStatus.cancelled && !_matchComplete) {
      return false;
    }
    final opp = _opponentOf(_players, me.id);
    if (_myFinished && (opp?.finished ?? false)) return false; // result
    if (!_started || _myFinished) return false;
    return true;
  }

  void _onProgress(int score, int progress) {
    final me = ref.read(profileProvider);
    if (me == null) return;
    _myScore = score;
    // ignore: discarded_futures
    _svc.submitProgress(
        roomId: _roomId, me: me, score: score, progress: progress);
  }

  void _onMyFinished(int score) {
    final me = ref.read(profileProvider);
    if (me == null) return;
    setState(() {
      _myFinished = true;
      _myScore = score;
    });
    // ignore: discarded_futures
    _svc.finishMatch(
        roomId: _roomId, me: me, score: score, progress: _total);
  }

  void _leave() {
    _cleanup();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';
    final me = ref.read(profileProvider);
    final room = _room;
    final inPlay = _inPlay(room, me);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('${widget.room.mode.emoji} '
                '${isFilipino ? widget.room.mode.labelFilipino : widget.room.mode.label}'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            // During play the top-left control is the Pause button (its menu is
            // the way out). Outside play the default back arrow handles leaving.
            leading: inPlay
                ? IconButton(
                    tooltip: isFilipino ? 'I-pause' : 'Pause',
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                    onPressed: () => setState(() => _paused = true),
                  )
                : null,
          ),
          body: SafeArea(child: _body(room, me, isFilipino)),
        ),
        if (_paused && inPlay)
          PauseOverlay(
            onResume: () => setState(() => _paused = false),
            onRestart: _restartMine,
            onQuit: () async => _leave(),
          ),
      ],
    );
  }

  Widget _body(GameRoom? room, UserProfile? me, bool isFilipino) {
    if (_error != null) {
      return _message('😕', _error!, isFilipino);
    }
    if (me == null) {
      return _message('😕', 'No active profile.', isFilipino);
    }
    if (room == null) {
      return _everLoaded
          ? _message('👋',
              isFilipino ? 'Tapos na ang laro.' : 'The game ended.', isFilipino)
          : _loading(isFilipino ? 'Kumokonekta…' : 'Connecting…');
    }
    if (room.status == GameRoomStatus.cancelled && !_matchComplete) {
      return _message(
          '👋',
          isFilipino
              ? 'Umalis ang kalaro mo.'
              : 'The other player left the game.',
          isFilipino);
    }

    final opp = _opponentOf(_players, me.id);
    final bothFinished = _myFinished && (opp?.finished ?? false);

    if (bothFinished) {
      return RaceResultView(
        player1Name: me.name,
        player1Score: _myScore,
        player2Name: opp?.name.isNotEmpty == true
            ? opp!.name
            : room.opponentNameFor(me.id),
        player2Score: opp?.score ?? 0,
        mode: room.mode,
        isFilipino: isFilipino,
        onHome: _leave,
      );
    }

    if (!_started) {
      // Host waiting for the invited friend to accept.
      return _waitingForGuest(room, isFilipino);
    }

    if (_myFinished) {
      return _waitingForOpponent(room, opp, isFilipino);
    }

    return _playing(room, opp, isFilipino);
  }

  // ─── Phase views ──────────────────────────────────────

  Widget _playing(GameRoom room, MpPlayerState? opp, bool isFilipino) {
    final accent = switch (room.mode) {
      MpGameMode.memoryRace => AppColors.playerAccent,
      MpGameMode.scrambleRace => AppColors.warning,
      MpGameMode.trueFalseRace => AppColors.success,
      _ => AppColors.info,
    };
    final key = ValueKey('online_$_playerSeq');
    final Widget player;
    if (room.mode == MpGameMode.memoryRace) {
      player = MemoryRacePlayer(
        key: key,
        layout: room.memoryLayout,
        accentColor: accent,
        isFilipino: isFilipino,
        isPaused: _paused,
        onProgress: _onProgress,
        onFinished: _onMyFinished,
      );
    } else if (room.mode == MpGameMode.scrambleRace) {
      player = ScrambleRacePlayer(
        key: key,
        items: room.scrambleItems,
        accentColor: accent,
        isFilipino: isFilipino,
        isPaused: _paused,
        onProgress: _onProgress,
        onFinished: _onMyFinished,
      );
    } else {
      player = QuizRacePlayer(
        key: key,
        questions: room.questions,
        accentColor: accent,
        isFilipino: isFilipino,
        isPaused: _paused,
        onProgress: _onProgress,
        onFinished: _onMyFinished,
      );
    }
    return Column(
      children: [
        _OpponentStrip(
          name: opp?.name.isNotEmpty == true
              ? opp!.name
              : room.opponentNameFor(ref.read(profileProvider)?.id ?? ''),
          score: opp?.score ?? 0,
          progress: opp?.progress ?? 0,
          total: _total,
          finished: opp?.finished ?? false,
          isFilipino: isFilipino,
        ),
        Expanded(child: player),
      ],
    );
  }

  Widget _waitingForGuest(GameRoom room, bool isFilipino) {
    final friend = room.opponentNameFor(room.hostProfileId);
    return _centeredCard(
      emoji: '⏳',
      title: isFilipino ? 'Hinihintay si $friend…' : 'Waiting for $friend…',
      subtitle: isFilipino
          ? 'Sasali sila kapag tinanggap nila ang imbitasyon mo.'
          : "They'll join once they accept your invite.",
      showSpinner: true,
    );
  }

  Widget _waitingForOpponent(
      GameRoom room, MpPlayerState? opp, bool isFilipino) {
    final name = opp?.name.isNotEmpty == true
        ? opp!.name
        : room.opponentNameFor(ref.read(profileProvider)?.id ?? '');
    return _centeredCard(
      emoji: '🏁',
      title: isFilipino ? 'Tapos ka na!' : "You're done!",
      subtitle: isFilipino
          ? 'Hinihintay si $name na matapos…'
          : 'Waiting for $name to finish…',
      showSpinner: true,
      extra: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: _OpponentStrip(
          name: name,
          score: opp?.score ?? 0,
          progress: opp?.progress ?? 0,
          total: _total,
          finished: opp?.finished ?? false,
          isFilipino: isFilipino,
        ),
      ),
    );
  }

  Widget _loading(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }

  Widget _message(String emoji, String text, bool isFilipino) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              text,
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _leave,
              child: Text(isFilipino ? 'Bumalik' : 'Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centeredCard({
    required String emoji,
    required String title,
    required String subtitle,
    bool showSpinner = false,
    Widget? extra,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: AppTypography.titleLarge
                    .copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTypography.bodyMedium
                  .copyWith(color: HCColor.of(context).textSecondary),
              textAlign: TextAlign.center,
            ),
            if (showSpinner) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
            ?extra,
          ],
        ),
      ),
    );
  }
}

/// Compact live strip showing the opponent's avatar, score and progress bar.
class _OpponentStrip extends StatelessWidget {
  final String name;
  final int score;
  final int progress;
  final int total;
  final bool finished;
  final bool isFilipino;

  const _OpponentStrip({
    required this.name,
    required this.score,
    required this.progress,
    required this.total,
    required this.finished,
    required this.isFilipino,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final fraction = total <= 0 ? 0.0 : (progress / total).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.error.withValues(alpha: 0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: AppTypography.labelLarge
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      finished
                          ? (isFilipino ? 'Tapos na ✓' : 'Done ✓')
                          : '$score',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: hc.surfaceLight,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
