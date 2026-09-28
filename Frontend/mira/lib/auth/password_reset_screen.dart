import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/word_wrap_text.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, this.email = '', this.sendReset});
  final String email;
  final Future<void> Function(String)? sendReset;
  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  late final _email = TextEditingController(text: widget.email);
  bool _busy = false, _sent = false;
  String? _error;

  Future<void> _send() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = '올바른 이메일 주소를 입력해주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (widget.sendReset ?? AuthService.instance.sendPasswordReset)(email);
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'user-not-found') {
        setState(() => _sent = true);
      } else {
        setState(
          () => _error = e.code == 'too-many-requests'
              ? '요청이 많아요. 잠시 후 다시 시도해주세요.'
              : '메일을 보내지 못했어요. 주소와 연결을 확인해주세요.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = '메일을 보내지 못했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('비밀번호 재설정')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        WordWrapText(
          _sent
              ? '가입된 이메일이라면 재설정 메일이 도착해요. 받은편지함과 스팸함을 확인해주세요.'
              : '가입할 때 사용한 이메일로 비밀번호를 다시 설정할 수 있어요.',
        ),
        const SizedBox(height: 20),
        if (!_sent) ...[
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(labelText: '이메일', errorText: _error),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: Text(_busy ? '메일 보내는 중…' : '재설정 메일 보내기'),
          ),
        ] else
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('로그인으로 돌아가기'),
          ),
      ],
    ),
  );
}
