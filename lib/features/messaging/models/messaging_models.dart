import 'package:flutter/material.dart';

/// Type of message in the local message board.
///
/// Persisted by `index` (see [LocalMessage.fromJson]), so new values must be
/// appended and never reordered.
enum MessageType { text, encouragement, sticker, achievement, sign }

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

  const LocalMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

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

/// A conversation thread between two profiles
class Conversation {
  final String otherProfileId;
  final String otherProfileName;
  final String otherProfileRole;
  final List<LocalMessage> messages;

  const Conversation({
    required this.otherProfileId,
    required this.otherProfileName,
    required this.otherProfileRole,
    this.messages = const [],
  });

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
    if (_isEducator(senderRole)) return encouragements;
    if (_isEducator(recipientRole)) return toEducator;
    return toFriend;
  }

  static bool _isEducator(String role) {
    final r = role.toLowerCase();
    return r == 'teacher' || r == 'parent';
  }
}
