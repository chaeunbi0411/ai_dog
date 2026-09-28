import '../../services/daily_care_service.dart';

class CareReminder {
  const CareReminder(this.uid, this.role, this.action, this.date);
  final String uid;
  final String role;
  final String action;
  final String date;
  String get key => '$date:$uid:$action';
  String get message {
    final request = switch (careActions.indexOf(action)) {
      0 => '배고파요',
      1 => '씻고 싶어요',
      2 => '같이 놀고 싶어요',
      3 => '졸려요, 재워주세요',
      _ => '함께 돌봐주세요',
    };
    return '$role $request!';
  }
}

List<CareReminder> pendingCareReminders(
  Map<String, dynamic> care,
  Map<String, dynamic> members,
  DateTime now, {
  bool ignoreDeadlines = false,
}) {
  if (care['_dateId'] != null && care['_dateId'] != careDate(now)) return [];
  final hour = now.toUtc().add(const Duration(hours: 9)).hour;
  // Don't wake the household overnight. Actions have separate due times.
  if (!ignoreDeadlines && hour < 8) return [];
  final reminders = <CareReminder>[];
  const deadlines = [12, 18, 18, 21];
  for (var i = 0; i < careActions.length; i++) {
    if (!ignoreDeadlines && hour < deadlines[i]) continue;
    for (final uid in members.keys.toList()..sort()) {
      final record = care[uid];
      if (record is Map &&
          record['action'] == careActions[i] &&
          record['completedAt'] == null) {
        reminders.add(
          CareReminder(
            uid,
            members[uid] as String,
            careActions[i],
            careDate(now),
          ),
        );
      }
    }
  }
  return reminders;
}

CareReminder? pendingCare(
  Map<String, dynamic> care,
  Map<String, dynamic> members,
  DateTime now, {
  bool ignoreDeadlines = false,
}) => pendingCareReminders(
  care,
  members,
  now,
  ignoreDeadlines: ignoreDeadlines,
).firstOrNull;
