import 'package:flutter/material.dart';

/// Type of message in the local message board.
///
/// Persisted by `index` (see [LocalMessage.fromJson]), so new values must be
/// appended and never reordered.
enum MessageType {
  text,
  encouragement,
  sticker,
  achievement,
  sign,
  report,

  /// A photo taken in the app; content is its `shared://` value.
  photo,

  /// A short recorded clip — usually the sender signing; content is its
  /// `shared://` value.
  video,
}

extension MessageTypeExt on MessageType {
  String get label {
    switch (this) {
      case MessageType.text:
        return 'Text';
      case MessageType.encouragement:
        return 'Encouragement';
      case MessageType.sticker:
        return 'Sticker';
      case MessageType.achievement:
        return 'Achievement';
      case MessageType.sign:
        return 'Sign';
      case MessageType.report:
        return 'Safety report';
      case MessageType.photo:
        return 'Photo';
      case MessageType.video:
        return 'Video';
    }
  }

  String get labelFilipino {
    switch (this) {
      case MessageType.text:
        return 'Text';
      case MessageType.encouragement:
        return 'Pagpapalakas ng Loob';
      case MessageType.sticker:
        return 'Sticker';
      case MessageType.achievement:
        return 'Achievement';
      case MessageType.sign:
        return 'Senyas';
      case MessageType.report:
        return 'Ulat pangkaligtasan';
      case MessageType.photo:
        return 'Larawan';
      case MessageType.video:
        return 'Video';
    }
  }

  IconData get icon {
    switch (this) {
      case MessageType.text:
        return Icons.chat_bubble_outline_rounded;
      case MessageType.encouragement:
        return Icons.favorite_rounded;
      case MessageType.sticker:
        return Icons.emoji_emotions_rounded;
      case MessageType.achievement:
        return Icons.emoji_events_rounded;
      case MessageType.sign:
        return Icons.sign_language_rounded;
      case MessageType.report:
        return Icons.flag_rounded;
      case MessageType.photo:
        return Icons.photo_camera_rounded;
      case MessageType.video:
        return Icons.videocam_rounded;
    }
  }
}

/// Reads a persisted [MessageType] index safely.
///
/// Types are stored as an int, so a device on an older build can receive a
/// message whose type it has never heard of. Falling back to [MessageType.text]
/// shows the content rather than throwing a range error mid-thread.
MessageType _messageTypeFromIndex(int? index) {
  if (index == null || index < 0 || index >= MessageType.values.length) {
    return MessageType.text;
  }
  return MessageType.values[index];
}

