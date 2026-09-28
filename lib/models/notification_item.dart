enum NotificationType { lowStock, payment, creditOverdue, orderReady }

class NotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final String timeAgo;
  final NotificationType type;
  final bool unread;
  final DateTime? createdAt;

  const NotificationItem({
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    required this.type,
    this.id = '',
    this.unread = true,
    this.createdAt,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? timeAgo,
    NotificationType? type,
    bool? unread,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timeAgo: timeAgo ?? this.timeAgo,
      type: type ?? this.type,
      unread: unread ?? this.unread,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'timeAgo': timeAgo,
        'type': type.name,
        'unread': unread,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    final typeName = (map['type'] as String?) ?? 'payment';
    final type = NotificationType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => NotificationType.payment,
    );
    DateTime? created;
    final rawCreated = map['createdAt'];
    if (rawCreated is String && rawCreated.isNotEmpty) {
      created = DateTime.tryParse(rawCreated);
    }
    return NotificationItem(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      subtitle: (map['subtitle'] ?? '').toString(),
      timeAgo: (map['timeAgo'] ?? '').toString(),
      type: type,
      unread: map['unread'] != false,
      createdAt: created,
    );
  }

  String get displayTime {
    if (createdAt == null) return timeAgo;
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return timeAgo.isNotEmpty ? timeAgo : '${diff.inDays}d ago';
  }
}
