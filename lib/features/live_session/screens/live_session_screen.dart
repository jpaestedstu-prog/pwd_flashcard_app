import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/local_repository.dart';
import '../../../data/models/classroom.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../models/live_session_models.dart';
import '../services/live_session_service.dart';

/// Real-time classroom session. Renders a teacher dashboard for educator
/// profiles and a student receiver for student profiles. Both share the
/// same screen so the route is one path.
class LiveSessionScreen extends ConsumerWidget {
  const LiveSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('No profile selected')),
      );
    }
    final isTeacher = profile.role == UserRole.teacher;
    return Scaffold(
      appBar: AppBar(
        title: Text(isTeacher ? 'Live Session (Teacher)' : 'Live Session'),
      ),
      body: SafeArea(
        child: isTeacher
            ? _TeacherView(profile: profile)
            : _StudentView(profile: profile),
      ),
    );
  }
}

// ─── Teacher ──────────────────────────────────────────

class _TeacherView extends ConsumerStatefulWidget {
  final UserProfile profile;
  const _TeacherView({required this.profile});

  @override
  ConsumerState<_TeacherView> createState() => _TeacherViewState();
}

class _TeacherViewState extends ConsumerState<_TeacherView> {
  static const _service = LiveSessionService();
  static const _local = LocalRepository();

  Classroom? _selectedClassroom;
  LiveActivity? _currentActivity;
  List<Classroom> _classrooms = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    final list = await _local.getClassroomsByTeacher(widget.profile.id);
    if (!mounted) return;
    setState(() {
      _classrooms = list;
      _loading = false;
      if (list.length == 1) _selectedClassroom = list.first;
    });
  }

  Future<void> _start(Classroom c) async {
    await _service.startSession(
      classroomId: c.id,
      teacherProfileId: widget.profile.id,
    );
    if (!mounted) return;
    setState(() => _selectedClassroom = c);
  }

  Future<void> _push(Flashcard card) async {
    final c = _selectedClassroom;
    if (c == null) return;
    final activity = await _service.pushFlashcard(
      classroomId: c.id,
      flashcardId: card.id,
    );
    if (!mounted) return;
    setState(() => _currentActivity = activity);
  }

  Future<void> _end() async {
    final c = _selectedClassroom;
    if (c == null) return;
    await _service.endSession(c.id);
    if (!mounted) return;
    setState(() {
      _selectedClassroom = null;
      _currentActivity = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_classrooms.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'You have no classrooms yet. Create one from the Classroom '
            'Management screen first.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final selected = _selectedClassroom;
    if (selected == null) {
      return _classroomPicker();
    }
    return _runningSession(selected);
  }

  Widget _classroomPicker() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _classrooms.length,
      itemBuilder: (context, i) {
        final c = _classrooms[i];
        return Card(
          child: ListTile(
            title: Text(c.name),
            subtitle: Text('Code: ${c.code}'),
            trailing: const Icon(Icons.play_circle_outline),
            onTap: () => _start(c),
          ),
        );
      },
    );
  }

  Widget _runningSession(Classroom c) {
    final flashcards = ref.watch(allFlashcardsProvider);
    final activity = _currentActivity;

    return Column(
      children: [
        // ── Status header ─────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.green.withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Code: ${c.code} • Live'),
              if (activity != null) ...[
                const SizedBox(height: 12),
                Text('Pushed: ${_describeActivity(activity, flashcards)}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _ResponsesLive(
                  service: _service,
                  classroomId: c.id,
                  activityId: activity.id,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _end,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('End session'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Push picker ──────────────────────────────
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Push a flashcard',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: flashcards.length,
            itemBuilder: (context, i) {
              final card = flashcards[i];
              return Card(
                child: ListTile(
                  title: Text(card.wordEnglish),
                  subtitle: Text(card.wordFilipino),
                  trailing: const Icon(Icons.send_rounded),
                  onTap: () => _push(card),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _describeActivity(LiveActivity a, List<Flashcard> flashcards) {
    final id = a.payload['flashcard_id'] as String?;
    if (id == null) return a.type.name;
    final card = flashcards.firstWhere(
      (c) => c.id == id,
      orElse: () => Flashcard(
        id: id,
        wordEnglish: id,
        wordFilipino: '',
        category: FlashcardCategory.animals,
      ),
    );
    return '${card.wordEnglish} (${card.wordFilipino})';
  }
}

class _ResponsesLive extends StatelessWidget {
  final LiveSessionService service;
  final String classroomId;
  final String activityId;

  const _ResponsesLive({
    required this.service,
    required this.classroomId,
    required this.activityId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LiveResponse>>(
      stream: service.watchResponses(
        classroomId: classroomId,
        activityId: activityId,
      ),
      builder: (context, snap) {
        final responses = snap.data ?? const <LiveResponse>[];
        return Text(
          responses.isEmpty
              ? 'Waiting for student responses…'
              : '${responses.length} responded: '
                  '${responses.map((r) => r.profileName).join(', ')}',
        );
      },
    );
  }
}

// ─── Student ──────────────────────────────────────────

class _StudentView extends ConsumerStatefulWidget {
  final UserProfile profile;
  const _StudentView({required this.profile});

  @override
  ConsumerState<_StudentView> createState() => _StudentViewState();
}

class _StudentViewState extends ConsumerState<_StudentView> {
  static const _service = LiveSessionService();
  String? _respondedActivityId;

  @override
  Widget build(BuildContext context) {
    final classroomId = widget.profile.classroomId;
    if (classroomId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'You are not in a classroom yet. Use "Join a class" first.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final flashcards = ref.watch(allFlashcardsProvider);

    return StreamBuilder<LiveSession?>(
      stream: _service.watchSession(classroomId),
      builder: (context, snap) {
        final session = snap.data;
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (session == null || session.status == LiveSessionStatus.ended) {
          return const Center(
            child: Text('No active session. Wait for your teacher.'),
          );
        }
        final activity = session.currentActivity;
        if (activity == null) {
          return const Center(
            child: Text('Waiting for the teacher to push an activity…'),
          );
        }
        return _activityCard(activity, flashcards, classroomId);
      },
    );
  }

  Widget _activityCard(
    LiveActivity activity,
    List<Flashcard> flashcards,
    String classroomId,
  ) {
    final id = activity.payload['flashcard_id'] as String?;
    final card = flashcards.firstWhere(
      (c) => c.id == id,
      orElse: () => Flashcard(
        id: id ?? 'unknown',
        wordEnglish: 'Unknown card',
        wordFilipino: '',
        category: FlashcardCategory.animals,
      ),
    );
    final alreadyResponded = _respondedActivityId == activity.id;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(
                    card.wordEnglish,
                    style: Theme.of(context).textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    card.wordFilipino,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: Icon(alreadyResponded
                ? Icons.check_circle
                : Icons.thumb_up_alt_outlined),
            label: Text(alreadyResponded ? 'Sent!' : 'Got it!'),
            onPressed: alreadyResponded
                ? null
                : () async {
                    await _service.submitResponse(
                      classroomId: classroomId,
                      activityId: activity.id,
                      profileId: widget.profile.id,
                      profileName: widget.profile.name,
                      payload: const {'got_it': true},
                    );
                    if (!mounted) return;
                    setState(() => _respondedActivityId = activity.id);
                  },
          ),
        ],
      ),
    );
  }
}
