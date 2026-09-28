import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/word_wrap_text.dart';

const privacyVersion = '2026-09-06';
const privacyKey = 'mira_privacy_acknowledgement_v1';

const privacySections = <(String, String)>[
  (
    '어떤 정보를 저장하나요?',
    '사진첩에서 직접 선택한 사진과 글, 댓글, 좋아요, 강아지 돌봄·성장 상태, 안내 확인 일시와 버전을 이 기기에 저장해요. 로그인·가족 프로필은 현재 체험 화면이며 입력한 계정 정보로 서버에 가입하거나 로그인하지 않아요.',
  ),
  (
    '어디에 사용하나요?',
    '사진첩을 다시 열었을 때 추억을 보여 주고, 강아지의 성장을 이어 가며, 확인한 안내를 다시 묻지 않기 위해 사용해요. 광고나 AI 학습에 사용하지 않아요.',
  ),
  (
    '가족에게 공유되나요?',
    '현재 버전은 기기 안에서 사용하는 체험판이에요. 사진·댓글을 서버나 다른 가족에게 전송하지 않아요. 실제 가족 공유를 연결할 때 공개 범위와 처리 내용을 다시 안내할게요.',
  ),
  (
    '언제까지 보관하나요?',
    '직접 삭제하거나 앱 데이터를 지울 때까지 이 기기에 보관해요. 웹에서는 브라우저 사이트 데이터를 지워도 삭제돼요. 다른 기기로 자동 백업되지 않으니 소중한 원본 사진은 따로 보관해 주세요.',
  ),
  (
    '확인·수정·삭제는 어떻게 하나요?',
    '사진을 누르면 글을 수정하고 사진·댓글을 삭제할 수 있어요. 설정의 ‘기기에 저장한 데이터 삭제’에서 사진첩, 강아지 상태, 안내 확인 기록을 함께 지울 수 있어요. 사진을 선택하지 않아도 나머지 화면을 둘러볼 수 있어요.',
  ),
  (
    '사진 접근 권한은 언제 필요한가요?',
    '사진첩에서 ‘사진 선택’을 눌렀을 때만 운영체제의 사진 선택 화면을 열어요. 선택한 사진만 사용하며 카메라·마이크·위치 권한은 요청하지 않아요.',
  ),
  (
    '어린이와 보호자에게',
    '어린이는 보호자와 함께 안내를 읽어 주세요. 다른 사람의 사진은 그 사람에게 먼저 물어보고 올려 주세요. 실제 회원가입 서비스에서 만 14세 미만 어린이의 개인정보를 수집하려면 법정대리인 동의 확인 절차가 필요하며, 현재 체험판에는 해당 가입 기능이 없어요.',
  ),
  (
    '안내 범위와 변경',
    '이 안내는 MIRA의 현재 기기 저장 기능에 관한 내용이에요. 실제 서비스의 운영자·개인정보 보호 담당 연락처, 서버 보관 기간, 위탁·제공 내역은 서비스 연동 전에 확정하여 별도로 공개해야 해요. 시행일: 2026년 9월 6일.',
  ),
];

void showPrivacyDocument(BuildContext context, {bool terms = false}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(terms ? '이용 안내' : '개인정보 처리방침')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              terms ? '함께 지키는 작은 약속' : '우리의 정보, 알기 쉽게',
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'MIRA 체험판 · 2026. 09. 06',
              style: TextStyle(color: Color(0xFF68766D)),
            ),
            const SizedBox(height: 28),
            for (final section
                in terms
                    ? <(String, String)>[
                        (
                          '다정하게 이야기해요',
                          '가족의 마음과 사생활을 존중해 주세요. 다른 사람의 사진이나 이야기는 허락을 받고 올려 주세요.',
                        ),
                        (
                          '내 사진으로 추억을 남겨요',
                          '직접 찍었거나 사용할 권한이 있는 사진을 올려 주세요. 다른 사람의 개인정보, 모욕적인 내용은 올리지 말아 주세요.',
                        ),
                        (
                          '현재 이용할 수 있는 기능',
                          '강아지 돌봄과 성장, 기기에 저장하는 사진첩을 체험할 수 있어요. 로그인·가족 공유·AI 분석 등 나머지 화면은 예시이며 실제 계정이나 가족에게 연결되지 않아요.',
                        ),
                        (
                          '함께 읽어 주세요',
                          '어린이는 보호자와 함께 이용 안내를 확인해 주세요. 가족이 함께 볼 수 있는 따뜻한 사진과 말을 남겨 주세요.',
                        ),
                      ]
                    : privacySections) ...[
              Text(
                section.$1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              WordWrapText(
                section.$2,
                style: const TextStyle(fontSize: 16, height: 1.7),
              ),
              const SizedBox(height: 28),
            ],
          ],
        ),
      ),
    ),
  );
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({required this.onDone, super.key});
  final VoidCallback onDone;
  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool terms = false, privacy = false, saving = false;
  Future<void> _continue() async {
    setState(() => saving = true);
    try {
      await SharedPreferencesAsync().setString(
        privacyKey,
        '$privacyVersion|${DateTime.now().toUtc().toIso8601String()}',
      );
      if (mounted) widget.onDone();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('확인 내용을 저장하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _row(
    String text,
    bool value,
    ValueChanged<bool?> onChanged,
    VoidCallback onRead,
  ) => Row(
    children: [
      Expanded(
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          value: value,
          onChanged: saving ? null : onChanged,
        ),
      ),
      TextButton(onPressed: onRead, child: const Text('보기')),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFFE4ECE5),
              child: Icon(
                CupertinoIcons.hand_raised,
                color: Color(0xFF315E50),
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '시작하기 전에,\n우리의 작은 약속',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.3,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '어떤 정보가 저장되는지 함께 살펴봐요.\n어린이는 보호자와 함께 읽어 주세요.',
            style: TextStyle(
              fontSize: 16,
              height: 1.65,
              color: Color(0xFF68766D),
            ),
          ),
          const SizedBox(height: 28),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '사진과 마음은 이 기기에',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '선택한 사진·글·댓글과 강아지의 성장을 저장해요. 지금은 다른 사람에게 전송되지 않아요. 저장한 내용은 설정에서 삭제할 수 있어요.',
                    style: TextStyle(fontSize: 15, height: 1.7),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _row(
            '이용 안내 확인',
            terms,
            (v) => setState(() => terms = v ?? false),
            () => showPrivacyDocument(context, terms: true),
          ),
          _row(
            '개인정보 처리방침 확인',
            privacy,
            (v) => setState(() => privacy = v ?? false),
            () => showPrivacyDocument(context),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: terms && privacy && !saving ? _continue : null,
            child: Text(saving ? '저장하는 중…' : '확인하고 시작하기'),
          ),
          const SizedBox(height: 12),
          const Text(
            '선택하지 않은 사진에는 접근하지 않아요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF68766D)),
          ),
        ],
      ),
    ),
  );
}
