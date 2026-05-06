import 'package:flutter/material.dart';

/// Type of message in the local message board
enum MessageType {
  text,
  encouragement,
  sticker,
  achievement,
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
    }
  }
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
        type: MessageType.values[json['type'] as int? ?? 0],
        timestamp: DateTime.parse(json['timestamp'] as String),
        isRead: json['isRead'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalMessage && runtimeType == other.runtimeType && id == other.id;

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

  int get unreadCount => messages.where((m) => !m.isRead && m.senderId != otherProfileId).length;

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

/// Pre-defined encouragement messages
class QuickEncouragements {
  static const List<Map<String, String>> items = [
    {'en': 'Great job! Keep it up! 🌟', 'fil': 'Magaling! Ituloy mo! 🌟'},
    {'en': "I'm proud of you! 💪", 'fil': 'Proud ako sa iyo! 💪'},
    {'en': 'You\'re doing amazing! 🎉', 'fil': 'Napakagaling mo! 🎉'},
    {'en': 'Keep learning! 📚', 'fil': 'Patuloy na matuto! 📚'},
    {'en': 'You\'re a star! ⭐', 'fil': 'Isa kang bituin! ⭐'},
    {'en': 'Well done today! 👏', 'fil': 'Napakahusay ngayon! 👏'},
    {'en': 'I believe in you! 🙌', 'fil': 'Naniniwala ako sa iyo! 🙌'},
    {'en': 'Way to go, champ! 🏆', 'fil': 'Tuloy lang, kampeon! 🏆'},
  ];
}