/// A single message in a conversation
class LocalMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;

  /// Words sent with a photo or video — what the sign means, for a
  /// recipient who does not sign. Null for every other type.
  final String? caption;

  const LocalMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.caption,
  });

  /// A photo or video: [content] is a shared file, not words.
  bool get isMedia => type == MessageType.photo || type == MessageType.video;

  LocalMessage copyWith({bool? isRead}) {
    return LocalMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      recipientId: recipientId,
      content: content,
      type: type,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      caption: caption,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'recipientId': recipientId,
    'content': content,
    'type': type.index,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'caption': ?caption,
  };

  factory LocalMessage.fromJson(Map<String, dynamic> json) => LocalMessage(
    id: json['id'] as String,
    senderId: json['senderId'] as String,
    senderName: json['senderName'] as String? ?? '',
    recipientId: json['recipientId'] as String,
    content: json['content'] as String,
    // Clamped rather than indexed blind: a device running an older build must
    // degrade a newer message type to text, not crash on a range error.
    type: _messageTypeFromIndex(json['type'] as int?),
    timestamp: DateTime.parse(json['timestamp'] as String),
    isRead: json['isRead'] as bool? ?? false,
    caption: json['caption'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A class or home group an educator's learner belongs to — what the
/// educator inbox filters by and what "message the whole class" targets.
class InboxGroup {
  final String id;
  final String name;

  /// A parent's home group rather than a teacher's classroom. Drives the
  /// wording ("family group" vs "class") wherever the group is named.
  final bool isHomeGroup;

  const InboxGroup({
    required this.id,
    required this.name,
    this.isHomeGroup = false,
  });

  @override
  bool operator ==(Object other) =>
      other is InboxGroup && other.id == id && other.isHomeGroup == isHomeGroup;

  @override
  int get hashCode => Object.hash(id, isHomeGroup);
}

/// A conversation thread between two profiles
class Conversation {
  final String otherProfileId;
  final String otherProfileName;
  final String otherProfileRole;
  final List<LocalMessage> messages;

  /// Whether the two profiles are still linked — a friendship, a class or a
  /// home group. False for a thread that is only history: a friend who was
  /// removed or who blocked you, a learner who left the class. Such a thread
  /// stays readable, but it has no composer, so the history never turns
  /// into a back door around the removal.
  final bool isConnected;

  /// The peer's accessibility category ([DisabilityType] index), from the
  /// profile directory. Lets an educator's composer suggest the channel the
  /// learner can actually receive — a sign for a Deaf child.
  final int? otherDisabilityIndex;

  /// The educator's classes / home groups this learner is in. Empty in a
  /// learner's own inbox.
  final List<InboxGroup> groups;

  const Conversation({
    required this.otherProfileId,
    required this.otherProfileName,
    required this.otherProfileRole,
    this.messages = const [],
    this.isConnected = true,
    this.otherDisabilityIndex,
    this.groups = const [],
  });

  Conversation copyWith({
    List<LocalMessage>? messages,
    bool? isConnected,
  }) {
    return Conversation(
      otherProfileId: otherProfileId,
      otherProfileName: otherProfileName,
      otherProfileRole: otherProfileRole,
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      otherDisabilityIndex: otherDisabilityIndex,
      groups: groups,
    );
  }

  /// A teacher or parent — someone the learner reaches through a class or
  /// home group rather than a friendship.
  bool get isEducatorPeer => isEducatorRole(otherProfileRole);

  /// The newest message the other party sent — what a report quotes. The
  /// thread's last message is often the reporter's own.
  LocalMessage? get lastInbound {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].senderId == otherProfileId) return messages[i];
    }
    return null;
  }

  /// An unread safety report is waiting in this thread (educator inbox).
  bool get hasUnreadReport => messages.any(
    (m) =>
        m.senderId == otherProfileId &&
        !m.isRead &&
        m.type == MessageType.report,
  );

  /// Messages **the other party sent me** that I haven't opened yet.
  ///
  /// The sender check must be `== otherProfileId`: my own outgoing messages
  /// carry `isRead: false` until the recipient opens them, so counting those
  /// would badge every thread I have ever written in.
  int get unreadCount =>
      messages.where((m) => m.senderId == otherProfileId && !m.isRead).length;

  /// The unread messages, oldest first — what [markConversationRead] patches.
  List<LocalMessage> get unreadMessages =>
      messages.where((m) => m.senderId == otherProfileId && !m.isRead).toList();

  LocalMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;

  String get roleEmoji {
    switch (otherProfileRole.toLowerCase()) {
      case 'teacher':
        return '👩‍🏫';
      case 'parent':
        return '👨‍👩‍👦';
      default:
        return '🧑‍🎓';
    }
  }
}

/// Whether a role slug (as [Conversation.otherProfileRole] carries it) is a
/// teacher or parent.
bool isEducatorRole(String role) {
  final r = role.toLowerCase();
  return r == 'teacher' || r == 'parent';
}

