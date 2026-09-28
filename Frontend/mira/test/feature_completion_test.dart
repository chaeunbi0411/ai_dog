import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira/auth/password_reset_screen.dart';
import 'package:mira/notifications/notification_inbox.dart';
import 'package:mira/widgets/story_filters.dart';

void main() {
  testWidgets('Reset validates email and prevents duplicate sends', (
    tester,
  ) async {
    final pending = Completer<void>();
    final emails = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetScreen(
          sendReset: (email) {
            emails.add(email);
            return pending.future;
          },
        ),
      ),
    );
    await tester.tap(find.text('재설정 메일 보내기'));
    await tester.pump();
    expect(find.text('올바른 이메일 주소를 입력해주세요.'), findsOneWidget);
    expect(emails, isEmpty);
    await tester.enterText(find.byType(TextField), ' person@example.com ');
    await tester.tap(find.text('재설정 메일 보내기'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(emails, ['person@example.com']);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('로그인으로 돌아가기'), findsOneWidget);
  });

  testWidgets('Reset failure is recoverable and safe after closing', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetScreen(
          email: 'person@example.com',
          sendReset: (_) => pending.future,
        ),
      ),
    );
    await tester.tap(find.text('재설정 메일 보내기'));
    await tester.pumpWidget(const SizedBox());
    pending.completeError(StateError('offline'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetScreen(
          email: 'person@example.com',
          sendReset: (_) async => throw StateError('offline'),
        ),
      ),
    );
    await tester.tap(find.text('재설정 메일 보내기'));
    await tester.pumpAndSettle();
    expect(find.text('메일을 보내지 못했어요. 잠시 후 다시 시도해주세요.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('Inbox filters unread entries and marks only unread IDs', (
    tester,
  ) async {
    final stream = StreamController<List<Map<String, dynamic>>>();
    addTearDown(stream.close);
    final marked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationInbox(
          userId: 'me',
          notifications: stream.stream,
          markRead: (ids) async => marked.addAll(ids),
        ),
      ),
    );
    stream.add([
      {'id': 'a', 'title': 'unread', 'message': 'hello', 'isRead': false},
      {'id': 'b', 'title': 'read', 'message': 'bye', 'isRead': true},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('read'), findsOneWidget);
    await tester.tap(find.byType(FilterChip));
    await tester.pump();
    expect(find.text('read'), findsNothing);
    await tester.tap(find.text('표시된 알림 모두 읽음'));
    await tester.pumpAndSettle();
    expect(marked, ['a']);
    stream.add([
      {'id': 'a', 'title': 'unread', 'isRead': true},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('안 읽은 알림이 없어요.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Inbox explains failed read updates', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationInbox(
          userId: 'me',
          notifications: Stream.value([
            {'id': 'a', 'title': 'news', 'isRead': false},
          ]),
          markRead: (_) async => throw StateError('offline'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('news'));
    await tester.pumpAndSettle();
    expect(find.text('읽음 상태를 저장하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
  });

  test('Story query combines words with ownership and like filters', () {
    final story = {
      'authorUid': 'me',
      'authorName': '엄마',
      'body': 'Happy 가족 산책',
      'mood': '기쁨',
      'likedBy': ['other'],
    };
    expect(matchesStory(story, '엄마 happy', StoryFilter.all, 'me'), isTrue);
    expect(matchesStory(story, '', StoryFilter.mine, 'other'), isFalse);
    expect(matchesStory(story, '산책', StoryFilter.liked, 'other'), isTrue);
    expect(matchesStory(story, '', StoryFilter.liked, 'me'), isFalse);
    expect(matchesStory({}, '', StoryFilter.all, 'me'), isTrue);
  });

  testWidgets('Story filter clear preserves the selected category', (
    tester,
  ) async {
    String query = '';
    StoryFilter filter = StoryFilter.all;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryFilters(
            onChanged: (q, f) {
              query = q;
              filter = f;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '산책');
    await tester.tap(find.text('내 이야기'));
    await tester.pump();
    expect(query, '산책');
    expect(filter, StoryFilter.mine);
    await tester.tap(find.byTooltip('검색어 지우기'));
    await tester.pump();
    expect(query, '');
    expect(filter, StoryFilter.mine);
  });
}
