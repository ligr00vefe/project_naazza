import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';
import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _verificationRequested = false;
  bool _emailVerified = false;
  bool _checkingVerification = false;
  String? _verifiedEmail;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _show(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _sendVerification() async {
    final email = _email.text.trim();
    if (!_isValidEmail(email)) {
      _show('인증 메일을 받을 이메일 주소를 입력해 주세요.');
      return;
    }
    if (_password.text.length < 6) {
      _show('회원가입에 사용할 6자 이상의 비밀번호를 입력해 주세요.');
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .signUp(email, _password.text);
    if (!mounted || _email.text.trim() != email) return;
    final error = ref.read(authControllerProvider).error;
    if (error != null) {
      _show('인증 메일을 보내지 못했어요: $error');
      return;
    }
    setState(() {
      _verificationRequested = true;
      _verifiedEmail = null;
    });
    _show('$email 로 인증 메일을 보냈어요. 메일의 인증 버튼을 눌러 주세요.');
  }

  Future<void> _resendVerification() async {
    await ref
        .read(authControllerProvider.notifier)
        .resendEmailVerification(_email.text.trim());
    if (!mounted) return;
    final error = ref.read(authControllerProvider).error;
    _show(error == null ? '인증 메일을 다시 보냈어요.' : '메일 재발송에 실패했어요: $error');
  }

  Future<void> _checkVerification() async {
    setState(() => _checkingVerification = true);
    final verified = await ref
        .read(authControllerProvider.notifier)
        .refreshEmailVerification(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _checkingVerification = false;
      _emailVerified = verified;
      _verifiedEmail = verified ? _email.text.trim() : null;
    });
    _show(
      verified ? '이메일 인증이 완료되었습니다.' : '아직 인증이 확인되지 않았어요. 메일의 인증 버튼을 먼저 눌러 주세요.',
    );
  }

  Future<void> _submit() async {
    if (_isSignUp) {
      if (!_emailVerified) {
        _show(
          _verificationRequested ? '인증 확인을 먼저 눌러 주세요.' : '먼저 이메일 인증을 진행해 주세요.',
        );
        return;
      }
    }
    await ref
        .read(authControllerProvider.notifier)
        .signIn(_email.text, _password.text);
    if (!mounted) return;
    final error = ref.read(authControllerProvider).error;
    if (error != null) _show('로그인에 실패했어요: $error');
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isDemo = !ref.watch(appConfigProvider).hasSupabaseConfiguration;
    ref.listen<AsyncValue<AuthUser?>>(authStateProvider, (_, next) {
      if (next.value?.isEmailVerified == true && mounted) {
        setState(() {
          _verificationRequested = true;
          _emailVerified = true;
          _verifiedEmail = next.value!.email;
        });
      }
    });
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.eco_rounded,
                    size: 66,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'NAAZZA',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp
                        ? '건강 기록을 시작하기 전에 이메일을 인증해 주세요.'
                        : '나의 기록이 내일의 변화를 만들어요',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onChanged: (value) {
                      if (_verificationRequested ||
                          (_emailVerified && value.trim() != _verifiedEmail)) {
                        setState(() {
                          _verificationRequested = false;
                          _emailVerified = false;
                          _verifiedEmail = null;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  if (_isSignUp) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: authState.isLoading || _emailVerified
                          ? null
                          : (_verificationRequested
                                ? _resendVerification
                                : _sendVerification),
                      icon: Icon(
                        _emailVerified
                            ? Icons.verified_rounded
                            : Icons.mark_email_read_outlined,
                      ),
                      label: Text(_emailVerified ? '인증 완료' : '이메일 인증'),
                    ),
                    if (_verificationRequested && !_emailVerified) ...[
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F8F4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '메일함에서 인증 링크를 누른 뒤 확인해 주세요.',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: authState.isLoading
                                      ? null
                                      : _checkVerification,
                                  child: Text(
                                    _checkingVerification ? '확인 중...' : '인증 확인',
                                  ),
                                ),
                                TextButton(
                                  onPressed: authState.isLoading
                                      ? null
                                      : _resendVerification,
                                  child: const Text('메일 재발송'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      helperText: '6자 이상',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: authState.isLoading ? null : _submit,
                    child: authState.isLoading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isSignUp ? '회원가입' : '로그인'),
                  ),
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => setState(() {
                            _isSignUp = !_isSignUp;
                            _verificationRequested = false;
                            _emailVerified = false;
                            _verifiedEmail = null;
                          }),
                    child: Text(_isSignUp ? '이미 계정이 있나요? 로그인' : '처음인가요? 회원가입'),
                  ),
                  if (isDemo)
                    const Card(
                      color: Color(0xFFF0F8F4),
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          '현재 데모 모드입니다. 실제 이메일 인증은 Supabase 설정 후 동작합니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.primary,
                            height: 1.45,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