/// Builds the inbox from the directory's peers and the live message stream.
///
/// Pure, so the rules that decide who appears — the ones that went wrong —
/// are unit-testable without Firebase:
///
///   * **A blocked peer never appears**, not even through the history
///     fallback. The fallback used to re-add anyone who had ever written to
///     you, so blocking a friend who had sent a message left them in the
///     inbox with a working composer.
///   * **History without a link is read-only.** A thread whose peer is no
///     longer in the directory (unfriended, left the class) still shows —
///     including in the short window before a just-accepted friendship
///     reaches this device — but as [Conversation.isConnected] false.
///   * Newest conversation first; empty threads alphabetically after.
List<Conversation> assembleInbox({
  required String myProfileId,
  required List<Conversation> peers,
  required List<LocalMessage> messages,
  Set<String> blockedIds = const {},
}) {
  final grouped = <String, List<LocalMessage>>{};
  for (final msg in messages) {
    final otherId = msg.senderId == myProfileId ? msg.recipientId : msg.senderId;
    if (otherId.isEmpty || otherId == myProfileId) continue;
    if (blockedIds.contains(otherId)) continue;
    grouped.putIfAbsent(otherId, () => []).add(msg);
  }

  List<LocalMessage> sorted(List<LocalMessage>? list) =>
      [...?list]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final convos = <Conversation>[];
  final known = <String>{};
  for (final peer in peers) {
    if (blockedIds.contains(peer.otherProfileId)) continue;
    if (!known.add(peer.otherProfileId)) continue;
    convos.add(
      peer.copyWith(
        messages: sorted(grouped[peer.otherProfileId]),
        isConnected: true,
      ),
    );
  }

  for (final entry in grouped.entries) {
    if (known.contains(entry.key)) continue;
    final inbound = entry.value.where((m) => m.senderId == entry.key);
    if (inbound.isEmpty) continue;
    final name = inbound.first.senderName.isEmpty
        ? 'User'
        : inbound.first.senderName;
    convos.add(
      Conversation(
        otherProfileId: entry.key,
        otherProfileName: name,
        otherProfileRole: 'student',
        messages: sorted(entry.value),
        isConnected: false,
      ),
    );
  }

  convos.sort((a, b) {
    final aLast = a.lastMessage?.timestamp;
    final bLast = b.lastMessage?.timestamp;
    if (aLast != null && bLast != null) return bLast.compareTo(aLast);
    if (aLast != null) return -1;
    if (bLast != null) return 1;
    return a.otherProfileName.toLowerCase().compareTo(
      b.otherProfileName.toLowerCase(),
    );
  });
  return convos;
}

/// How a message reads outside its bubble: the inbox preview line, the words
/// a screen reader says, and the words the read-aloud button speaks.
///
/// A sign message's content is just the word ("Apple"), so the inbox used to
/// preview it as if someone had typed "Apple"; a screen reader announced a
/// received bubble by the avatar's initial ("H, try"), never the sender.
class MessageWording {
  const MessageWording._();

  /// One-line inbox preview.
  static String preview(LocalMessage message, {required bool isFilipino}) {
    switch (message.type) {
      case MessageType.sign:
        return isFilipino
            ? '🤟 Senyas: ${message.content}'
            : '🤟 Sign: ${message.content}';
      case MessageType.sticker:
        final name = MessageStickerNames.nameOf(
          message.content,
          isFilipino: isFilipino,
        );
        return name == null ? message.content : '${message.content} $name';
      case MessageType.report:
        return isFilipino ? '🚩 Ulat pangkaligtasan' : '🚩 Safety report';
      case MessageType.photo:
        return _withCaption(isFilipino ? '📷 Larawan' : '📷 Photo', message);
      case MessageType.video:
        return _withCaption(isFilipino ? '🎬 Video' : '🎬 Video', message);
      case MessageType.text:
      case MessageType.encouragement:
      case MessageType.achievement:
        return message.content;
    }
  }

  static String _withCaption(String label, LocalMessage message) {
    final caption = message.caption?.trim() ?? '';
    return caption.isEmpty ? label : '$label: $caption';
  }

