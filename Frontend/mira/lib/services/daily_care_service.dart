import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';

// dog_room의 실제 돌봄 버튼(밥 주기/목욕/놀기/재우기)과 맞춤.
const careActions = ['🍚 밥 주기', '🛁 목욕', '🎾 놀기', '😴 재우기'];

// 하루 기준을 자정이 아니라 한국시간(UTC+9) 오전 8시로 잡는다.
String careDate([DateTime? now]) => (now ?? DateTime.now())
    .toUtc()
    .add(const Duration(hours: 1))
    .toIso8601String()
    .substring(0, 10);

class DailyCareService {
  DailyCareService._();
  static final instance = DailyCareService._();

  final _firestore = FirebaseFirestore.instance;
  final _random = Random();

  DocumentReference<Map<String, dynamic>> _familyDoc(String familyId) =>
      _firestore.collection('families').doc(familyId);

  DocumentReference<Map<String, dynamic>> _careDoc(
    String familyId,
    String dateId,
  ) => _familyDoc(familyId).collection('dailyCare').doc(dateId);

  // Cloud Functions(Blaze 미전환이라 배포 불가) 대신 클라이언트 트랜잭션으로 오늘
  // 배정을 보장한다. 아직 배정 안 된 가족 구성원에게 서로 겹치지 않는 행동을 하나씩
  // 무작위로 배정 - 기존에 배정된 사람 몫은 건드리지 않는다.
  Future<String> _ensureCare(String familyId) async {
    final dateId = careDate();
    final familyRef = _familyDoc(familyId);
    final careRef = _careDoc(familyId, dateId);
    var newlyAssigned = const <String, dynamic>{};
    await _firestore.runTransaction((tx) async {
      newlyAssigned = const <String, dynamic>{};
      final familySnap = await tx.get(familyRef);
      final members = Map<String, dynamic>.from(
        familySnap.data()?['members'] as Map? ?? const {},
      );
      final careSnap = await tx.get(careRef);
      final existing = Map<String, dynamic>.from(careSnap.data() ?? const {});
      final assignments = _assignMissing(members.keys, existing);
      if (assignments.length != existing.length) {
        tx.set(careRef, assignments, SetOptions(merge: true));
        newlyAssigned = Map.fromEntries(
          assignments.entries.where(
            (entry) => !existing.containsKey(entry.key),
          ),
        );
      }
    });
    // 알림 발송은 트랜잭션 밖에서 - 트랜잭션이 경합으로 재시도되면 알림도 중복 발송될 수 있어서.
    for (final entry in newlyAssigned.entries) {
      final action = (entry.value as Map)['action'] as String;
      unawaited(
        NotificationService.instance
            .sendCareAssignedAlert(toUserId: entry.key, action: action)
            .catchError((Object _) {}),
      );
    }
    return dateId;
  }

  Map<String, dynamic> _assignMissing(
    Iterable<String> memberUids,
    Map<String, dynamic> existing,
  ) {
    final result = Map<String, dynamic>.from(existing);
    final taken = existing.values
        .map((record) => (record as Map)['action'] as String?)
        .whereType<String>()
        .toSet();
    final available = careActions
        .where((action) => !taken.contains(action))
        .toList();
    for (final uid in memberUids.toList()..sort()) {
      if (result.containsKey(uid)) continue;
      final pool = available.isNotEmpty ? available : List.of(careActions);
      final action = pool.removeAt(_random.nextInt(pool.length));
      result[uid] = {'action': action, 'completedAt': null};
    }
    return result;
  }

  Stream<Map<String, dynamic>> watchToday(String familyId) {
    late StreamController<Map<String, dynamic>> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
    Timer? timer;
    String? date;
    bool loading = false;
    bool closed = false;
    Future<void> refresh() async {
      if (closed || loading || date == careDate()) return;
      loading = true;
      try {
        final nextDate = await _ensureCare(familyId);
        if (closed) return;
        await subscription?.cancel();
        if (closed) return;
        date = nextDate;
        controller.add({});
        subscription = _firestore
            .collection('families')
            .doc(familyId)
            .collection('dailyCare')
            .doc(nextDate)
            .snapshots()
            .listen(
              (doc) => controller.add({...?doc.data(), '_dateId': nextDate}),
              onError: (Object error, StackTrace stack) {
                date = null;
                controller.addError(error, stack);
              },
            );
      } catch (error, stack) {
        if (!closed) controller.addError(error, stack);
      } finally {
        loading = false;
      }
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        refresh();
        timer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
      },
      onCancel: () async {
        closed = true;
        timer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> completeSelectedAction({
    required String familyId,
    required String uid,
    required String action,
  }) async {
    final dateId = await _ensureCare(familyId);
    final careRef = _careDoc(familyId, dateId);
    var completed = false;
    await _firestore.runTransaction((tx) async {
      completed = false;
      final snapshot = await tx.get(careRef);
      final record = snapshot.data()?[uid] as Map<String, dynamic>?;
      if (record == null ||
          record['action'] != action ||
          record['completedAt'] != null) {
        return;
      }
      tx.update(careRef, {'$uid.completedAt': FieldValue.serverTimestamp()});
      completed = true;
    });
    if (!completed) return;

    final familySnap = await _familyDoc(familyId).get();
    final members = Map<String, dynamic>.from(
      familySnap.data()?['members'] as Map? ?? const {},
    );
    final myRole = members[uid] as String? ?? '가족';
    for (final otherUid in members.keys) {
      if (otherUid == uid) continue;
      unawaited(
        NotificationService.instance
            .sendCareCompletedAlert(
              toUserId: otherUid,
              fromRole: myRole,
              action: action,
            )
            .catchError((Object _) {}),
      );
    }
  }
}
