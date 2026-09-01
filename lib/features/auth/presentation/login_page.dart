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
  final _passwordConfirmation = TextEditingController(text: 'password');
  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _pendingConfirmationEmail;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!_looksLikeEmail(email)) {
      _showMessage('올바른 이메일 주소를 입력해 주세요.');
      return;
    }
    if (_password.text.length < 6) {
      _showMessage('비밀번호는 6자 이상 입력해 주세요.');
      return;
    }
    if (_isSignUp && _password.text != _passwordConfirmation.text) {
      _showMessage('비밀번호 확인이 일치하지 않아요.');
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    if (_isSignUp) {
      final result = await controller.signUp(email, _password.text);
      if (!mounted) return;
      final error = ref.read(authControllerProvider).error;
      if (error != null) {
        _showMessage(_friendlyError(error));
      } else if (result?.requiresEmailConfirmation == true) {
        setState(() => _pendingConfirmationEmail = email);
      }
    } else {
      await controller.signIn(email, _password.text);
      if (!mounted) return;
      final error = ref.read(authControllerProvider).error;
      if (error != null) _showMessage(_friendlyError(error));
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _pendingConfirmationEmail;
    if (email == null) return;
    final sent = await ref
        .read(authControllerProvider.notifier)
        .resendSignUpConfirmation(email);
    if (!mounted) return;
    if (sent) {
      _showMessage('인증 메일을 다시 보냈어요. 메일함을 확인해 주세요.');
    } else {
      _showMessage(_friendlyError(ref.read(authControllerProvider).error));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object? error) {
    final message = error.toString();
    if (message.contains('over_email_send_rate_limit')) {
      return '인증 메일을 너무 자주 요청했어요. 잠시 후 다시 시도해 주세요.';
    }
    if (message.contains('Invalid login credentials')) {
      return '이메일 또는 비밀번호가 올바르지 않아요.';
    }
    if (message.contains('Email not confirmed')) {
      return '이메일 인증이 아직 완료되지 않았어요. 메일함을 확인해 주세요.';
    }
    return '요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.';
  }

  bool _looksLikeEmail(String value) {
    final at = value.indexOf('@');
    return at > 0 && value.indexOf('.', at) > at + 1;
  }

  void _showLoginForm() {
    setState(() {
      _pendingConfirmationEmail = null;
      _isSignUp = false;
    });
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
                  if (_pendingConfirmationEmail != null)
                    _ConfirmationPanel(
                      email: _pendingConfirmationEmail!,
                      isLoading: authState.isLoading,
                      onResend: _resendConfirmation,
                      onLogin: _showLoginForm,
                      onChangeEmail: () =>
                          setState(() => _pendingConfirmationEmail = null),
                    )
                  else ...[
                    Text(
                      _isSignUp ? '이메일로 회원가입' : '로그인',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSignUp
                          ? '회원가입 버튼을 누르면 입력한 주소로 인증 메일을 보내드려요.'
                          : '가입한 이메일과 비밀번호를 입력해 주세요.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _email,
                      enabled: !authState.isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        hintText: 'name@example.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      enabled: !authState.isLoading,
                      obscureText: _obscurePassword,
                      textInputAction: _isSignUp
                          ? TextInputAction.next
                          : TextInputAction.done,
                      autofillHints: [
                        _isSignUp
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      onSubmitted: _isSignUp ? null : (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        helperText: _isSignUp ? '6자 이상 입력해 주세요.' : null,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                        ),
                      ),
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordConfirmation,
                        enabled: !authState.isLoading,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: '비밀번호 확인',
                          prefixIcon: Icon(Icons.lock_reset_rounded),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: authState.isLoading ? null : _submit,
                      icon: authState.isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _isSignUp
                                  ? Icons.mark_email_unread_outlined
                                  : Icons.login_rounded,
                            ),
                      label: Text(_isSignUp ? '가입하고 인증 메일 받기' : '로그인'),
                    ),
                    TextButton(
                      onPressed: authState.isLoading
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp ? '이미 계정이 있나요? 로그인' : '처음인가요? 이메일로 회원가입',
                      ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationPanel extends StatelessWidget {
  const _ConfirmationPanel({
    required this.email,
    required this.isLoading,
    required this.onResend,
    required this.onLogin,
    required this.onChangeEmail,
  });

  final String email;
  final bool isLoading;
  final VoidCallback onResend;
  final VoidCallback onLogin;
  final VoidCallback onChangeEmail;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F8F4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 58,
              color: AppColors.primary,
            ),
            const SizedBox(height: 18),
            Text(
              '인증 메일을 보냈어요',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '메일에 있는 인증 링크를 누르면 가입이 완료됩니다. 인증 후 이 화면으로 돌아와 로그인해 주세요. 스팸함도 확인해 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.55),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: isLoading ? null : onLogin,
              child: const Text('인증했어요 · 로그인하기'),
            ),
            OutlinedButton(
              onPressed: isLoading ? null : onResend,
              child: Text(isLoading ? '전송 중…' : '인증 메일 다시 보내기'),
            ),
            TextButton(
              onPressed: isLoading ? null : onChangeEmail,
              child: const Text('이메일 주소 수정하기'),
            ),
          ],
        ),
      ),
    );
  }
}
