import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../models/messaging_models.dart';
import '../services/cloud_message_repository.dart';

/// "Message the whole class" for teachers and parents.
///
/// A teacher with a class of Deaf learners had to open each thread in turn to
/// say the same "No class tomorrow — see you Monday!". This writes the same
/// message into every chosen learner's own thread: each one is an ordinary
/// one-to-one message, so it is read, badged, read aloud and answered exactly
/// like any other, and a learner's reply stays private to the teacher.

/// The learners a broadcast reaches: every linked learner, or only those in
/// [groupId]. History-only threads (a learner who left) never receive one.
List<Conversation> broadcastTargets(
  List<Conversation> conversations, {
  String? groupId,
}) => [
  for (final c in conversations)
    if (c.isConnected &&
        !c.isEducatorPeer &&
        (groupId == null || c.groups.any((g) => g.id == groupId)))
      c,
];

/// One message per target, all carrying the same words and time.
List<LocalMessage> broadcastMessages({
  required UserProfile sender,
  required List<Conversation> targets,
  required String content,
  required MessageType type,
  required String Function() newId,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  return [
    for (final t in targets)
      LocalMessage(
        id: newId(),
        senderId: sender.id,
        senderName: sender.name,
        recipientId: t.otherProfileId,
        content: content,
        type: type,
        timestamp: at,
      ),
  ];
}

/// Shows the sheet; resolves to how many learners were messaged, or null if
/// the educator backed out.
Future<int?> showBroadcastSheet(
  BuildContext context, {
  required UserProfile me,
  required List<Conversation> conversations,
  required List<InboxGroup> groups,
  String? initialGroupId,
  required bool isFilipino,
}) {
  return showModalBottomSheet<int>(
    context: context,
    // Without this the dismiss barrier announces itself as "Scrim",
    // Material's untranslated default.
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BroadcastSheet(
      me: me,
      conversations: conversations,
      groups: groups,
      initialGroupId: initialGroupId,
      isFilipino: isFilipino,
    ),
  );
}

class BroadcastSheet extends StatefulWidget {
  final UserProfile me;
  final List<Conversation> conversations;
  final List<InboxGroup> groups;
  final String? initialGroupId;
  final bool isFilipino;

  const BroadcastSheet({
    super.key,
    required this.me,
    required this.conversations,
    required this.groups,
    required this.isFilipino,
    this.initialGroupId,
  });

  @override
  State<BroadcastSheet> createState() => _BroadcastSheetState();
}

class _BroadcastSheetState extends State<BroadcastSheet> {
  final _controller = TextEditingController();
  late String? _groupId = widget.groups.any((g) => g.id == widget.initialGroupId)
      ? widget.initialGroupId
      : null;
  bool _sending = false;

  /// The chip the text came from, so an untouched chip goes out as an
  /// encouragement (with its heart) and anything typed goes out as text.
  String? _chipText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Conversation> get _targets =>
      broadcastTargets(widget.conversations, groupId: _groupId);

  bool get _isParent => widget.me.role == UserRole.parent;

  Future<void> _send() async {
    final content = _controller.text.trim();
    final targets = _targets;
    if (content.isEmpty || targets.isEmpty || _sending) return;
    setState(() => _sending = true);
    const uuid = Uuid();
    await CloudMessageRepository.instance.sendMessages(
      broadcastMessages(
        sender: widget.me,
        targets: targets,
        content: content,
        type: content == _chipText
            ? MessageType.encouragement
            : MessageType.text,
        newId: uuid.v4,
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(targets.length);
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final fil = widget.isFilipino;
    final targets = _targets;
    final count = targets.length;
    final who = _isParent
        ? (fil ? 'anak' : (count == 1 ? 'child' : 'children'))
        : (fil ? 'mag-aaral' : (count == 1 ? 'learner' : 'learners'));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isParent
                    ? (fil
                          ? 'Magpadala sa buong pamilya'
                          : 'Message the whole family')
                    : (fil
                          ? 'Magpadala sa buong klase'
                          : 'Message the whole class'),
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fil
                    ? 'Darating ito sa sariling usapan ng bawat isa. Ikaw lang ang makakakita ng kanilang sagot.'
                    : "It arrives in each one's own chat. Only you see their replies.",
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
              if (widget.groups.length > 1) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text(
                        '${fil ? 'Lahat' : 'Everyone'} '
                        '(${broadcastTargets(widget.conversations).length})',
                      ),
                      selected: _groupId == null,
                      onSelected: (_) => setState(() => _groupId = null),
                    ),
                    for (final g in widget.groups)
                      ChoiceChip(
                        avatar: Text(g.isHomeGroup ? '🏠' : '🏫'),
                        label: Text(
                          '${g.name} '
                          '(${broadcastTargets(widget.conversations, groupId: g.id).length})',
                        ),
                        selected: _groupId == g.id,
                        onSelected: (_) => setState(() => _groupId = g.id),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final chip in QuickEncouragements.encouragements.take(4))
                    ActionChip(
                      label: Text(
                        fil ? chip['fil']! : chip['en']!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        final text = fil ? chip['fil']! : chip['en']!;
                        _controller.text = text;
                        _controller.selection = TextSelection.collapsed(
                          offset: text.length,
                        );
                        setState(() => _chipText = text);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: fil
                      ? 'Isulat ang mensahe…'
                      : 'Write your message…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed:
                    _controller.text.trim().isEmpty || count == 0 || _sending
                    ? null
                    : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  fil
                      ? 'Ipadala sa $count $who'
                      : 'Send to $count $who',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: hc.fillFor(AppColors.primary),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
