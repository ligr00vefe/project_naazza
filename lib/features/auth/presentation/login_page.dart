import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController(text: 'demo@naazza.app');
  final _password = TextEditingController(text: 'password');
  bool _isSignUp = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 6자 이상의 비밀번호를 입력해 주세요.')),
      );
      return;
    }
    final controller = ref.read(authControllerProvider.notifier);
    _isSignUp
        ? await controller.signUp(_email.text, _password.text)
        : await controller.signIn(_email.text, _password.text);
    if (!mounted) return;
    final error = ref.read(authControllerProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('인증에 실패했어요: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isDemo = !ref.watch(appConfigProvider).hasSupabaseConfiguration;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.eco_rounded,
                    size: 74,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'NAAZZA',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '나의 기록이 내일의 변화를 만들어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: authState.isLoading ? null : _submit,
                    child: authState.isLoading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp ? '회원가입' : '로그인'),
                  ),
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(_isSignUp ? '이미 계정이 있나요? 로그인' : '처음인가요? 회원가입'),
                  ),
                  if (isDemo) ...[
                    const SizedBox(height: 12),
                    const Card(
                      color: Color(0xFFF0F8F4),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          '현재 데모 모드입니다. 어떤 이메일과 6자 이상의 비밀번호로도 화면을 확인할 수 있어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.primary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
