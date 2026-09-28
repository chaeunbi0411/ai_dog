import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/ai_server_service.dart';
import '../services/family_service.dart';
import '../services/mood_service.dart';
import '../services/notification_service.dart';
import '../widgets/word_wrap_text.dart';

/// 홈 화면 "오늘의 감정 한 줄 기록"에서 여는 비공개 감정 일기.
/// FamilyPage의 "오늘의 마음 기록"(moments)과 달리 원문은 가족에게 보이지 않고,
/// kobert 감정 분석 결과가 부정적이면 AI가 요약한 메시지만 가족에게 알림으로 전달된다.
Future<void> showMoodDiarySheet(BuildContext context) async {
  String? maybeUid;
  try {
    maybeUid = FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    // Firebase 미설정 플랫폼(화면 미리보기 등)에서는 로그인 안내로 대체한다.
  }
  final uid = maybeUid;
  if (uid == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('로그인 후 이용할 수 있어요.')));
    return;
  }
  String? familyId;
  try {
    familyId = await FamilyService.instance.fetchMyFamilyId(uid);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가족 정보를 불러오지 못했어요. 다시 시도해주세요.')),
      );
    }
    return;
  }
  if (familyId == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('가족에 먼저 참여해주세요.')));
    }
    return;
  }
  if (!context.mounted) return;
  final result = await showModalBottomSheet<MoodAnalysisResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MoodDiarySheet(uid: uid, familyId: familyId!),
  );
  if (!context.mounted || result == null) return;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('오늘의 기록을 남겼어요'),
      content: SingleChildScrollView(child: WordWrapText(result.selfMessage)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

class _MoodDiarySheet extends StatefulWidget {
  const _MoodDiarySheet({required this.uid, required this.familyId});
  final String uid;
  final String familyId;

  @override
  State<_MoodDiarySheet> createState() => _MoodDiarySheetState();
}

class _MoodDiarySheetState extends State<_MoodDiarySheet> {
  String _moodTag = moodTags.first;
  final _textController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '오늘 기분을 한 줄로 적어주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final profile = await firestore.collection('users').doc(widget.uid).get();
      final myRole = profile.data()?['role'] as String? ?? '가족';

      final memberDocs = await firestore
          .collection('users')
          .where('familyId', isEqualTo: widget.familyId)
          .get();
      final others = memberDocs.docs
          .where((doc) => doc.id != widget.uid)
          .toList();
      final familyRoles = others
          .map((doc) => doc.data()['role'] as String? ?? '가족')
          .toList();

      final result = await AiServerService.instance.analyzeMood(
        moodText: text,
        moodTag: _moodTag,
        userRole: myRole,
        familyRoles: familyRoles,
      );

      final moodId = await MoodService.instance.addMood(
        familyId: widget.familyId,
        userId: widget.uid,
        role: myRole,
        moodTag: _moodTag,
        moodText: text,
        aiEmotion: result.aiEmotion,
      );

      if (result.isNegative) {
        for (final doc in others) {
          try {
            await NotificationService.instance.sendMoodAlert(
              toUserId: doc.id,
              message: result.familyMessage,
              relatedMoodId: moodId,
            );
          } catch (_) {
            // The diary is already saved; retrying submission would duplicate it.
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context, result);
    } on AiServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '기록을 저장하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      22,
      5,
      22,
      MediaQuery.viewInsetsOf(context).bottom + 25,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '나의 오늘 감정',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const WordWrapText(
          '나만 보는 기록이에요. 가족에게는 원문 대신 AI가 정리한 짧은 소식만 전해져요.',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: moodTags
              .map(
                (tag) => ChoiceChip(
                  label: Text(tag),
                  selected: _moodTag == tag,
                  onSelected: _submitting
                      ? null
                      : (_) => setState(() => _moodTag = tag),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
          enabled: !_submitting,
          maxLength: 2000,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '오늘 있었던 일과 기분을 편하게 적어보세요.',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('감정 기록하기'),
          ),
        ),
      ],
    ),
  );
}
