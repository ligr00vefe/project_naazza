import '../../../core/widgets/app_scaffold.dart';
import '../data/login_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'login_brand_mark.dart';
import '../../../core/config/app_config.dart';
import '../domain/auth_failure.dart';
import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _username = TextEditingController();
  final _pin = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePin = true;
  bool _rememberId = false, _autoLogin = false, _settingsReady = false;
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final settings = await ref.read(loginPreferencesProvider);
      if (!mounted) return;
      setState(() {
        _username.text = settings.username;
        _rememberId = settings.rememberId;
        _autoLogin = settings.autoLogin;
        _settingsReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _settingsReady = true);
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _show(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  bool _validate() {
    final username = _username.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
      _show('아이디는 영문 소문자, 숫자, 밑줄로 3~20자 입력해 줘.');
      return false;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      _show('비밀번호를 확인해 줘.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_settingsReady ||
        ref.read(authControllerProvider).isLoading ||
        !_validate()) {
      return;
    }
    final controller = ref.read(authControllerProvider.notifier);
    if (_isSignUp) {
      await controller.signUp(
        _username.text,
        _pin.text,
        rememberId: _rememberId,
        autoLogin: _autoLogin,
      );
    } else {
      await controller.signIn(
        _username.text,
        _pin.text,
        rememberId: _rememberId,
        autoLogin: _autoLogin,
      );
    }
    if (!mounted) return;
    final error = ref.read(authControllerProvider).error;
    if (error != null) {
      _show(error is AuthFailure ? error.message : '요청을 처리하지 못했어. 다시 시도해 줘.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isDemo = !ref.watch(appConfigProvider).hasSupabaseConfiguration;
    final enabled = _settingsReady && !authState.isLoading;
    const green = Color(0xFF3B6FF5);
    return AppScaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 40).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: 380,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            LoginBrandMark(size: compact ? 52 : 66),
                            const SizedBox(width: 12),
                            const Text(
                              'NAAZZA',
                              style: TextStyle(
                                color: green,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 20 : 30),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isSignUp ? '나의 기록을 시작해요' : '오늘도 가볍게 기록해요',
                            key: const ValueKey('login-heading'),
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: compact ? 20 : 22,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF142443),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSignUp ? '사용할 아이디와 비밀번호를 정해 주세요' : '나의 기록이 쌓이는 곳',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF7585A1),
                          ),
                        ),
                        SizedBox(height: compact ? 20 : 28),
                        Container(
                          key: const ValueKey('login-form-card'),
                          padding: EdgeInsets.all(compact ? 20 : 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x123B6FF5),
                                blurRadius: 28,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _FieldLabel('아이디'),
                              const SizedBox(height: 7),
                              TextField(
                                controller: _username,
                                enabled: enabled,
                                autocorrect: false,
                                textCapitalization: TextCapitalization.none,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(fontSize: 14),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9_]'),
                                  ),
                                  LengthLimitingTextInputFormatter(20),
                                ],
                                decoration: _decoration(
                                  '아이디를 입력해 주세요',
                                  Icons.person_outline_rounded,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _FieldLabel('비밀번호'),
                              const SizedBox(height: 7),
                              TextField(
                                controller: _pin,
                                enabled: enabled,
                                obscureText: _obscurePin,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                style: const TextStyle(fontSize: 14),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                onSubmitted: (_) => _submit(),
                                decoration:
                                    _decoration(
                                      '비밀번호를 입력해 주세요',
                                      Icons.lock_outline_rounded,
                                    ).copyWith(
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePin
                                            ? '비밀번호 보기'
                                            : '비밀번호 숨기기',
                                        onPressed: () => setState(
                                          () => _obscurePin = !_obscurePin,
                                        ),
                                        icon: Icon(
                                          _obscurePin
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text(
                                  '숫자 4자리',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8896AE),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 18,
                                children: [
                                  _LoginOption(
                                    label: '아이디 저장',
                                    value: _rememberId,
                                    onChanged: !enabled
                                        ? null
                                        : (value) async {
                                            setState(() => _rememberId = value);
                                            if (!value) {
                                              try {
                                                await (await ref.read(
                                                  loginPreferencesProvider,
                                                )).saveUsername('', false);
                                              } catch (_) {
                                                if (mounted) {
                                                  _show(
                                                    '아이디 저장 설정을 바꾸지 못했어. 다시 시도해 줘.',
                                                  );
                                                }
                                              }
                                            }
                                          },
                                  ),
                                  _LoginOption(
                                    label: '자동 로그인',
                                    value: _autoLogin,
                                    onChanged: !enabled
                                        ? null
                                        : (value) => setState(
                                            () => _autoLogin = value,
                                          ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FilledButton(
                                key: const ValueKey('login-submit'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: green,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: enabled ? _submit : null,
                                child: authState.isLoading
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(_isSignUp ? '회원가입' : '로그인'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          key: const ValueKey('login-mode'),
                          style: TextButton.styleFrom(
                            foregroundColor: green,
                            minimumSize: const Size(48, 44),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          onPressed: authState.isLoading
                              ? null
                              : () => setState(() => _isSignUp = !_isSignUp),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: _isSignUp
                                      ? '이미 계정이 있나요?  '
                                      : '처음이신가요?  ',
                                  style: const TextStyle(
                                    color: Color(0xFF7585A1),
                                  ),
                                ),
                                TextSpan(
                                  text: _isSignUp ? '로그인' : '회원가입',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isDemo)
                          const Text(
                            '데모 모드 · 아무 아이디와 비밀번호로 체험할 수 있어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7585A1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, IconData icon) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Color(0xFFD5E4FB)),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8896AE)),
      prefixIcon: Icon(icon, size: 21, color: const Color(0xFF7585A1)),
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFF3B6FF5), width: 1.5),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Color(0xFF142443),
    ),
  );
}

class _LoginOption extends StatelessWidget {
  const _LoginOption({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged == null
                    ? null
                    : (v) => onChanged!(v ?? false),
                activeColor: const Color(0xFF3B6FF5),
                side: const BorderSide(color: Color(0xFF8896AE), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7585A1)),
            ),
          ],
        ),
      ),
    ),
  );
}
