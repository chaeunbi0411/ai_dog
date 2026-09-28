import 'dart:async';
import 'dart:convert';
import 'services/family_activity.dart';
import 'dog_room/models/pet_personality.dart';
import 'dog_room/widgets/pet_personality_quiz.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'design/mira_icons.dart';
import 'dog_room/controllers/dog_controller.dart';
import 'dog_room/services/character_save_service.dart';
import 'dog_room/services/dog_save_service.dart';
import 'dog_room/screens/family_dog_room.dart';
import 'firebase_options.dart';
import 'memories/memory_page.dart';
import 'mood/mood_diary_sheet.dart';
import 'privacy/privacy_screen.dart';
import 'services/ai_server_service.dart';
import 'services/auth_service.dart';
import 'services/character_server_service.dart';
import 'services/daily_care_service.dart';
import 'services/family_interaction.dart';
import 'services/family_service.dart';
import 'services/moment_service.dart';
import 'services/notification_service.dart';
import 'services/pet_service.dart';
import 'widgets/author_avatar.dart';
import 'widgets/word_wrap_text.dart';
import 'auth/password_reset_screen.dart';
import 'notifications/notification_inbox.dart';
import 'widgets/story_filters.dart';

part 'family_activity_ui.dart';
part 'moment_editor.dart';

const textScaleKey = 'text_scale_v1';
final textScaleNotifier = ValueNotifier<double>(1.0);

class _AppTextScaler extends TextScaler {
  const _AppTextScaler(this.system, this.preference);
  final TextScaler system;
  final double preference;
  @override
  double scale(double fontSize) => system.scale(fontSize) * preference;
  @override
  double get textScaleFactor => scale(14) / 14;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    await Firebase.initializeApp(
      options: useEmulators
          ? const FirebaseOptions(
              apiKey: 'demo-api-key',
              appId: '1:123:web:demo',
              messagingSenderId: '123',
              projectId: 'demo-mira-care',
            )
          : DefaultFirebaseOptions.currentPlatform,
    );
    if (useEmulators) {
      const host = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      );
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    }
  } catch (_) {
    // Web/Android는 아직 Firebase 앱 등록 전이라 화면 미리보기용으로 무시.
  }
  try {
    final savedScale = await SharedPreferencesAsync().getDouble(textScaleKey);
    if (savedScale != null) textScaleNotifier.value = savedScale;
  } catch (_) {
    /* 기본 배율(1.0) 유지 */
  }
  runApp(const MiraApp());
}

const ink = Color(0xFF263E34),
    violet = Color(0xFF315E50),
    cream = Color(0xFFF7F8F3);

/// FirebaseAuth.instance는 Firebase가 초기화되지 않은 환경(화면 미리보기, 테스트,
/// 아직 등록 안 된 플랫폼)에서 접근하는 순간 예외를 던진다. build() 안에서 로그인
/// 여부만 필요한 곳은 항상 이걸로 안전하게 확인한다 — 그냥 currentUser를 읽으면
/// IndexedStack에 항상 붙어있는 다른 탭까지 통째로 에러 화면이 된다.
String? currentUidOrNull() {
  try {
    return FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    return null;
  }
}

class MiraApp extends StatelessWidget {
  const MiraApp({this.home, super.key});
  final Widget? home;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'MIRA',
    theme: ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      fontFamily: 'Pretendard',
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: ink),
        bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: ink),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 1.45,
          color: Color(0xFF68766D),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Color(0xFFD3DDD3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE3E8DF),
        thickness: 1,
      ),
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: violet, surface: cream),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFFFFFEFB),
        indicatorColor: Color(0xFFE3EBDF),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(18),
        ),
        contentPadding: const EdgeInsets.all(17),
      ),
    ),
    builder: (context, child) => ValueListenableBuilder<double>(
      valueListenable: textScaleNotifier,
      builder: (context, scale, _) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: _AppTextScaler(MediaQuery.textScalerOf(context), scale),
        ),
        child: ColoredBox(
          color: const Color(0xFFE9EEE7),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ClipRect(child: child!),
            ),
          ),
        ),
      ),
    ),
    home: home ?? const AppFlow(),
  );
}

enum Stage { onboarding, privacy, auth, profile, pet, app }

class AppFlow extends StatefulWidget {
  const AppFlow({this.skipOnboarding = false, super.key});
  final bool skipOnboarding;
  @override
  State<AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<AppFlow> {
  Stage stage = Stage.onboarding;

  @override
  void initState() {
    super.initState();
    if (widget.skipOnboarding) {
      stage = Stage.auth;
      _start();
    }
  }

  Future<void> _start() async {
    String? record;
    try {
      record = await SharedPreferencesAsync().getString(privacyKey);
    } catch (_) {
      /* Show the notice if storage is unavailable. */
    }
    if (record?.startsWith('$privacyVersion|') != true) {
      if (mounted) setState(() => stage = Stage.privacy);
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => stage = Stage.auth);
        return;
      }

      final familyId = await FamilyService.instance.fetchMyFamilyId(user.uid);
      if (mounted) {
        setState(() => stage = familyId == null ? Stage.profile : Stage.app);
      }
    } catch (_) {
      // Firebase 미설정 플랫폼(화면 미리보기 등)에서는 로그인 화면부터 보여준다.
      if (mounted) setState(() => stage = Stage.auth);
    }
  }

  @override
  Widget build(BuildContext context) => switch (stage) {
    Stage.onboarding => Onboarding(onDone: _start),
    Stage.privacy => PrivacyScreen(
      onDone: () => setState(() => stage = Stage.auth),
    ),
    Stage.auth => AuthScreen(onDone: _start),
    Stage.profile => ProfileSetup(
      onDone: () => setState(() => stage = Stage.pet),
    ),
    Stage.pet => PetSetup(onDone: () => setState(() => stage = Stage.app)),
    Stage.app => const MainShell(),
  };
}

class Onboarding extends StatefulWidget {
  const Onboarding({required this.onDone, super.key});
  final VoidCallback onDone;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final page = PageController();
  int index = 0;
  @override
  void dispose() {
    page.dispose();
    super.dispose();
  }

