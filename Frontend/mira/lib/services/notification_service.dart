import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/korean_particles.dart';

/// users/{userId}/notifications — Backend/firestore-schema.md 참고.
/// moodAlert(감정 소식), commentAlert(댓글), careAlert(돌봄 배정/완료)에 사용한다.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  DocumentReference<Map<String, dynamic>> _preferencesDoc(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('settings')
      .doc('preferences');

  // 다른 가족 구성원의 클라이언트에서 나에게 알림을 보내기 전에 내 알림 설정을
  // 확인해야 해서, 설정 화면(기기 로컬 저장소가 아니라)이 아니라 Firestore에 둔다.
  Future<Map<String, dynamic>> fetchPreferences(String userId) async {
    final doc = await _preferencesDoc(userId).get();
    return doc.data() ?? const {};
  }

  Future<void> setPreference(String userId, String key, bool value) {
    return _preferencesDoc(userId).set({key: value}, SetOptions(merge: true));
  }

  Future<bool> _isEnabled(String userId, String key) async {
    final prefs = await fetchPreferences(userId);
    return prefs[key] as bool? ?? true;
  }

  /// [moodText]는 절대 저장하지 않는다 — family_message(요약)만 전달해서 일기 원문을
  /// 가족에게 그대로 노출하지 않는다는 정책을 서버뿐 아니라 클라이언트에서도 지킨다.
  Future<void> sendMoodAlert({
    required String toUserId,
    required String message,
    required String relatedMoodId,
  }) {
    return _collection(toUserId).add({
      'type': 'moodAlert',
      'title': '가족 소식',
      'message': message,
      'isRead': false,
      'relatedId': relatedMoodId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendCommentAlert({
    required String toUserId,
    required String fromRole,
    required String relatedId,
  }) async {
    if (!await _isEnabled(toUserId, 'commentEnabled')) return;
    await _collection(toUserId).add({
      'type': 'commentAlert',
      'title': '새 댓글',
      'message': '${withIGa(fromRole)} 댓글을 남겼어요.',
      'isRead': false,
      'relatedId': relatedId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendCareAssignedAlert({
    required String toUserId,
    required String action,
  }) async {
    if (!await _isEnabled(toUserId, 'careEnabled')) return;
    await _collection(toUserId).add({
      'type': 'careAlert',
      'title': '오늘의 돌봄',
      'message': '오늘은 "$action" 담당이에요!',
      'isRead': false,
      'relatedId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendCareCompletedAlert({
    required String toUserId,
    required String fromRole,
    required String action,
  }) async {
    if (!await _isEnabled(toUserId, 'careEnabled')) return;
    await _collection(toUserId).add({
      'type': 'careAlert',
      'title': '오늘의 돌봄',
      'message': '${withIGa(fromRole)} "$action"${eulReul(action)} 완료했어요.',
      'isRead': false,
      'relatedId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchUnread(String userId) {
    return _collection(userId)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<void> markRead(String userId, String notificationId) {
    return _collection(userId).doc(notificationId).update({'isRead': true});
  }
}