  /// What a screen reader says for one bubble.
  static String bubbleLabel(
    LocalMessage message, {
    required bool isMine,
    required String otherName,
    required bool isFilipino,
  }) {
    final who = isMine
        ? (isFilipino ? 'Ikaw' : 'You')
        : (otherName.isNotEmpty ? otherName : message.senderName);
    final body = switch (message.type) {
      MessageType.sign =>
        isFilipino
            ? 'nagpadala ng senyas para sa ${message.content}'
            : 'sent the sign for ${message.content}',
      MessageType.sticker =>
        isFilipino
            ? 'nagpadala ng sticker: ${MessageStickerNames.nameOf(message.content, isFilipino: true) ?? message.content}'
            : 'sent a sticker: ${MessageStickerNames.nameOf(message.content, isFilipino: false) ?? message.content}',
      MessageType.report =>
        isFilipino
            ? 'ulat pangkaligtasan: ${message.content}'
            : 'safety report: ${message.content}',
      MessageType.encouragement =>
        isFilipino
            ? 'pagpapalakas ng loob: ${message.content}'
            : 'encouragement: ${message.content}',
      MessageType.photo => _withCaption(
        isFilipino ? 'nagpadala ng larawan' : 'sent a photo',
        message,
      ),
      MessageType.video => _withCaption(
        isFilipino ? 'nagpadala ng video' : 'sent a video',
        message,
      ),
      _ => message.content,
    };
    final time = MessageTime.clock(message.timestamp);
    final receipt = !isMine
        ? ''
        : message.isRead
        ? (isFilipino ? ', nabasa na' : ', read')
        : (isFilipino ? ', naipadala' : ', sent');
    return '$who: $body, $time$receipt';
  }

  /// The words the read-aloud button speaks: the content without emoji,
  /// which a speech engine reads out as "sparkles", "flexed biceps"…
  static String speakable(LocalMessage message, {required bool isFilipino}) {
    switch (message.type) {
      case MessageType.sticker:
        return MessageStickerNames.nameOf(
              message.content,
              isFilipino: isFilipino,
            ) ??
            '';
      case MessageType.sign:
        return message.content;
      case MessageType.photo:
      case MessageType.video:
        final caption = stripEmoji(message.caption ?? '');
        final what = message.type == MessageType.photo
            ? (isFilipino ? 'Larawan' : 'A photo')
            : (isFilipino ? 'Video' : 'A video');
        return caption.isEmpty ? what : '$what. $caption';
      case MessageType.text:
      case MessageType.encouragement:
      case MessageType.achievement:
      case MessageType.report:
        return stripEmoji(message.content);
    }
  }

