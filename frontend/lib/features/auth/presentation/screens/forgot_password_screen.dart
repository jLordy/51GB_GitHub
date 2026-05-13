
import 'package:frontend/core/widgets/custom_snackbar.dart';
import 'package:frontend/features/auth/controller/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _ResetStep { email, otp, newPassword, success }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  _ResetStep _step = _ResetStep.email;

  // Step 1 — email
  final _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();

  // Step 2 — OTP (6 individual boxes)
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _otpFormKey = GlobalKey<FormState>();

  // Step 3 — new password
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _enteredOtp => _otpControllers.map((c) => c.text.trim()).join();

  // ── Step 1: send OTP ──────────────────────────────────────────────────────

  Future<void> _onSendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .sendOtp(email);
    if (ok && mounted) {
      setState(() => _step = _ResetStep.otp);
    }
  }

  // ── Step 2: verify OTP ───────────────────────────────────────────────────

  Future<void> _onVerifyOtp() async {
    if (_enteredOtp.length < 6) {
      AppSnackBar.show(
        context,
        'Please enter all 6 digits.',
        type: SnackBarType.error,
      );
      return;
    }
    final email = _emailController.text.trim();
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .verifyOtp(email, _enteredOtp);
    if (ok && mounted) {
      setState(() => _step = _ResetStep.newPassword);
    }
  }

  // ── Step 3: reset password ───────────────────────────────────────────────

  Future<void> _onResetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .resetPassword(email, _enteredOtp, _passwordController.text.trim());
    if (ok && mounted) {
      setState(() => _step = _ResetStep.success);
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  String _stepTitle() => switch (_step) {
    _ResetStep.email => 'Forgot Password',
    _ResetStep.otp => 'Enter Reset Code',
    _ResetStep.newPassword => 'Set New Password',
    _ResetStep.success => 'All Done!',
  };

  String _stepSubtitle() => switch (_step) {
    _ResetStep.email =>
      "Enter your email and we'll send you a 6-digit reset code.",
    _ResetStep.otp =>
      "We sent a code to ${_emailController.text.trim()}.\nEnter it below.",
    _ResetStep.newPassword => 'Create a new password for your account.',
    _ResetStep.success => 'Your password has been reset successfully.',
  };

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final resetState = ref.watch(passwordResetControllerProvider);

    ref.listen<AsyncValue<void>>(passwordResetControllerProvider, (
      previous,
      next,
    ) {
      if (next.hasError) {
        AppSnackBar.show(
          context,
          next.error!.toString().replaceFirst('Exception: ', ''),
          type: SnackBarType.error,
        );
      }
    });

    final roundedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _step != _ResetStep.success
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: colorScheme.onSurface,
                ),
                onPressed: () {
                  if (_step == _ResetStep.email) {
                    context.pop();
                  } else if (_step == _ResetStep.otp) {
                    setState(() => _step = _ResetStep.email);
                  } else if (_step == _ResetStep.newPassword) {
                    setState(() => _step = _ResetStep.otp);
                  }
                },
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // ── Icon ────────────────────────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _step == _ResetStep.success
                      ? Icons.check_circle_rounded
                      : Icons.lock_reset_rounded,
                  size: 36,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),

              // ── Title ───────────────────────────────────────────────────
              Text(
                _stepTitle(),
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _stepSubtitle(),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ── Step content ────────────────────────────────────────────
              if (_step == _ResetStep.email)
                _buildEmailStep(
                  colorScheme,
                  textTheme,
                  isLightMode,
                  roundedBorder,
                  focusedBorder,
                  resetState,
                ),

              if (_step == _ResetStep.otp)
                _buildOtpStep(colorScheme, textTheme, isLightMode, resetState),

              if (_step == _ResetStep.newPassword)
                _buildPasswordStep(
                  colorScheme,
                  textTheme,
                  isLightMode,
                  roundedBorder,
                  focusedBorder,
                  resetState,
                ),

              if (_step == _ResetStep.success)
                _buildSuccessStep(colorScheme, textTheme, isLightMode),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Step widgets ────────────────────────────────

  Widget _buildEmailStep(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isLightMode,
    OutlineInputBorder roundedBorder,
    OutlineInputBorder focusedBorder,
    AsyncValue<void> resetState,
  ) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Email Address',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'name@gmail.com',
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              border: roundedBorder,
              enabledBorder: roundedBorder,
              focusedBorder: focusedBorder,
            ),
            validator: (v) {
              if (v == null || !v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: resetState.isLoading ? null : _onSendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: resetState.isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: isLightMode
                            ? Colors.white
                            : colorScheme.onPrimary,
                      ),
                    )
                  : Text(
                      'SEND CODE',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isLightMode
                            ? Colors.white
                            : colorScheme.onPrimary,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: Text(
                'Back to Sign In',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isLightMode,
    AsyncValue<void> resetState,
  ) {
    return Form(
      key: _otpFormKey,
      child: Column(
        children: [
          // ── 6 OTP boxes ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 48,
                height: 56,
                child: TextFormField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: colorScheme.surface,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.length == 1 && index < 5) {
                      _otpFocusNodes[index + 1].requestFocus();
                    } else if (value.isEmpty && index > 0) {
                      _otpFocusNodes[index - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: resetState.isLoading ? null : _onVerifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: resetState.isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: isLightMode
                            ? Colors.white
                            : colorScheme.onPrimary,
                      ),
                    )
                  : Text(
                      'VERIFY CODE',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isLightMode
                            ? Colors.white
                            : colorScheme.onPrimary,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Resend ───────────────────────────────────────────────────
          _ResendButton(
            onResend: () async {
              final email = _emailController.text.trim();
              final ok = await ref
                  .read(passwordResetControllerProvider.notifier)
                  .sendOtp(email);
              if (ok && mounted) {
                for (final c in _otpControllers) {
                  c.clear();
                }
                _otpFocusNodes[0].requestFocus();
                AppSnackBar.show(
                  context,
                  'A new code has been sent.',
                  type: SnackBarType.success,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isLightMode,
    OutlineInputBorder roundedBorder,
    OutlineInputBorder focusedBorder,
    AsyncValue<void> resetState,
  ) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── New password ────────────────────────────────────────────
          Text(
            'New Password',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Min. 8 characters',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              border: roundedBorder,
              enabledBorder: roundedBorder,
              focusedBorder: focusedBorder,
            ),
            validator: (v) {
              if (v == null || v.trim().length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Confirm password ────────────────────────────────────────
          Text(
            'Confirm Password',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              filled: true,
              fillColor: colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              border: roundedBorder,
              enabledBorder: roundedBorder,
              focusedBorder: focusedBorder,
            ),
            validator: (v) {
              if (v != _passwordController.text.trim()) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: resetState.isLoading ? null : _onResetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: resetState.isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: isLightMode
                            ? Colors.white
                            : colorScheme.onPrimary,
                      ),
                    )
                  : Text(
                      'RESET PASSWORD',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isLightMode
                            ? Colors.white
                            : colorScheme.onPrimary,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isLightMode,
  ) {
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: Text(
              'BACK TO SIGN IN',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isLightMode ? Colors.white : colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Resend button with 60s cooldown ──────────────────────────────────────────

class _ResendButton extends StatefulWidget {
  const _ResendButton({required this.onResend});
  final VoidCallback onResend;

  @override
  State<_ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<_ResendButton> {
  int _secondsLeft = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    setState(() {
      _secondsLeft = 60;
      _canResend = false;
    });
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) _canResend = true;
      });
      return _secondsLeft > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return TextButton(
      onPressed: _canResend
          ? () {
              _startCooldown();
              widget.onResend();
            }
          : null,
      child: Text.rich(
        TextSpan(
          text: "Didn't receive a code? ",
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          children: [
            TextSpan(
              text: _canResend ? 'Resend' : 'Resend in ${_secondsLeft}s',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _canResend
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}