  final data = const [
    (
      '함께한 순간이 서로의 마음에 오래 울리도록',
      'MIRA는 Moments In Resonance, Always의 약자예요. 가족의 일상과 감정을 다정하게 이어드려요.',
      CupertinoIcons.heart_fill,
      Color(0xFFFFD7CF),
    ),
    (
      '말하지 않아도\n놓치지 않는 작은 신호',
      '일기는 안전하게 지키고, 가족에게는 필요한 마음만 전해요.',
      CupertinoIcons.sparkles,
      Color(0xFFDCD8FF),
    ),
    (
      '우리 가족이 함께\n돌보는 새로운 친구',
      '매일 한 사람, 한 번의 참여가 가족의 세계를 키워요.',
      Icons.pets_rounded,
      Color(0xFFD9EFD7),
    ),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        PageView.builder(
          controller: page,
          itemCount: 3,
          onPageChanged: (v) => setState(() => index = v),
          itemBuilder: (_, i) {
            final d = data[i];
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 130),
                children: [
                  Row(
                    children: [
                      const WordSafeText(
                        'MIRA',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: violet,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: widget.onDone,
                        child: const WordSafeText('건너뛰기'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const WordSafeText(
                    'Moments In Resonance, Always',
                    style: TextStyle(fontSize: 12, color: violet),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      color: d.$4.withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/dog/${['baby_idle', 'child_idle', 'baby_tail_01'][i]}.png',
                          height: 225,
                        ),
                        Positioned(
                          right: 24,
                          top: 24,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              [
                                CupertinoIcons.heart,
                                CupertinoIcons.sparkles,
                                CupertinoIcons.house,
                              ][i],
                              color: violet,
                              size: 25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 38),
                  WordWrapText(
                    d.$1,
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.9,
                    ),
                  ),
                  const SizedBox(height: 16),
                  WordWrapText(
                    d.$2,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: Color(0xFF68766D),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Positioned(
          left: 28,
          right: 28,
          bottom: 34,
          child: Row(
            children: [
              ...List.generate(
                3,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: i == index ? 28 : 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 7),
                  decoration: BoxDecoration(
                    color: i == index ? ink : ink.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              const Spacer(),
              FloatingActionButton(
                onPressed: () {
                  if (index == 2) {
                    widget.onDone();
                  } else {
                    page.nextPage(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    );
                  }
                },
                backgroundColor: ink,
                foregroundColor: Colors.white,
                child: Icon(index == 2 ? Icons.check : Icons.arrow_forward),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.onDone, super.key});
  final VoidCallback onDone;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool signup = false;
  bool _submitting = false;
  bool _showPassword = false;
  String? _errorText;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (signup && _nameController.text.trim().isEmpty) {
      setState(() => _errorText = '이름을 입력해주세요.');
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = '이메일과 비밀번호를 입력해주세요');
      return;
    }
    if (signup && password != _passwordConfirmController.text) {
      setState(() => _errorText = '비밀번호가 일치하지 않아요');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      if (signup) {
        await AuthService.instance.signUp(
          email: email,
          password: password,
          name: _nameController.text.trim(),
        );
      } else {
        await AuthService.instance.signIn(email: email, password: password);
      }
      if (mounted) widget.onDone();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _errorText = AuthService.instance.messageFor(e));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = '로그인 정보를 저장하지 못했어요. 연결을 확인하고 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 42),
            const WordSafeText(
              'MIRA',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 36),
            WordSafeText(
              signup ? '가족의 첫 페이지를\n만들어 볼까요?' : '다시 만나서\n반가워요',
              style: const TextStyle(
                fontSize: 34,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 12),
            WordSafeText(
              signup ? '가족 프로필을 설정하고 둘러보세요.' : '우리 가족의 오늘을 확인해 보세요.',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (signup) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  prefixIcon: Icon(CupertinoIcons.person),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '이메일',
                prefixIcon: Icon(CupertinoIcons.envelope),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              enabled: !_submitting,
              obscureText: !_showPassword,
              onSubmitted: (_) {
                if (!signup) _handleSubmit();
              },
              decoration: InputDecoration(
                labelText: '비밀번호',
                prefixIcon: const Icon(CupertinoIcons.lock),
                suffixIcon: IconButton(
                  tooltip: _showPassword ? '비밀번호 숨기기' : '비밀번호 보기',
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            if (signup) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _passwordConfirmController,
                obscureText: !_showPassword,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: '비밀번호 확인',
                  prefixIcon: Icon(CupertinoIcons.lock),
                ),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              WordSafeText(
                _errorText!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _handleSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: ink,
                  padding: const EdgeInsets.all(18),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : WordSafeText(signup ? '프로필 만들기' : '로그인'),
              ),
            ),
            const SizedBox(height: 12),
            if (!signup)
              Center(
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PasswordResetScreen(
                              email: _emailController.text.trim(),
                            ),
                          ),
                        ),
                  child: const WordSafeText('비밀번호를 잊으셨나요?'),
                ),
              ),
            Center(
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                        signup = !signup;
                        _errorText = null;
                      }),
                child: WordSafeText(
                  signup ? '이미 계정이 있어요 · 로그인' : '처음이신가요? · 회원가입',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SetupFrame extends StatelessWidget {
  const SetupFrame({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });
  final String step, title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WordSafeText(
              step,
              style: const TextStyle(
                color: violet,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            WordWrapText(
              title,
              style: const TextStyle(
                fontSize: 32,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.3,
              ),
            ),
            const SizedBox(height: 10),
            WordSafeText(
              subtitle,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            child,
          ],
        ),
      ),
    ),
  );
}

class ProfileSetup extends StatefulWidget {
  const ProfileSetup({required this.onDone, super.key});
  final VoidCallback onDone;
  @override
  State<ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<ProfileSetup> {
  String role = '딸';
  bool _submitting = false;
  String? _errorText;
  DateTime? _birthday;
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthday = picked;
        _birthdayController.text =
            '${picked.year}. ${picked.month.toString().padLeft(2, '0')}. ${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _saveProfileFields() async {
    final name = _nameController.text.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && (name.isNotEmpty || _birthday != null)) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        if (name.isNotEmpty) 'name': name,
        if (_birthday != null)
          'birthday':
              '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
      }, SetOptions(merge: true));
    }
  }

  Future<void> _handleCreate() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await _saveProfileFields();
      await FamilyService.instance.createFamily(role);
      widget.onDone();
    } on FamilyServiceException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleJoin() async {
    final inviteCode = _inviteCodeController.text.trim();
    if (inviteCode.isEmpty) {
      setState(() => _errorText = '초대 코드를 입력해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await _saveProfileFields();
      await FamilyService.instance.joinFamily(inviteCode, role);
      widget.onDone();
    } on FamilyServiceException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => SetupFrame(
    step: '01 / 02',
    title: '가족에게 나는\n어떤 사람인가요?',
    subtitle: '첫 로그인에 한 번만 설정하면 돼요.',
    child: Column(
      children: [
        Wrap(
          spacing: 8,
          children: familyRoles
              .map(
                (e) => ChoiceChip(
                  avatar: const Icon(Icons.person_rounded, size: 20),
                  label: WordSafeText(e),
                  selected: role == e,
                  onSelected: (_) => setState(() => role = e),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '이름',
            hintText: '이름을 입력하세요',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _birthdayController,
          readOnly: true,
          onTap: _pickBirthday,
          decoration: const InputDecoration(
            labelText: '생년월일',
            hintText: '예) 2002. 03. 14',
            suffixIcon: Icon(CupertinoIcons.calendar),
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          WordSafeText(_errorText!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 28),
        const WordSafeText(
          '처음이신가요?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _handleCreate,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const WordSafeText('가족 코드 생성하기'),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        const WordSafeText(
          '이미 가족 코드가 있으신가요?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _inviteCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: '가족 초대 코드',
            hintText: '가족에게 받은 코드를 입력하세요',
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _submitting ? null : _handleJoin,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(18)),
            child: const WordSafeText('가족 코드 등록하기'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: widget.onDone,
            child: const WordSafeText('백엔드 연동 없이 화면만 보기'),
          ),
        ),
      ],
    ),
  );
}

class PetSetup extends StatefulWidget {
  const PetSetup({required this.onDone, super.key});
  final VoidCallback onDone;
  @override
  State<PetSetup> createState() => _PetSetupState();
}

class _PetSetupState extends State<PetSetup> {
  bool photo = true;
  String personality = '활발함';
  String? _petGender;
  final _petAddressController = TextEditingController();
  PetPersonality? _personalityProfile;
  final _breedController = TextEditingController();
  final _colorController = TextEditingController();
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  final List<Uint8List> _photoBytes = [];
  bool _analyzing = false;
  bool _saving = false;
  bool _loadingExisting = true;
  bool _hadExistingPet = false;
  String? _analysisError;
  Uint8List? _characterImage;
  bool _generatingCharacter = false;
  String? _characterError;
  int _characterSeed = 42;
  String? _saveError;
  String? _familyId;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    // initState에서 바로 호출돼서, Firebase 미설정 환경에서는 currentUidOrNull()로
    // 안전하게 확인해야 한다 (안 그러면 화면 진입 자체가 예외로 죽는다).
    final uid = currentUidOrNull();
    if (uid == null) {
      if (mounted) setState(() => _loadingExisting = false);
      return;
    }
    final familyId = await FamilyService.instance.fetchMyFamilyId(uid);
    final pet = familyId == null
        ? null
        : await PetService.instance.fetchPet(familyId);
    if (!mounted) return;
    setState(() {
      _familyId = familyId;
      _loadingExisting = false;
      if (pet != null) {
        _hadExistingPet = true;
        photo = false;
        _nameController.text = pet['name'] as String? ?? '';
        _petAddressController.text =
            (pet['addresses'] as Map?)?[uid] as String? ?? '';
        _breedController.text = pet['breed'] as String? ?? '';
        _colorController.text = pet['colorDescription'] as String? ?? '';
        personality = pet['personality'] as String? ?? personality;
        _petGender = ['male', 'female'].contains(pet['gender'])
            ? pet['gender'] as String
            : null;
        _personalityProfile = PetPersonality.fromJson(
          pet['personalityProfile'],
        );
      }
    });
  }

  @override
  void dispose() {
    _breedController.dispose();
    _colorController.dispose();
    _nameController.dispose();
    _petAddressController.dispose();
    super.dispose();
  }

  Future<void> _generateCharacter({bool reroll = false}) async {
    final breed = _breedController.text.trim();
    final color = _colorController.text.trim();
    if (breed.isEmpty || color.isEmpty) {
      setState(() => _characterError = '견종과 색상을 먼저 입력해주세요.');
      return;
    }
    if (reroll) _characterSeed = DateTime.now().millisecondsSinceEpoch % 100000;
    setState(() {
      _generatingCharacter = true;
      _characterError = null;
    });
    try {
      final bytes = await CharacterServerService.instance.generate(
        breed: breed,
        color: color,
        personality: personality,
        seed: _characterSeed,
      );
      setState(() => _characterImage = bytes);
    } on CharacterServerException catch (e) {
      setState(() => _characterError = e.message);
    } catch (_) {
      setState(() => _characterError = '캐릭터를 만들지 못했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _generatingCharacter = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (_personalityProfile == null) {
      setState(() => _saveError = '네 문항의 성격 테스트를 먼저 완료해주세요.');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _familyId == null) {
      widget.onDone();
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await PetService.instance.savePet(
        familyId: _familyId!,
        updatedByUid: uid,
        name: _nameController.text.trim(),
        breed: _breedController.text.trim(),
        colorDescription: _colorController.text.trim(),
        personality: personality,
        personalityProfile: _personalityProfile?.toJson(),
        gender: _petGender,
        preferredAddress: _petAddressController.text,
      );
      final image = _characterImage;
      if (image != null) {
        await CharacterSaveService.instance.save(image);
      }
      widget.onDone();
    } catch (_) {
      setState(() => _saveError = '저장하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80, limit: 5);
    if (picked.isEmpty) return;
    final bytesList = await Future.wait(
      picked.map((file) => file.readAsBytes()),
    );
    setState(() {
      _photoBytes
        ..clear()
        ..addAll(bytesList);
      _analysisError = null;
    });
  }

  Future<void> _analyzePhotos() async {
    if (_photoBytes.isEmpty) return;
    setState(() {
      _analyzing = true;
      _analysisError = null;
    });
    try {
      final result = await AiServerService.instance.analyzePetPhotos(
        _photoBytes,
      );
      setState(() {
        _breedController.text = result.breed;
        _colorController.text = result.colorDescription;
      });
    } on AiServerException catch (e) {
      setState(() => _analysisError = e.message);
    } catch (_) {
      setState(
        () => _analysisError = 'AI 서버에 연결하지 못했어요. ai-server가 실행 중인지 확인해주세요.',
      );
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) => SetupFrame(
    step: '02 / 02',
    title: '우리 가족의 친구를\n소개해 주세요',
    subtitle: '사진을 올리면 AI가 품종과 색상을 분석해줘요.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: WordSafeText('사진으로 만들기'),
                icon: Icon(CupertinoIcons.sparkles),
              ),
              ButtonSegment(
                value: false,
                label: WordSafeText('직접 꾸미기'),
                icon: Icon(CupertinoIcons.slider_horizontal_3),
              ),
            ],
            selected: {photo},
            onSelectionChanged: (v) => setState(() => photo = v.first),
          ),
        ),
        const SizedBox(height: 18),
        if (photo) ...[
          GestureDetector(
            onTap: _pickPhotos,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9F8),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: violet.withValues(alpha: .25)),
              ),
              child: _photoBytes.isEmpty
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 24),
                        Icon(
                          CupertinoIcons.photo_on_rectangle,
                          size: 44,
                          color: violet,
                        ),
                        SizedBox(height: 8),
                        WordSafeText(
                          '강아지 사진 최대 5장',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        WordSafeText(
                          '눌러서 사진 선택',
                          style: TextStyle(color: Colors.black45, fontSize: 12),
                        ),
                        SizedBox(height: 24),
                      ],
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final bytes in _photoBytes)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              bytes,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        InkWell(
                          onTap: _pickPhotos,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: violet.withValues(alpha: .4),
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.pencil,
                              color: violet,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (_photoBytes.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _analyzing ? null : _analyzePhotos,
                icon: _analyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(CupertinoIcons.sparkles),
                label: WordSafeText(_analyzing ? '분석 중...' : 'AI로 분석하기'),
              ),
            ),
          ],
          if (_analysisError != null) ...[
            const SizedBox(height: 8),
            WordSafeText(
              _analysisError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          if (_breedController.text.isNotEmpty) ...[
            const SizedBox(height: 14),
            const WordSafeText(
              '분석 결과',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            WordSafeText('품종: ${_breedController.text}'),
            WordSafeText('색상: ${_colorController.text}'),
          ],
        ] else
          Column(
            children: [
              TextField(
                controller: _breedController,
                decoration: const InputDecoration(labelText: '견종'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _colorController,
                decoration: const InputDecoration(labelText: '털 색상과 특징'),
              ),
            ],
          ),
        const SizedBox(height: 22),
        const WordSafeText(
          '우리 아이 성별',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const WordSafeText('남아'),
              selected: _petGender == 'male',
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _petGender = 'male'),
            ),
            ChoiceChip(
              label: const WordSafeText('여아'),
              selected: _petGender == 'female',
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _petGender = 'female'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        TextField(
          key: const ValueKey('pet-preferred-address'),
          controller: _petAddressController,
          enabled: !_loadingExisting && !_saving,
          maxLength: 20,
          decoration: const InputDecoration(
            labelText: '반려견에게 듣고 싶은 호칭',
            counterText: '',
          ),
        ),
        const SizedBox(height: 22),
        const WordSafeText(
          '우리 아이 성격',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const WordSafeText(
          '짧은 네 가지 질문으로 평소 모습을 알려주세요. 대화 말투에 반영돼요.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        if (_personalityProfile != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _personalityProfile!.labels
                .map((label) => Chip(label: WordSafeText(label)))
                .toList(),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(CupertinoIcons.paw),
          label: WordSafeText(
            _personalityProfile == null ? '성격 테스트 시작 · 4문항' : '성격 테스트 다시 하기',
          ),
          onPressed: _saving
              ? null
              : () async {
                  final result = await showModalBottomSheet<PetPersonality>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) =>
                        PetPersonalityQuiz(initial: _personalityProfile),
                  );
                  if (result != null && mounted) {
                    setState(() {
                      _personalityProfile = result;
                      personality = result.legacyStyle;
                      _saveError = null;
                    });
                  }
                },
        ),
        const SizedBox(height: 22),
        const WordSafeText(
          'AI 캐릭터',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const WordSafeText(
          '견종·색상·성격으로 우리 아이만의 마스코트를 만들어요.',
          style: TextStyle(color: Colors.black45, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (_characterImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              color: const Color(0xFFEDE9F8),
              padding: const EdgeInsets.all(12),
              child: Image.memory(_characterImage!, height: 160),
            ),
          ),
        if (_characterError != null) ...[
          const SizedBox(height: 8),
          WordSafeText(
            _characterError!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _generatingCharacter
                ? null
                : () => _generateCharacter(reroll: _characterImage != null),
            icon: _generatingCharacter
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(CupertinoIcons.wand_stars),
            label: WordSafeText(
              _generatingCharacter
                  ? '만드는 중...'
                  : _characterImage == null
                  ? 'AI 캐릭터 만들기'
                  : '다시 만들기',
            ),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: '이름'),
        ),
        if (_saveError != null) ...[
          const SizedBox(height: 12),
          WordSafeText(_saveError!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_saving || _loadingExisting) ? null : _handleSubmit,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : WordSafeText(_hadExistingPet ? '저장하기' : 'MIRA 시작하기'),
          ),
        ),
      ],
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final _familyPageKey = GlobalKey<_FamilyPageState>();

  void _openStoryQuest() {
    setState(() => index = 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _familyPageKey.currentState?._write(context);
    });
  }

  late final DogController dog = DogController(
    SharedPreferencesDogSaveService(),
  );
  @override
  void dispose() {
    dog.dispose();
    super.dispose();
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const WordSafeText('기기에 저장한 데이터를 삭제할까요?'),
        content: const WordSafeText(
          '이 기기의 강아지 성장·캐릭터 이미지·글자 크기·안내 확인 기록을 초기화해요. 가족에게 공유한 글과 사진, 계정은 유지돼요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const WordSafeText('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const WordSafeText('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final prefs = SharedPreferencesAsync();
      await dog.flush();
      for (final key in ['dog_state_v1', privacyKey, textScaleKey]) {
        await prefs.remove(key);
      }
      await CharacterSaveService.instance.clear();
      textScaleNotifier.value = 1;
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AppFlow()),
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: WordSafeText('삭제를 완료하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onAttendance: _attendance,
        onMoodDiary: () => showMoodDiarySheet(context),
        dog: dog,
        active: index == 0,
        onOpenPet: () => setState(() => index = 1),
        onOpenFamily: _openStoryQuest,
        onOpenPhotos: () => setState(() => index = 3),
      ),
      index == 1 ? PetPage(controller: dog) : const SizedBox.shrink(),
      FamilyPage(key: _familyPageKey),
      MemoryPage(active: index == 3),
      const AiPage(),
      SettingsPage(onClearData: _clearData),
    ];
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(index: index, children: pages),
            const _MoodAlertListener(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: [
          for (final item in const [
            (MiraSymbol.home, '홈'),
            (MiraSymbol.paw, '펫'),
            (MiraSymbol.family, '가족'),
            (MiraSymbol.album, '사진첩'),
            (MiraSymbol.sparkle, 'MIRA'),
            (MiraSymbol.settings, '설정'),
          ])
            NavigationDestination(
              icon: MiraIcon(item.$1),
              selectedIcon: MiraIcon(item.$1, selected: true),
              label: item.$2,
            ),
        ],
      ),
    );
  }

  void _attendance() => showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const WordSafeText('오늘의 돌봄 현황'),
      content: const SizedBox(width: 320, child: _FamilyCareSection()),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(c),
          child: const WordSafeText('닫기'),
        ),
      ],
    ),
  );
}

