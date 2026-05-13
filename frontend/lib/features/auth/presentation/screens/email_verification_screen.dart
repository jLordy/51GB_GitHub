
import 'package:frontend/core/widgets/custom_snackbar.dart';
import 'package:frontend/features/auth/controller/auth_controller.dart';
import 'package:frontend/features/auth/data/register_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EmailVerificationArgs {
  final RegisterRequest request;

  const EmailVerificationArgs({required this.request});
}

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final EmailVerificationArgs args;

  const EmailVerificationScreen({super.key, required this.args});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  String get _otp => _otpControllers.map((c) => c.text.trim()).join();

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyAndRegister() async {
    if (_otp.length != 6) {
      AppSnackBar.show(
        context,
        'Please enter all 6 digits.',
        type: SnackBarType.error,
      );
      return;
    }

    final email = widget.args.request.email.trim();
    final verified = await ref
        .read(registrationOtpControllerProvider.notifier)
        .verifyOtp(email, _otp);

    if (!verified || !mounted) return;

    await ref
        .read(authControllerProvider.notifier)
        .register(widget.args.request);

    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    if (authState.hasError) {
      AppSnackBar.show(
        context,
        authState.error.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
      return;
    }

    context.go('/role-selection');
  }

  Future<void> _resend() async {
    final email = widget.args.request.email.trim();
    final ok = await ref
        .read(registrationOtpControllerProvider.notifier)
        .sendOtp(email);
    if (ok && mounted) {
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes[0].requestFocus();
      AppSnackBar.show(
        context,
        'Verification code sent.',
        type: SnackBarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final verifyState = ref.watch(registrationOtpControllerProvider);
    final authState = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(registrationOtpControllerProvider, (
      prev,
      next,
    ) {
      if (next.hasError) {
        AppSnackBar.show(
          context,
          next.error.toString().replaceFirst('Exception: ', ''),
          type: SnackBarType.error,
        );
      }
    });

    ref.listen<AsyncValue<void>>(authControllerProvider, (prev, next) {
      if (next.hasError) {
        AppSnackBar.show(
          context,
          next.error.toString().replaceFirst('Exception: ', ''),
          type: SnackBarType.error,
        );
      }
    });

    final isLoading = verifyState.isLoading || authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 36,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Verify Your Email',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to\n${widget.args.request.email}',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

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
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant,
                          ),
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
                  onPressed: isLoading ? null : _verifyAndRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
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
                          'VERIFY ACCOUNT',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.7,
                            color: isLightMode
                                ? Colors.white
                                : colorScheme.onPrimary,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              _ResendButton(enabled: !isLoading, onResend: _resend),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResendButton extends StatefulWidget {
  const _ResendButton({required this.enabled, required this.onResend});

  final bool enabled;
  final Future<void> Function() onResend;

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
      onPressed: (_canResend && widget.enabled)
          ? () async {
              _startCooldown();
              await widget.onResend();
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
                color: (_canResend && widget.enabled)
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