  /// [text] with pictographs, variation selectors and joiners removed and
  /// the leftover spacing tidied.
  static String stripEmoji(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final isPictograph =
          (rune >= 0x1F000 && rune <= 0x1FAFF) || // emoji blocks
          (rune >= 0x2600 && rune <= 0x27BF) || // symbols & dingbats
          (rune >= 0x2B00 && rune <= 0x2BFF) || // stars, arrows
          (rune >= 0x2190 && rune <= 0x21FF) || // arrows
          rune == 0x200D || // zero-width joiner
          (rune >= 0xFE00 && rune <= 0xFE0F) || // variation selectors
          (rune >= 0x1F3FB && rune <= 0x1F3FF); // skin tones
      if (!isPictograph) buffer.writeCharCode(rune);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

/// Delivers a learner's report to the grown-ups who can act on it.
///
/// Reports used to land only in `message_reports`, a collection no app user
/// can read (`allow read: if false`), while the child was told "Sent to a
/// grown-up. They'll look into it." Nobody ever would. Now each of the
/// learner's own grown-ups — the class teacher, the home-group parent —
/// gets the report as a message in their thread with the child, where it is
/// badged, highlighted, and answerable. Messages are already readable by
/// the recipient, so this needs no new security rule.
class SafetyReport {
  const SafetyReport._();

  /// Longest quoted message carried in a report.
  static const int maxQuote = 140;

  /// Who hears about a report on [reportedId]: every grown-up in the
  /// learner's inbox except the person reported — a report about the
  /// teacher goes to the parent, never to the teacher.
  static List<Conversation> recipients({
    required List<Conversation> grownUps,
    required String reportedId,
  }) => [
    for (final g in grownUps)
      if (g.isEducatorPeer && g.isConnected && g.otherProfileId != reportedId)
        g,
  ];

  /// The report text, in the reporter's language. Curly quotes around the
  /// quoted message: a straight `"` inside a label blanks the whole
  /// accessibility description on Android.
  static String content({
    required String reportedName,
    required String reason,
    String? quote,
    required bool isFilipino,
  }) {
    final base = isFilipino
        ? 'Iniulat ko si $reportedName: $reason.'
        : 'I reported $reportedName: $reason.';
    final q = quote?.trim() ?? '';
    if (q.isEmpty) return base;
    final clipped = q.length > maxQuote ? '${q.substring(0, maxQuote)}…' : q;
    return isFilipino
        ? '$base Isinulat nila: “$clipped”'
        : '$base They wrote: “$clipped”';
  }

  /// One report message per recipient.
  static List<LocalMessage> messages({
    required String reporterId,
    required String reporterName,
    required List<Conversation> recipients,
    required String content,
    required String Function() newId,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return [
      for (final r in recipients)
        LocalMessage(
          id: newId(),
          senderId: reporterId,
          senderName: reporterName,
          recipientId: r.otherProfileId,
          content: content,
          type: MessageType.report,
          timestamp: at,
        ),
    ];
  }
}

/// Spoken names for the sticker set, so a sticker can be read aloud and
/// announced by name rather than as an unnamed picture.
class MessageStickerNames {
  const MessageStickerNames._();

  static const Map<String, (String, String)> _names = {
    '👍': ('thumbs up', 'thumbs up'),
    '❤️': ('heart', 'puso'),
    '😀': ('happy face', 'masayang mukha'),
    '😂': ('laughing', 'tumatawa'),
    '🎉': ('party', 'pagdiriwang'),
    '⭐': ('star', 'bituin'),
    '🏆': ('trophy', 'tropeo'),
    '👏': ('clapping', 'palakpak'),
    '🤝': ('handshake', 'kamayan'),
    '💪': ('strong', 'malakas'),
    '🌈': ('rainbow', 'bahaghari'),
    '🌟': ('shining star', 'nagniningning na bituin'),
    '📚': ('books', 'mga libro'),
    '✏️': ('pencil', 'lapis'),
    '🎨': ('painting', 'pagpipinta'),
    '⚽': ('soccer ball', 'bola'),
  };

  /// The sticker's name, or null for an emoji outside the set.
  static String? nameOf(String sticker, {required bool isFilipino}) {
    final names = _names[sticker];
    if (names == null) return null;
    return isFilipino ? names.$2 : names.$1;
  }
}

/// Time formatting shared by the inbox rows and the thread bubbles, so a
/// conversation's "when" reads the same in both places.
///
/// Deliberately hand-rolled rather than `intl`: the app ships exactly two
/// languages with hand-written strings, and a 12-hour clock plus a short
/// relative label is all either surface needs.
class MessageTime {
  /// Wall-clock time inside a thread bubble, e.g. `3:42 PM`.
  static String clock(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  /// Compact age for an inbox row, e.g. `Now`, `5m`, `3h`, `2d`, `12/03`.
  /// [now] is injectable so tests don't depend on the wall clock.
  static String relative(
    DateTime time, {
    required bool isFilipino,
    DateTime? now,
  }) {
    final diff = (now ?? DateTime.now()).difference(time);
    if (diff.inMinutes < 1) return isFilipino ? 'Ngayon' : 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  /// Day divider above the first bubble of each calendar day.
  static String dayLabel(
    DateTime time, {
    required bool isFilipino,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final that = DateTime(time.year, time.month, time.day);
    final delta = today.difference(that).inDays;
    if (delta == 0) return isFilipino ? 'Ngayon' : 'Today';
    if (delta == 1) return isFilipino ? 'Kahapon' : 'Yesterday';
    return '${that.year}-${that.month.toString().padLeft(2, '0')}-'
        '${that.day.toString().padLeft(2, '0')}';
  }
}

/// Pre-defined one-tap messages shown above the composer.
///
/// These are **role-aware**. The original single list was written from an
/// educator's mouth ("I'm proud of you!", "Keep learning!"), so a student
/// tapping a chip ended up praising their own teacher. [forAudience] picks the
/// phrasing that actually fits who the sender is talking to, which matters
/// doubly here: for learners who can't compose free text, these chips *are*
/// the messaging feature.
class QuickEncouragements {
  /// Educator → learner: praise and encouragement.
  static const List<Map<String, String>> encouragements = [
    {'en': 'Great job! Keep it up! 🌟', 'fil': 'Magaling! Ituloy mo! 🌟'},
    {'en': "I'm proud of you! 💪", 'fil': 'Proud ako sa iyo! 💪'},
    {'en': "You're doing amazing! 🎉", 'fil': 'Napakagaling mo! 🎉'},
    {'en': 'Keep learning! 📚', 'fil': 'Patuloy na matuto! 📚'},
    {'en': "You're a star! ⭐", 'fil': 'Isa kang bituin! ⭐'},
    {'en': 'Well done today! 👏', 'fil': 'Napakahusay ngayon! 👏'},
    {'en': 'I believe in you! 🙌', 'fil': 'Naniniwala ako sa iyo! 🙌'},
    {'en': 'Way to go, champ! 🏆', 'fil': 'Tuloy lang, kampeon! 🏆'},
  ];

  /// Learner → educator: the things a student actually needs to say — greet,
  /// ask for help, report progress, ask for a repeat.
  static const List<Map<String, String>> toEducator = [
    {'en': 'Hello po! 👋', 'fil': 'Hello po! 👋'},
    {'en': 'Thank you po! 🙏', 'fil': 'Salamat po! 🙏'},
    {'en': 'I need help please 🙋', 'fil': 'Kailangan ko po ng tulong 🙋'},
    {'en': "I'm done with my work ✅", 'fil': 'Tapos na po ako ✅'},
    {'en': "I don't understand yet 😕", 'fil': 'Hindi ko po maintindihan 😕'},
    {'en': 'Can you repeat it po? 🔁', 'fil': 'Pwede po bang ulitin? 🔁'},
    {
      'en': "I'm not feeling well 🤒",
      'fil': 'Hindi po ako maganda ang pakiramdam 🤒',
    },
    {'en': 'Good bye po! 👋', 'fil': 'Paalam po! 👋'},
  ];

  /// Learner → learner: friendly peer chat.
  static const List<Map<String, String>> toFriend = [
    {'en': 'Hi friend! 👋', 'fil': 'Hi kaibigan! 👋'},
    {'en': 'Want to play? 🎮', 'fil': 'Gusto mong maglaro? 🎮'},
    {'en': 'Good job! 🌟', 'fil': 'Magaling! 🌟'},
    {'en': 'Thank you! 🙏', 'fil': 'Salamat! 🙏'},
    {'en': "Let's study together 📚", 'fil': 'Mag-aral tayo 📚'},
    {'en': 'That was fun! 😄', 'fil': 'Ang saya nun! 😄'},
    {'en': 'See you later! 👋', 'fil': 'Kita tayo mamaya! 👋'},
    {'en': 'Congrats! 🎉', 'fil': 'Congrats! 🎉'},
  ];

  /// Chips for a sender in [senderRole] writing to a peer in [recipientRole].
  /// Roles are the lowercase slugs [Conversation.otherProfileRole] carries.
  static List<Map<String, String>> forAudience({
    required String senderRole,
    required String recipientRole,
  }) {
    if (isEducatorRole(senderRole)) return encouragements;
    if (isEducatorRole(recipientRole)) return toEducator;
    return toFriend;
  }

  /// The message type a chip is sent as. Only an educator's chips are
  /// encouragement — a learner's "Hi friend!" or "I need help please" used to
  /// arrive under a pink "Encouragement" banner too.
  static MessageType typeFor({required String senderRole}) =>
      isEducatorRole(senderRole) ? MessageType.encouragement : MessageType.text;
}
