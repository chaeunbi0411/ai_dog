import 'package:flutter_test/flutter_test.dart';
import 'package:mira/dog_room/models/care_reminder.dart';
import 'package:mira/services/daily_care_service.dart';

void main() {
  test(
    'all overdue members remain selectable until their care is complete',
    () {
      final now = DateTime.parse('2026-09-28T21:00:00+09:00');
      final care = <String, dynamic>{
        '_dateId': careDate(now),
        'mom': {'action': careActions[0], 'completedAt': null},
        'dad': {'action': careActions[2], 'completedAt': null},
        'sister': {'action': careActions[3], 'completedAt': null},
      };
      final members = {'mom': '엄마', 'dad': '아빠', 'sister': '언니'};
      expect(pendingCareReminders(care, members, now).map((r) => r.uid), [
        'mom',
        'dad',
        'sister',
      ]);
      care['mom']['completedAt'] = 'saved';
      expect(pendingCareReminders(care, members, now).map((r) => r.uid), [
        'dad',
        'sister',
      ]);
    },
  );
  test(
    'preview skips time limits but keeps actual assignments and completion',
    () {
      final now = DateTime.parse('2026-09-08T10:00:00+09:00');
      final care = <String, dynamic>{
        '_dateId': careDate(now),
        'a': {'action': careActions[2], 'completedAt': null},
      };
      expect(pendingCare(care, {'a': '몰라요'}, now), isNull);
      expect(
        pendingCare(care, {'a': '몰라요'}, now, ignoreDeadlines: true)?.message,
        '몰라요 같이 놀고 싶어요!',
      );
      care['a']['completedAt'] = 'saved';
      expect(
        pendingCare(care, {'a': '몰라요'}, now, ignoreDeadlines: true),
        isNull,
      );
    },
  );
  test('requests match the assigned member and care action', () {
    expect(
      CareReminder('a', '아빠', careActions[0], 'today').message,
      '아빠 배고파요!',
    );
    expect(
      CareReminder('b', '엄마', careActions[1], 'today').message,
      '엄마 씻고 싶어요!',
    );
    expect(
      CareReminder('c', '언니', careActions[2], 'today').message,
      '언니 같이 놀고 싶어요!',
    );
    expect(
      CareReminder('d', '오빠', careActions[3], 'today').message,
      '오빠 졸려요, 재워주세요!',
    );
  });
  test('resuming on a later day does not announce stale assignments', () {
    expect(
      pendingCare(
        {
          '_dateId': '2026-09-06',
          'a': {'action': careActions[0], 'completedAt': null},
        },
        {'a': '아빠'},
        DateTime.parse('2026-09-07T12:00:00+09:00'),
      ),
      isNull,
    );
  });
  test(
    'care date resets at 8 AM Korea time, independent of device timezone',
    () {
      expect(
        careDate(DateTime.parse('2026-01-01T07:59:59+09:00')),
        '2025-12-31',
      );
      expect(
        careDate(DateTime.parse('2026-01-01T08:00:00+09:00')),
        '2026-01-01',
      );
    },
  );

  test(
    'feeding reminder uses actual assignee and disappears on completion',
    () {
      final care = {
        'a': {'action': careActions[0], 'completedAt': null},
      };
      final now = DateTime.parse('2026-09-07T12:00:00+09:00');
      expect(pendingCare(care, {'a': '엄마'}, now)?.role, '엄마');
      expect(
        pendingCare(care, {
          'a': '엄마',
        }, now.subtract(const Duration(seconds: 1))),
        isNull,
      );
      care['a']!['completedAt'] = 'saved';
      expect(pendingCare(care, {'a': '엄마'}, now), isNull);
    },
  );

  test('departed members and overnight do not trigger reminders', () {
    final care = {
      'a': {'action': careActions[0], 'completedAt': null},
    };
    expect(
      pendingCare(care, {}, DateTime.parse('2026-09-07T12:00:00+09:00')),
      isNull,
    );
    expect(
      pendingCare(care, {
        'a': '아빠',
      }, DateTime.parse('2026-09-07T01:00:00+09:00')),
      isNull,
    );
  });

  test('sleep has a later deadline than feeding', () {
    final care = {
      'a': {'action': careActions[3], 'completedAt': null},
    };
    expect(
      pendingCare(care, {
        'a': '아빠',
      }, DateTime.parse('2026-09-07T20:59:59+09:00')),
      isNull,
    );
    expect(
      pendingCare(care, {
        'a': '아빠',
      }, DateTime.parse('2026-09-07T21:00:00+09:00')),
      isNotNull,
    );
  });
}
