import '../../widgets/word_wrap_text.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/daily_care_service.dart';
import '../../services/family_service.dart';
import '../../services/pet_service.dart';
import '../controllers/dog_controller.dart';
import '../models/care_reminder.dart';
import '../models/pet_address.dart';
import '../widgets/pet_chat_sheet.dart';
import 'dog_room_screen.dart';

class FamilyDogRoom extends StatefulWidget {
  const FamilyDogRoom({super.key, required this.controller, required this.uid});
  final DogController controller;
  final String? uid;
  @override
  State<FamilyDogRoom> createState() => _FamilyDogRoomState();
}

class _FamilyDogRoomState extends State<FamilyDogRoom> {
  StreamSubscription<Map<String, dynamic>>? _careSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _familySubscription;
  StreamSubscription<Map<String, dynamic>?>? _petSubscription;
  String _petName = '강아지';
  String? _petGender;
  Map<String, dynamic> _addresses = {};
  String _addressFor(String? uid) => petAddress(
    _members[uid] as String?,
    _petGender,
    preferredAddress: _addresses[uid] as String?,
  );
  int _connection = 0;
  String get _viewerAddress => _addressFor(widget.uid);
  Timer? _timer;
  String? _familyId;
  String? _error;
  Map<String, dynamic> _care = {};
  Map<String, dynamic> _members = {};
  List<CareReminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    _connect();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshReminder(),
    );
  }

  Future<void> _connect() async {
    final connection = ++_connection;
    final uid = widget.uid;
    if (uid == null) return;
    try {
      final familyId = await FamilyService.instance.fetchMyFamilyId(uid);
      if (!mounted || connection != _connection || familyId == null) return;
      _familyId = familyId;
      _petSubscription = PetService.instance
          .watchPet(familyId)
          .listen(
            (pet) {
              if (!mounted || connection != _connection) return;
              final name = (pet?['name'] as String?)?.trim();
              setState(() {
                _petName = name == null || name.isEmpty ? '강아지' : name;
                _petGender = pet?['gender'] as String?;
                _addresses = Map<String, dynamic>.from(
                  pet?['addresses'] as Map? ?? {},
                );
              });
              _refreshReminder();
            },
            onError: (Object error) {
              if (mounted && connection == _connection) {
                setState(() {
                  _petName = '강아지';
                  _petGender = null;
                  _addresses = {};
                });
                _refreshReminder();
              }
            },
          );
      _familySubscription = FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .snapshots()
          .listen(
            (doc) {
              if (!mounted || connection != _connection) return;
              _members = Map<String, dynamic>.from(
                doc.data()?['members'] as Map? ?? {},
              );
              _refreshReminder();
            },
            onError: (Object error) {
              if (connection == _connection) _failed();
            },
          );
      _careSubscription = DailyCareService.instance
          .watchToday(familyId)
          .listen(
            (care) {
              if (!mounted || connection != _connection) return;
              setState(() {
                _care = care;
                _error = null;
              });
              _refreshReminder();
            },
            onError: (Object error) {
              if (connection == _connection) _failed();
            },
          );
    } catch (_) {
      if (connection == _connection) _failed();
    }
  }

  void _failed() {
    if (mounted) {
      setState(() {
        _error = '돌봄 상태를 불러오지 못했어요. 잠시 후 다시 확인해주세요.';
        _care = {};
        _reminders = [];
      });
    }
  }

  void _refreshReminder() {
    if (!mounted) return;
    final reminders = pendingCareReminders(
      _care,
      _members.map((uid, role) => MapEntry(uid, _addressFor(uid))),
      DateTime.now(),
      ignoreDeadlines:
          kDebugMode && const bool.fromEnvironment('CARE_REMINDER_PREVIEW'),
    );
    setState(() => _reminders = reminders);
  }

  String _careContext() =>
      '현재 대화 상대 역할: ${_members[widget.uid] ?? '미확인'}. '
      '이 사용자를 부를 호칭: $_viewerAddress. 다른 가족과 혼동하지 마세요.\n'
      '${_members.entries.map((member) {
        final record = _care[member.key];
        if (record is! Map || _care['_dateId'] != careDate()) {
          return '${member.value}: 배정 확인 중';
        }
        return '${_addressFor(member.key)}'
            '${member.key == widget.uid ? ' (현재 대화 상대)' : ' (다른 가족)'}: '
            '${record['action']} / ${record['completedAt'] == null ? '미완료' : '완료'}';
      }).join('\n')}';

  @override
  void didUpdateWidget(covariant FamilyDogRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid == widget.uid) return;
    _careSubscription?.cancel();
    _familySubscription?.cancel();
    _petSubscription?.cancel();
    _familyId = null;
    _members = {};
    _care = {};
    _reminders = [];
    _petName = '강아지';
    _petGender = null;
    _addresses = {};
    _error = null;
    _connect();
  }

  void _chat() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        PetChatSheet(careContext: _careContext, familyId: _familyId),
  );

  Future<void> _complete(CareAction action) async {
    if (_familyId == null || widget.uid == null) return;
    final label = switch (action) {
      CareAction.feed => careActions[0],
      CareAction.wash => careActions[1],
      CareAction.play => careActions[2],
      CareAction.sleep => careActions[3],
    };
    try {
      await DailyCareService.instance.completeSelectedAction(
        familyId: _familyId!,
        uid: widget.uid!,
        action: label,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: WordSafeText('돌봄 완료를 저장하지 못했어요. 연결을 확인하고 다시 해주세요.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _careSubscription?.cancel();
    _petSubscription?.cancel();
    _familySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_error != null)
        Padding(padding: const EdgeInsets.all(8), child: WordSafeText(_error!)),
      Expanded(
        child: DogRoomScreen(
          key: ValueKey(widget.uid),
          controller: widget.controller,
          onCareAction: _complete,
          careReminders: _reminders,
          viewerUid: widget.uid,
          viewerAddress: _viewerAddress,
          petName: _petName,
          onTalk: _chat,
        ),
      ),
    ],
  );
}