class _FamilyCareSection extends StatelessWidget {
  const _FamilyCareSection();

  @override
  Widget build(BuildContext context) {
    final myUid = currentUidOrNull();
    if (myUid == null) {
      return const WordSafeText(
        '로그인이 필요해요.',
        style: TextStyle(color: Colors.black54),
      );
    }
    return FutureBuilder<String?>(
      future: FamilyService.instance.fetchMyFamilyId(myUid),
      builder: (context, familyIdSnapshot) {
        final familyId = familyIdSnapshot.data;
        if (familyIdSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (familyId == null) {
          return const WordSafeText(
            '아직 가족에 소속되어 있지 않아요.',
            style: TextStyle(color: Colors.black54),
          );
        }
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FamilyService.instance.watchFamilyMembers(familyId),
          builder: (context, memberSnapshot) {
            final members = memberSnapshot.data ?? const [];
            return StreamBuilder<Map<String, dynamic>>(
              stream: DailyCareService.instance.watchToday(familyId),
              builder: (context, careSnapshot) {
                if (careSnapshot.hasError) {
                  return const WordSafeText(
                    '돌봄 배정을 불러오지 못했어요. 잠시 후 다시 확인해주세요.',
                  );
                }
                final care = careSnapshot.data ?? const {};
                if (members.isEmpty) {
                  return const WordSafeText(
                    '가족 구성원이 없어요.',
                    style: TextStyle(color: Colors.black54),
                  );
                }
                final doneCount = members.where((m) {
                  final record = care[m['uid']] as Map<String, dynamic>?;
                  return record?['completedAt'] != null;
                }).length;
                return Card(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Row(
                          children: [
                            const WordSafeText(
                              '오늘 현황',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const Spacer(),
                            WordSafeText(
                              '$doneCount / ${members.length} 완료',
                              style: const TextStyle(
                                fontSize: 12,
                                color: violet,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final member in members)
                        Builder(
                          builder: (context) {
                            final uid = member['uid'] as String;
                            final name = member['name'] as String? ?? '이름 없음';
                            final record = care[uid] as Map<String, dynamic>?;
                            const avatar = '●';
                            final isDone = record?['completedAt'] != null;
                            if (isDone) {
                              return CareLine(
                                '$avatar $name',
                                '${record!['action']} · 완료',
                              );
                            }
                            if (uid == myUid) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: WordSafeText(
                                        record != null
                                            ? '$avatar $name · ${record['action']} 하면 완료돼요'
                                            : '$avatar $name',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const WordSafeText(
                                      '자동 배정',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return CareLine(
                              '$avatar $name',
                              record != null
                                  ? '${record['action']} · 진행 중'
                                  : '대기',
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,
    required this.child,
    this.actions,
    this.controller,
    super.key,
  });
  final String title;
  final ScrollController? controller;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => CustomScrollView(
    controller: controller,
    slivers: [
      SliverAppBar(
        floating: true,
        backgroundColor: cream,
        surfaceTintColor: Colors.transparent,
        title: WordSafeText(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
          ),
        ),
        actions: actions,
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 35),
        sliver: SliverToBoxAdapter(child: child),
      ),
    ],
  );
}

/// 다른 가족 구성원이 "오늘의 감정 한 줄 기록"에서 힘든 마음을 남기면,
/// AI가 요약한 소식을 화면 어디에 있든 팝업으로 보여준다.
class _MoodAlertListener extends StatefulWidget {
  const _MoodAlertListener();
  @override
  State<_MoodAlertListener> createState() => _MoodAlertListenerState();
}

class _MoodAlertListenerState extends State<_MoodAlertListener> {
  final _presented = <String>{};
  bool _showing = false;
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _notifications;

  @override
  Widget build(BuildContext context) {
    // IndexedStack 밖(항상 그려지는 자리)에 있는 위젯이라 currentUidOrNull()로
    // 안전하게 확인한다 — 그냥 읽으면 에러 박스가 모든 탭 위에 덮어씌워진다.
    final uid = currentUidOrNull();
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _notifications ??= NotificationService.instance.watchUnread(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Firestore 색인 누락 등으로 쿼리가 실패하면 알림이 조용히 사라지는 대신
          // 콘솔에 남겨서 원인을 바로 찾을 수 있게 한다.
          debugPrint('알림을 불러오지 못했어요: ${snapshot.error}');
        }
        final docs =
            (snapshot.data ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where((d) => !_presented.contains(d.id))
                .toList();
        if (docs.isEmpty || _showing) return const SizedBox.shrink();
        final first = docs.first;
        _showing = true;
        _presented.add(first.id);
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!context.mounted) return;
          try {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: WordSafeText(
                  first.data()['title'] as String? ?? '가족 소식',
                ),
                content: SingleChildScrollView(
                  child: WordWrapText(first.data()['message'] as String? ?? ''),
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const WordSafeText('확인'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await NotificationService.instance.markRead(uid, first.id);
            }
          } catch (_) {
            // Reading can be retried from the inbox without blocking the app.
          } finally {
            if (mounted) setState(() => _showing = false);
          }
        });
        return const SizedBox.shrink();
      },
    );
  }
}

/// PetSetup에서 AI로 만든 캐릭터 이미지가 있으면 작은 원형 프로필로 보여준다.
/// 없으면 아무것도 그리지 않는다 ("직접 꾸미기"로 건너뛴 경우 등).
class _CharacterAvatar extends StatelessWidget {
  const _CharacterAvatar();

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: CharacterSaveService.instance.load(),
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null) return const SizedBox.shrink();
      return CircleAvatar(radius: 18, backgroundImage: MemoryImage(bytes));
    },
  );
}

class HomePage extends StatelessWidget {
  const HomePage({
    required this.onAttendance,
    required this.onMoodDiary,
    required this.dog,
    required this.active,
    required this.onOpenPet,
    required this.onOpenFamily,
    required this.onOpenPhotos,
    super.key,
  });
  final DogController dog;
  final bool active;
  final VoidCallback onOpenPet;
  final VoidCallback onOpenFamily, onOpenPhotos;
  final VoidCallback onAttendance;
  final VoidCallback onMoodDiary;
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'MIRA',
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Chip(
          avatar: const Icon(
            CupertinoIcons.leaf_arrow_circlepath,
            size: 16,
            color: violet,
          ),
          label: const WordSafeText('우리 가족의 하루'),
          side: BorderSide.none,
          backgroundColor: const Color(0xFFE7EDE2),
        ),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WordSafeText(
          '${DateTime.now().month}월 ${DateTime.now().day}일 · 오늘도 함께',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Color(0xFF9C9891),
          ),
        ),
        const SizedBox(height: 8),
        const WordWrapText(
          '함께라서 좋은 하루예요.',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const _CharacterAvatar(),
            const SizedBox(width: 8),
            const Expanded(
              child: WordSafeText(
                '우리 집 작은 친구',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: onOpenPet,
              icon: const Icon(
                CupertinoIcons.arrow_up_left_arrow_down_right,
                size: 16,
              ),
              label: const WordSafeText('크게 보기'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: SizedBox(
            height: 590,
            child: active
                ? _CareCompletingDogRoom(controller: dog)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onAttendance,
            icon: const Icon(CupertinoIcons.sun_max),
            label: const WordSafeText(
              '오늘의 돌봄 확인  →',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              padding: const EdgeInsets.all(19),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _WeeklyQuests(onStory: onOpenFamily, onPhoto: onOpenPhotos),
        const SizedBox(height: 28),
        _DailyQuestsSection(
          onMoodDiary: onMoodDiary,
          onPet: onOpenPet,
          onFamily: onOpenFamily,
        ),
        const SizedBox(height: 28),
        const Section('오늘의 가족 돌봄', ''),
        const SizedBox(height: 12),
        const _FamilyCareSection(),
        const SizedBox(height: 20),
        _LiveMetrics(onEmotion: onMoodDiary, onFamily: onOpenFamily),
      ],
    ),
  );
}

class _DailyQuestsSection extends StatelessWidget {
  const _DailyQuestsSection({
    required this.onMoodDiary,
    required this.onPet,
    required this.onFamily,
  });
  final VoidCallback onMoodDiary, onPet, onFamily;
  @override
  Widget build(BuildContext context) => _ActivityBuilder(
    builder: (_, data) {
      final uid = currentUidOrNull();
      bool today(dynamic value) {
        final time = activityTime(value);
        return time != null &&
            time.year == data.now.year &&
            time.month == data.now.month &&
            time.day == data.now.day;
      }

      final cared = data.care.any(
        (d) =>
            d['uid'] == careDate() &&
            d[uid] is Map &&
            (d[uid] as Map)['completedAt'] != null,
      );
      final posted = data.moments.any(
        (d) => d['authorUid'] == uid && today(d['createdAt']),
      );
      final quests = [
        (icon: '🐾', title: '오늘의 강아지 돌봄', done: cared, onTap: onPet),
        (
          icon: '✍️',
          title: '나의 오늘 감정 기록',
          done: data.todayMoods.containsKey(uid),
          onTap: onMoodDiary,
        ),
        (icon: '💬', title: '가족에게 오늘 이야기 나누기', done: posted, onTap: onFamily),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Section('나의 일일 퀘스트', '${quests.where((q) => q.done).length} / 3 완료'),
          const SizedBox(height: 12),
          for (final quest in quests) ...[
            DailyQuest(
              icon: quest.icon,
              title: quest.title,
              done: quest.done,
              onTap: quest.onTap,
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
    },
  );
}

class PetPage extends StatelessWidget {
  const PetPage({required this.controller, super.key});
  final DogController controller;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minimumHeight =
          600.0 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 5;
      if (constraints.maxHeight >= minimumHeight) {
        return _CareCompletingDogRoom(controller: controller);
      }
      return SingleChildScrollView(
        child: SizedBox(
          height: minimumHeight,
          child: _CareCompletingDogRoom(controller: controller),
        ),
      );
    },
  );
}

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});
  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _CareCompletingDogRoom extends StatelessWidget {
  const _CareCompletingDogRoom({required this.controller});
  final DogController controller;

  @override
  Widget build(BuildContext context) => FamilyDogRoom(
    key: ValueKey(currentUidOrNull()),
    controller: controller,
    uid: currentUidOrNull(),
  );
}

class _FamilyPageState extends State<FamilyPage> {
  @override
  Widget build(BuildContext context) => AppPage(
    title: '가족 이야기',
    actions: [
      IconButton(
        onPressed: () => _write(context),
        icon: const Icon(Icons.edit_square),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Section('우리 가족', ''),
        const SizedBox(height: 12),
        const _FamilyMembersSection(),
        const SizedBox(height: 22),
        const Section('가족 이야기', '가족에게 공유'),
        const SizedBox(height: 12),
        const _MomentsSection(),
        const SizedBox(height: 22),
        const _LiveInteraction(),
      ],
    ),
  );

  Future<void> _write(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final familyId = await FamilyService.instance.fetchMyFamilyId(uid);
    if (familyId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: WordSafeText('가족에 먼저 참여해주세요.')));
      }
      return;
    }
    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final authorName = profile.data()?['name'] as String? ?? '이름 없음';
    final authorRole = profile.data()?['role'] as String? ?? '';

    final moodController = TextEditingController();
    final bodyController = TextEditingController();
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          5,
          22,
          MediaQuery.viewInsetsOf(c).bottom + 25,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WordSafeText(
              '가족에게 이야기 남기기',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: moodController,
              decoration: const InputDecoration(hintText: '이야기 제목이나 짧은 한마디'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '가족과 나누고 싶은 이야기를 적어보세요.',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final body = bodyController.text.trim();
                  if (body.isEmpty) return;
                  await MomentService.instance.addMoment(
                    familyId: familyId,
                    authorUid: uid,
                    authorName: authorName,
                    authorRole: authorRole,
                    mood: moodController.text.trim(),
                    body: body,
                  );
                  if (c.mounted) Navigator.pop(c);
                },
                child: const WordSafeText('기록하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCommentsSheet({
  required BuildContext context,
  required String familyId,
  required String momentId,
  required String? momentAuthorUid,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> comments,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final controller = TextEditingController();
  var sending = false;
  var sheetOpen = true;
  ModalRoute<dynamic>? sheetRoute;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      sheetRoute = ModalRoute.of(sheetContext);
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: WordSafeText(
                  '댓글',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              Expanded(
                child:
                    StreamBuilder<
                      List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    >(
                      stream: MomentService.instance.watchComments(
                        familyId,
                        momentId,
                      ),
                      initialData: comments,
                      builder: (context, snapshot) {
                        final docs = snapshot.data ?? const [];
                        if (docs.isEmpty) {
                          return const Center(
                            child: WordSafeText(
                              '아직 댓글이 없어요.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          );
                        }
                        return ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            for (final doc in docs)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AuthorAvatar(
                                      uid: doc.data()['authorUid'] as String?,
                                      role: doc.data()['authorRole'] as String?,
                                      radius: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          WordSafeText(
                                            doc.data()['authorName']
                                                    as String? ??
                                                '이름 없음',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          WordWrapText(
                                            doc.data()['text'] as String? ?? '',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
              ),
              if (uid != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: '댓글을 입력하세요',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.paperplane_fill),
                        onPressed: () async {
                          final text = controller.text.trim();
                          if (text.isEmpty || sending) return;
                          sending = true;
                          try {
                            final profile = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .get();
                            final myRole =
                                profile.data()?['role'] as String? ?? '';
                            await MomentService.instance.addComment(
                              familyId: familyId,
                              momentId: momentId,
                              authorUid: uid,
                              authorName:
                                  profile.data()?['name'] as String? ?? '이름 없음',
                              authorRole: myRole,
                              text: text,
                            );
                            if (momentAuthorUid != null &&
                                momentAuthorUid != uid) {
                              unawaited(
                                NotificationService.instance
                                    .sendCommentAlert(
                                      toUserId: momentAuthorUid,
                                      fromRole: myRole,
                                      relatedId: momentId,
                                    )
                                    .catchError((Object _) {}),
                              );
                            }
                            if (sheetOpen && controller.text.trim() == text) {
                              controller.clear();
                            }
                          } catch (_) {
                            if (sheetOpen && sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: WordSafeText(
                                    '댓글을 저장하지 못했어요. 다시 시도해주세요.',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            sending = false;
                          }
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
  sheetOpen = false;
  await sheetRoute?.completed;
  controller.dispose();
}

class _MomentsSection extends StatefulWidget {
  const _MomentsSection();
  @override
  State<_MomentsSection> createState() => _MomentsSectionState();
}

class _MomentsSectionState extends State<_MomentsSection> {
  String _query = '';
  StoryFilter _filter = StoryFilter.all;
  late final String? _uid = currentUidOrNull();
  late final Future<String?> _family = _uid == null
      ? Future.value(null)
      : FamilyService.instance.fetchMyFamilyId(_uid);
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _moments;

  @override
  Widget build(BuildContext context) {
    final uid = currentUidOrNull();
    if (uid == null) {
      return const WordSafeText(
        '로그인 후 가족 이야기를 볼 수 있어요.',
        style: TextStyle(color: Colors.black54),
      );
    }
    return FutureBuilder<String?>(
      future: _family,
      builder: (context, familyIdSnapshot) {
        if (familyIdSnapshot.hasError) {
          return const WordWrapText('가족 정보를 불러오지 못했어요. 연결을 확인해주세요.');
        }
        final familyId = familyIdSnapshot.data;
        if (familyIdSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (familyId == null) {
          return const WordSafeText(
            '아직 가족에 소속되어 있지 않아요.',
            style: TextStyle(color: Colors.black54),
          );
        }
        return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _moments ??= MomentService.instance.watchMoments(familyId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const WordWrapText('가족 이야기를 불러오지 못했어요. 연결을 확인해주세요.');
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final docs = snapshot.data ?? const [];
            if (docs.isEmpty) {
              return const WordSafeText(
                '아직 기록된 가족 이야기가 없어요.',
                style: TextStyle(color: Colors.black54),
              );
            }
            return Column(
              children: [
                StoryFilters(
                  onChanged: (query, filter) => setState(() {
                    _query = query;
                    _filter = filter;
                  }),
                ),
                if (!docs.any(
                  (d) => matchesStory(d.data(), _query, _filter, uid),
                ))
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: WordSafeText('조건에 맞는 이야기가 없어요.'),
                  ),
                for (final doc in docs.where(
                  (d) => matchesStory(d.data(), _query, _filter, uid),
                )) ...[
                  Builder(
                    builder: (context) {
                      final data = doc.data();
                      final likedBy = List<String>.from(
                        data['likedBy'] as List? ?? const [],
                      );
                      final isLiked = likedBy.contains(uid);
                      return StreamBuilder<
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      >(
                        stream: MomentService.instance.watchComments(
                          familyId,
                          doc.id,
                        ),
                        builder: (context, commentSnapshot) {
                          final commentDocs = commentSnapshot.data ?? const [];
                          return DiaryCard(
                            name: data['authorName'] as String? ?? '이름 없음',
                            mood: data['mood'] as String? ?? '',
                            body: data['body'] as String? ?? '',
                            authorUid: data['authorUid'] as String?,
                            authorRole: data['authorRole'] as String?,
                            likes: likedBy.length,
                            comments: commentDocs.length,
                            isLiked: isLiked,
                            onEdit: data['authorUid'] == uid
                                ? () => editMoment(
                                    context,
                                    familyId,
                                    doc.id,
                                    data,
                                  )
                                : null,
                            onDelete: data['authorUid'] == uid
                                ? () => deleteMoment(context, familyId, doc.id)
                                : null,
                            onLike: () => MomentService.instance.toggleLike(
                              familyId: familyId,
                              momentId: doc.id,
                              uid: uid,
                              currentlyLiked: isLiked,
                            ),
                            onComment: () => _showCommentsSheet(
                              context: context,
                              familyId: familyId,
                              momentId: doc.id,
                              momentAuthorUid: data['authorUid'] as String?,
                              comments: commentDocs,
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _FamilyMembersSection extends StatelessWidget {
  const _FamilyMembersSection();

  @override
  Widget build(BuildContext context) {
    final uid = currentUidOrNull();
    if (uid == null) {
      return const WordSafeText(
        '로그인 후 가족 구성원을 볼 수 있어요.',
        style: TextStyle(color: Colors.black54),
      );
    }
    return FutureBuilder<String?>(
      future: FamilyService.instance.fetchMyFamilyId(uid),
      builder: (context, familyIdSnapshot) {
        final familyId = familyIdSnapshot.data;
        if (familyIdSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (familyId == null) {
          return const WordSafeText(
            '아직 가족에 소속되어 있지 않아요.',
            style: TextStyle(color: Colors.black54),
          );
        }
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FamilyService.instance.watchFamilyMembers(familyId),
          builder: (context, snapshot) {
            final members = snapshot.data ?? const [];
            if (members.isEmpty) {
              return const WordSafeText(
                '아직 참여한 가족 구성원이 없어요.',
                style: TextStyle(color: Colors.black54),
              );
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final member in members)
                  Chip(
                    avatar: AuthorAvatar(
                      uid: member['uid'] as String?,
                      role: member['role'] as String?,
                      radius: 12,
                    ),
                    label: WordSafeText(
                      '${member['name'] ?? '이름 없음'} · ${member['role'] ?? '역할 미설정'}',
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class DiaryCard extends StatelessWidget {
  const DiaryCard({
    required this.name,
    required this.mood,
    required this.body,
    required this.likes,
    required this.comments,
    this.authorUid,
    this.authorRole,
    this.isLiked = false,
    this.onLike,
    this.onComment,
    this.onEdit,
    this.onDelete,
    super.key,
  });
  final String name, mood, body;
  final String? authorUid, authorRole;
  final int likes, comments;
  final bool isLiked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onEdit, onDelete;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuthorAvatar(uid: authorUid, role: authorRole),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WordWrapText(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    WordWrapText(
                      mood,
                      style: const TextStyle(fontSize: 12, color: violet),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          WordWrapText(body, style: const TextStyle(height: 1.6)),
          const Divider(height: 28),
          Row(
            children: [
              TextButton.icon(
                onPressed: onLike,
                icon: Icon(
                  isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  size: 19,
                  color: isLiked ? Colors.redAccent : null,
                ),
                label: WordSafeText('$likes'),
              ),
              TextButton.icon(
                onPressed: onComment,
                icon: const Icon(CupertinoIcons.chat_bubble, size: 18),
                label: WordSafeText('$comments'),
              ),
              const Spacer(),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  tooltip: '기록 관리',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit?.call();
                    } else {
                      onDelete?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: WordSafeText('수정'),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: WordSafeText('삭제'),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.onClearData, super.key});
  final VoidCallback onClearData;
  @override
  Widget build(BuildContext context) => AppPage(
    title: '설정',
    child: Column(
      children: [
        _ProfileCard(),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              setting(
                CupertinoIcons.person_2,
                '가족 관리',
                '초대 코드 · 구성원',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FamilyManagementScreen(),
                  ),
                ),
              ),
              setting(
                CupertinoIcons.paw,
                '반려견 설정',
                '프로필 · 커스터마이징',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PetSetup(onDone: () => Navigator.of(context).pop()),
                  ),
                ),
              ),
              setting(
                CupertinoIcons.bell,
                '알림함',
                '받은 소식 · 읽음 관리',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        NotificationInbox(userId: currentUidOrNull()),
                  ),
                ),
              ),
              setting(
                CupertinoIcons.bell,
                '알림 설정',
                '돌봄 · 댓글',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.lock_shield),
                title: const WordSafeText('개인정보 처리방침'),
                subtitle: const WordSafeText('저장하는 정보 · 사진 접근 · 삭제'),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
                onTap: () => showPrivacyDocument(context),
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.doc_text),
                title: const WordSafeText('이용 안내'),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
                onTap: () => showPrivacyDocument(context, terms: true),
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.trash),
                title: const WordSafeText('기기에 저장한 데이터 삭제'),
                subtitle: const WordWrapText('기기 설정 초기화 · 가족 공유 기록은 유지'),
                onTap: onClearData,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              setting(
                CupertinoIcons.paintbrush,
                '화면 설정',
                '글자 크기',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DisplaySettingsScreen(),
                  ),
                ),
              ),
              setting(
                CupertinoIcons.question_circle,
                '도움말',
                '자주 묻는 질문',
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
              ),
              setting(
                CupertinoIcons.info_circle,
                '앱 정보',
                'MIRA 1.0.0',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'MIRA',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '팀 에이원하조',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const Icon(
              CupertinoIcons.square_arrow_right,
              color: Colors.red,
            ),
            title: const WordSafeText(
              '로그아웃',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              await AuthService.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const AppFlow(skipOnboarding: true),
                  ),
                  (_) => false,
                );
              }
            },
          ),
        ),
      ],
    ),
  );
  static Widget setting(
    IconData icon,
    String title,
    String sub, {
    VoidCallback? onTap,
  }) => ListTile(
    leading: Icon(icon),
    title: WordSafeText(
      title,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: WordSafeText(sub),
    trailing: const Icon(CupertinoIcons.chevron_right),
    onTap: onTap,
  );
}

class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({super.key});
  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  bool _loading = true;
  String? _familyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final familyId = uid == null
        ? null
        : await FamilyService.instance.fetchMyFamilyId(uid);
    if (mounted) {
      setState(() {
        _familyId = familyId;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const WordSafeText('가족 관리')),
      body: uid == null
          ? const Center(child: WordSafeText('로그인이 필요해요.'))
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _familyId == null
          ? _JoinOrCreateFamilyForm(
              onSuccess: (familyId) => setState(() => _familyId = familyId),
            )
          : _FamilyDetails(familyId: _familyId!),
    );
  }
}

class _FamilyDetails extends StatelessWidget {
  const _FamilyDetails({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const WordSafeText(
        '초대 코드',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          title: WordSafeText(
            familyId,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          subtitle: const WordSafeText('가족에게 이 코드를 공유해주세요'),
          trailing: IconButton(
            icon: const Icon(CupertinoIcons.doc_on_doc),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: familyId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: WordSafeText('초대 코드를 복사했어요.')),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 24),
      const WordSafeText(
        '가족 구성원',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: FamilyService.instance.watchFamilyMembers(familyId),
        builder: (context, memberSnapshot) {
          final members = memberSnapshot.data ?? const [];
          if (members.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: WordSafeText('구성원이 없어요.'),
            );
          }
          return Card(
            child: Column(
              children: [
                for (final member in members)
                  ListTile(
                    leading: AuthorAvatar(
                      uid: member['uid'] as String?,
                      role: member['role'] as String?,
                    ),
                    title: WordSafeText(member['name'] as String? ?? '이름 없음'),
                    subtitle: WordSafeText(member['role'] as String? ?? ''),
                  ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

class _JoinOrCreateFamilyForm extends StatefulWidget {
  const _JoinOrCreateFamilyForm({required this.onSuccess});
  final ValueChanged<String> onSuccess;
  @override
  State<_JoinOrCreateFamilyForm> createState() =>
      _JoinOrCreateFamilyFormState();
}

class _JoinOrCreateFamilyFormState extends State<_JoinOrCreateFamilyForm> {
  String role = '딸';
  bool _submitting = false;
  String? _errorText;
  final _inviteCodeController = TextEditingController();

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final result = await FamilyService.instance.createFamily(role);
      widget.onSuccess(result['familyId'] as String);
    } on FamilyServiceException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleJoin() async {
    final inviteCode = _inviteCodeController.text.trim();
    if (inviteCode.isEmpty) {
      setState(() => _errorText = '초대 코드를 입력해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final result = await FamilyService.instance.joinFamily(inviteCode, role);
      widget.onSuccess(result['familyId'] as String);
    } on FamilyServiceException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const WordSafeText(
        '아직 가족에 소속되어 있지 않아요',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      const SizedBox(height: 6),
      const WordSafeText(
        '가족을 새로 만들거나, 초대 코드로 참여해보세요.',
        style: TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 20),
      const WordSafeText('내 역할', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: familyRoles
            .map(
              (e) => ChoiceChip(
                avatar: const Icon(Icons.person_rounded, size: 20),
                label: WordSafeText(e),
                selected: role == e,
                onSelected: (_) => setState(() => role = e),
              ),
            )
            .toList(),
      ),
      if (_errorText != null) ...[
        const SizedBox(height: 12),
        WordSafeText(_errorText!, style: const TextStyle(color: Colors.red)),
      ],
      const SizedBox(height: 24),
      const WordSafeText(
        '처음이신가요?',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _submitting ? null : _handleCreate,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const WordSafeText('가족 코드 생성하기'),
        ),
      ),
      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 16),
      const WordSafeText(
        '이미 가족 코드가 있으신가요?',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _inviteCodeController,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: '가족 초대 코드',
          hintText: '가족에게 받은 코드를 입력하세요',
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _submitting ? null : _handleJoin,
          child: const WordSafeText('가족 코드 등록하기'),
        ),
      ),
    ],
  );
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _care = true;
  bool _comment = true;
  bool _schedule = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 다른 가족 구성원의 클라이언트가 알림을 보내기 전에 이 값을 확인해야 해서
  // (NotificationService._isEnabled), 기기 로컬 저장소가 아니라 Firestore에 저장한다.
  Future<void> _load() async {
    final uid = currentUidOrNull();
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final doc = await NotificationService.instance.fetchPreferences(uid);
      if (mounted) {
        setState(() {
          _care = doc['careEnabled'] as bool? ?? true;
          _comment = doc['commentEnabled'] as bool? ?? true;
          _schedule = doc['scheduleEnabled'] as bool? ?? true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '알림 설정을 불러오지 못했어요. 다시 시도해주세요.';
        });
      }
    }
  }

  Future<void> _save(String key, bool value) async {
    final uid = currentUidOrNull();
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    try {
      await NotificationService.instance.setPreference(uid, key, value);
      if (!mounted) return;
      setState(() {
        if (key == 'careEnabled') _care = value;
        if (key == 'commentEnabled') _comment = value;
        if (key == 'scheduleEnabled') _schedule = value;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: WordSafeText('설정을 저장하지 못했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const WordSafeText('알림')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              if (_error != null)
                ListTile(
                  title: WordWrapText(_error!),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _load();
                    },
                    child: const WordSafeText('재시도'),
                  ),
                ),
              SwitchListTile(
                title: const WordSafeText('돌봄 알림'),
                subtitle: const WordWrapText(
                  '내게 오늘의 돌봄이 배정되거나, 가족이 돌봄을 완료하면 알려드려요',
                ),
                value: _care,
                onChanged:
                    _saving || _error != null || currentUidOrNull() == null
                    ? null
                    : (v) => _save('careEnabled', v),
              ),
              SwitchListTile(
                title: const WordSafeText('댓글 알림'),
                subtitle: const WordWrapText('가족이 내 기록에 댓글을 남기면 알려드려요'),
                value: _comment,
                onChanged:
                    _saving || _error != null || currentUidOrNull() == null
                    ? null
                    : (v) => _save('commentEnabled', v),
              ),
              SwitchListTile(
                title: const WordSafeText('일정 알림'),
                subtitle: const WordSafeText('다가오는 가족 일정을 알려드려요'),
                value: _schedule,
                onChanged:
                    _saving || _error != null || currentUidOrNull() == null
                    ? null
                    : (v) => _save('scheduleEnabled', v),
              ),
            ],
          ),
  );
}

class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const WordSafeText('화면 설정')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WordSafeText(
            '글자 크기',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<double>(
            valueListenable: textScaleNotifier,
            builder: (context, scale, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: scale,
                  min: 0.85,
                  max: 1.3,
                  divisions: 9,
                  label: '${(scale * 100).round()}%',
                  onChanged: (v) {
                    textScaleNotifier.value = v;
                    SharedPreferencesAsync().setDouble(textScaleKey, v);
                  },
                ),
                const SizedBox(height: 8),
                const WordSafeText('가족과 함께 볼 땐 이 정도가 딱 좋아요.'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = [
    ('MIRA는 무엇인가요?', '가족이 함께 반려동물을 돌보며 서로의 하루를 나누는 앱이에요.'),
    ('가족 초대 코드는 어디서 확인하나요?', '설정 → 가족 관리에서 확인하고 공유할 수 있어요.'),
    (
      '반려견 사진 분석은 어떻게 하나요?',
      '반려견 설정에서 사진을 올리고 "AI로 분석하기"를 누르면 품종과 색상을 자동으로 알려줘요.',
    ),
    ('내 기록은 가족에게 전부 공개되나요?', '가족 이야기에 직접 작성한 내용만 공개되고, 개인 정보는 안전하게 보호돼요.'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const WordSafeText('도움말')),
    body: ListView(
      children: [
        for (final item in _faq)
          ExpansionTile(
            title: WordSafeText(
              item.$1,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: WordSafeText(
                    item.$2,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = currentUidOrNull();
    if (uid == null) {
      return const Card(
        child: ListTile(
          leading: CircleAvatar(child: WordSafeText('👤')),
          title: WordSafeText('로그인 정보 없음'),
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['name'] as String? ?? '이름 없음';
        final role = data?['role'] as String?;
        return Card(
          child: ListTile(
            leading: AuthorAvatar(uid: uid, role: role),
            title: WordSafeText(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: WordSafeText(role != null ? '우리 가족 · $role' : '역할 미설정'),
            trailing: const Icon(CupertinoIcons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
            ),
          ),
        );
      },
    );
  }
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _interestsController = TextEditingController();
  DateTime? _birthday;
  bool _loading = true;
  bool _saving = false;
  bool _pickingPhoto = false;
  String? _error;
  String? _existingPhotoBase64;
  Uint8List? _newPhotoBytes;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data();
    _nameController.text = data?['name'] as String? ?? '';
    _existingPhotoBase64 = data?['photo'] as String?;
    _interestsController.text = data?['interests'] as String? ?? '';
    final birthdayStr = data?['birthday'] as String?;
    if (birthdayStr != null) {
      final parsed = DateTime.tryParse(birthdayStr);
      if (parsed != null) {
        _birthday = parsed;
        _birthdayController.text =
            '${parsed.year}. ${parsed.month.toString().padLeft(2, '0')}. ${parsed.day.toString().padLeft(2, '0')}';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthday = picked;
        _birthdayController.text =
            '${picked.year}. ${picked.month.toString().padLeft(2, '0')}. ${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _pickingPhoto = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 300 * 1024) {
        if (mounted) setState(() => _error = '프로필 사진은 300KB 이하로 선택해 주세요.');
        return;
      }
      final decoded = await decodeImageFromList(bytes);
      decoded.dispose();
      if (mounted) {
        setState(() {
          _newPhotoBytes = bytes;
          _removePhoto = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 열지 못했어요. 사진 접근 권한을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _clearPhoto() {
    setState(() {
      _newPhotoBytes = null;
      _existingPhotoBase64 = null;
      _removePhoto = true;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '이름을 입력해주세요.');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        if (_birthday != null)
          'birthday':
              '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
        'interests': _interestsController.text.trim(),
        if (_newPhotoBytes != null) 'photo': base64Encode(_newPhotoBytes!),
        if (_removePhoto && _newPhotoBytes == null)
          'photo': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = '저장하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const WordSafeText('프로필 수정')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickingPhoto ? null : _pickPhoto,
                      child: CircleAvatar(
                        radius: 48,
                        backgroundImage: _newPhotoBytes != null
                            ? MemoryImage(_newPhotoBytes!)
                            : _existingPhotoBase64 != null
                            ? MemoryImage(base64Decode(_existingPhotoBase64!))
                            : null,
                        child: _pickingPhoto
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : (_newPhotoBytes == null &&
                                  _existingPhotoBase64 == null)
                            ? const Icon(CupertinoIcons.camera, size: 28)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _pickingPhoto ? null : _pickPhoto,
                          child: const WordSafeText('사진 바꾸기'),
                        ),
                        if (_newPhotoBytes != null ||
                            _existingPhotoBase64 != null)
                          TextButton(
                            onPressed: _clearPhoto,
                            child: const WordSafeText('사진 제거'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  hintText: '이름을 입력하세요',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _interestsController,
                maxLength: 300,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '좋아하는 것과 나의 성향',
                  hintText: '예: 산책과 식물, 실용적인 선물, 조용한 시간을 좋아해요',
                  helperText: '가족에게 공유되며 MIRA의 추천에 반영돼요.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _birthdayController,
                readOnly: true,
                onTap: _pickBirthday,
                decoration: const InputDecoration(
                  labelText: '생년월일',
                  hintText: '예) 2002. 03. 14',
                  suffixIcon: Icon(CupertinoIcons.calendar),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                WordSafeText(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(18),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const WordSafeText('저장하기'),
                ),
              ),
            ],
          ),
  );
}

class QuestCard extends StatelessWidget {
  const QuestCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.progress,
    required this.color,
    this.onTap,
    super.key,
  });
  final String icon, title, detail;
  final double progress;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(26),
    child: Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(17),
            ),
            child: WordSafeText(icon, style: const TextStyle(fontSize: 25)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WordWrapText(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 5),
                WordWrapText(
                  detail,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF77716A),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: .65),
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        ],
      ),
    ),
  );
}

class DailyQuest extends StatelessWidget {
  const DailyQuest({
    required this.icon,
    required this.title,
    required this.done,
    this.onTap,
    super.key,
  });
  final String icon, title;
  final bool done;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAE6DF)),
      ),
      child: Row(
        children: [
          WordSafeText(icon, style: const TextStyle(fontSize: 21)),
          const SizedBox(width: 12),
          Expanded(
            child: WordWrapText(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: done ? const Color(0xFF928E87) : ink,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? ink : Colors.transparent,
              border: Border.all(
                color: done ? ink : const Color(0xFFD7D2CA),
                width: 1.5,
              ),
            ),
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        ],
      ),
    ),
  );
}

class CareLine extends StatelessWidget {
  const CareLine(this.who, this.action, {super.key});
  final String who, action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: WordSafeText(
            who,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: WordWrapText(action)),
      ],
    ),
  );
}

class Metric extends StatelessWidget {
  const Metric(
    this.icon,
    this.label,
    this.value, {
    this.description = '',
    super.key,
  });
  final String icon, label, value;
  final String description;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WordSafeText(
            '$icon  $label',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          WordSafeText(
            value,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            WordWrapText(
              description,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ],
      ),
    ),
  );
}

class Section extends StatelessWidget {
  const Section(this.title, this.tail, {super.key});
  final String title, tail;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: WordWrapText(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: WordWrapText(
          tail,
          style: const TextStyle(
            fontSize: 11,
            color: violet,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class Insight extends StatelessWidget {
  const Insight(this.label, this.value, this.desc, {super.key});
  final String label, value, desc;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WordWrapText(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            WordWrapText(
              desc,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      const SizedBox(width: 16),
      SizedBox(
        width: 64,
        child: WordSafeText(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(color: violet, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}
