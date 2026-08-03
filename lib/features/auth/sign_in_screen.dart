import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart' show UserCredential;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/icon_box.dart';
import '../../widgets/prekta_logo.dart';

enum _AuthMode { signIn, signUp }

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _obscurePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _supportsApple => !kIsWeb && Platform.isIOS;

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn;
    });
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final auth = ref.read(authRepositoryProvider);

    await _signIn(
      () => _mode == _AuthMode.signIn
          ? auth.signInWithEmail(email, password)
          : auth.registerWithEmail(email, password),
    );
  }

  Future<void> _signInWithGoogle() =>
      _signIn(() => ref.read(authRepositoryProvider).signInWithGoogle());

  Future<void> _signInWithApple() =>
      _signIn(() => ref.read(authRepositoryProvider).signInWithApple());

  Future<void> _signIn(Future<UserCredential> Function() action) async {
    setState(() => _busy = true);
    try {
      final credential = await action();
      final user = credential.user;
      if (user != null) {
        await ref.read(userRepositoryProvider).upsertProfile(user);
      }
      // Oturum açılınca kök widget ekranı kendisi değiştirir.
    } on SignInCancelled {
      // Kullanıcı vazgeçti — sessizce geç.
    } on SignInFailure catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Beklenmedik bir sorun oldu, tekrar dener misin?');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == _AuthMode.signUp;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xl,
            AppSpacing.screenH,
            AppSpacing.xxl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: PrektaLogo(size: 64)),
                const SizedBox(height: AppSpacing.lg),
                Center(child: Text('Prekta', style: AppTextStyles.screenTitle)),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Text(
                    'Her gün birkaç kelime. Gerisini seri getirir.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (!isSignUp) ...[
                  const _Highlights(),
                  const SizedBox(height: AppSpacing.xl),
                ],
                _EmailField(controller: _emailController),
                const SizedBox(height: AppSpacing.lg),
                _PasswordField(
                  controller: _passwordController,
                  obscure: _obscurePassword,
                  isSignUp: isSignUp,
                  onToggleObscure: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  onSubmitted: _busy ? null : _submitEmail,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _submitEmail,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(isSignUp ? 'Kayıt ol' : 'Giriş yap'),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _toggleMode,
                    child: Text(
                      isSignUp
                          ? 'Zaten hesabın var mı? Giriş yap'
                          : 'Hesabın yok mu? Kayıt ol',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _OrDivider(),
                const SizedBox(height: AppSpacing.lg),
                _GoogleButton(
                  busy: _busy,
                  onPressed: _busy ? null : _signInWithGoogle,
                ),
                if (_supportsApple) ...[
                  const SizedBox(height: AppSpacing.md),
                  _AppleButton(
                    busy: _busy,
                    onPressed: _busy ? null : _signInWithApple,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Giriş yaparak ilerlemen hesabına kaydedilir, '
                  'cihaz değiştirsen de kaybolmaz.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('E-posta', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          style: AppTextStyles.word,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(hintText: 'ornek@eposta.com'),
          validator: (value) {
            final email = (value ?? '').trim();
            if (email.isEmpty) return 'E-postanı yazman gerekiyor.';
            if (!_emailPattern.hasMatch(email)) {
              return 'Geçerli bir e-posta yaz.';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.isSignUp,
    required this.onToggleObscure,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool obscure;
  final bool isSignUp;
  final VoidCallback onToggleObscure;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Şifre', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          style: AppTextStyles.word,
          obscureText: obscure,
          textInputAction: TextInputAction.done,
          autofillHints: [
            isSignUp ? AutofillHints.newPassword : AutofillHints.password,
          ],
          onFieldSubmitted: (_) => onSubmitted?.call(),
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
            ),
          ),
          validator: (value) {
            final password = value ?? '';
            if (password.isEmpty) return 'Şifreni yazman gerekiyor.';
            if (isSignUp && password.length < 6) {
              return 'Şifre en az 6 karakter olmalı.';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('veya', style: AppTextStyles.caption),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: const [
          _HighlightRow(
            icon: Icons.bolt_outlined,
            background: AppColors.primarySurface,
            foreground: AppColors.primary,
            text: 'Günlük hedefinle küçük adımlarla ilerle',
          ),
          Divider(height: 1),
          _HighlightRow(
            icon: Icons.local_fire_department_outlined,
            background: AppColors.streakSurface,
            foreground: AppColors.streak,
            text: 'Serini koru, çalışma alışkanlığını sürdür',
          ),
          Divider(height: 1),
          _HighlightRow(
            icon: Icons.check_circle_outline,
            background: AppColors.successSurface,
            foreground: AppColors.success,
            text: 'Her kelimenin ustalığını 5 adımda takip et',
          ),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.text,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          IconBox(
            icon: icon,
            background: background,
            foreground: foreground,
            size: 34,
            iconSize: 18,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _GoogleGlyph(),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Google ile devam et',
                  style: AppTextStyles.button.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.apple, size: 22, color: Colors.white),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Apple ile devam et',
                  style: AppTextStyles.button.copyWith(color: Colors.white),
                ),
              ],
            ),
    );
  }
}

/// Google markasının "G" harfi. Tek renkli tutuldu — arayüzün geri kalanı
/// gibi sade dursun diye.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.iconBox - 4),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
          height: 1.1,
        ),
      ),
    );
  }
}
