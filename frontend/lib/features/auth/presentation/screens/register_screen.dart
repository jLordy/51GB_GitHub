
import 'package:frontend/features/auth/controller/auth_controller.dart';
import 'package:frontend/features/auth/data/register_request.dart';
import 'package:frontend/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:frontend/theme/palette.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _formErrorMessage;

  String _friendlyAuthError(Object error) {
    // FirebaseAuthException — most reliable for Firebase errors.
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'weak-password':
          return 'Password is too weak. Use at least 8 characters with a mix of letters, numbers, and symbols.';
        case 'email-already-in-use':
          return 'This email is already registered. Try signing in instead.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'operation-not-allowed':
          return 'Email sign-up is currently disabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please wait a few minutes before trying again.';
        case 'network-request-failed':
          return 'No internet connection. Please check your network and try again.';
      }
    }

    // DioException — backend HTTP errors.
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 409) {
        return 'This email is already registered. Try signing in instead.';
      }
      if (status == 400 || status == 422) {
        return 'Some of the information you entered is invalid. Please review and try again.';
      }
      if (status == 404) {
        return 'The sign-up service could not be reached. Please try again later.';
      }
      if (status == 429) {
        return 'Too many requests. Please wait a moment before trying again.';
      }
      if (status != null && status >= 500) {
        return 'A server error occurred. Please try again in a few moments.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'The request timed out. Please check your connection and try again.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network and try again.';
      }
    }

    final message = error.toString().toLowerCase();

    if (message.contains('googlesigninexceptioncode.canceled') ||
        message.contains('canceled by user') ||
        message.contains('cancelled by user')) {
      return 'Google sign-in was cancelled.';
    }

    if (message.contains('email-already-in-use') ||
        message.contains('conflict') ||
        message.contains('409')) {
      return 'This email is already registered. Try signing in instead.';
    }

    if (message.contains('weak-password')) {
      return 'Password is too weak. Use at least 8 characters with a mix of letters, numbers, and symbols.';
    }

    if (message.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }

    if (message.contains('too-many-requests') || message.contains('too many')) {
      return 'Too many failed attempts. Please wait a few minutes before trying again.';
    }

    if (message.contains('network') ||
        message.contains('connection') ||
        message.contains('internet')) {
      return 'No internet connection. Please check your network and try again.';
    }

    if (message.contains('timeout') || message.contains('timed out')) {
      return 'The request timed out. Please check your connection and try again.';
    }

    if (message.contains('400') ||
        message.contains('422') ||
        message.contains('bad request') ||
        message.contains('unprocessable')) {
      return 'Some of the information you entered is invalid. Please review and try again.';
    }

    return 'Sign-up failed. Please try again.';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _formErrorMessage = null);

    if (!_formKey.currentState!.validate()) {
      if (_confirmPasswordController.text != _passwordController.text) {
        setState(() => _formErrorMessage = 'Passwords do not match!');
      } else {
        setState(
          () => _formErrorMessage = 'Please fix the highlighted fields.',
        );
      }
      return;
    }

    final request = RegisterRequest(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      displayName: _displayNameController.text.trim(),
    );

    final sent = await ref
        .read(registrationOtpControllerProvider.notifier)
        .sendOtp(request.email);

    if (!sent) {
      final otpState = ref.read(registrationOtpControllerProvider);
      final message = otpState.error?.toString().replaceFirst(
        'Exception: ',
        '',
      );
      setState(
        () =>
            _formErrorMessage = message ?? 'Failed to send verification code.',
      );
      return;
    }

    if (!mounted) return;
    context.push(
      '/email-verification',
      extra: EmailVerificationArgs(request: request),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );
    final focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
    );
    final errorInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: colorScheme.error, width: 1.4),
    );

    InputDecoration buildInputDecoration({
      required String hint,
      required IconData prefixIcon,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        hintText: hint,
        prefixIcon: Icon(prefixIcon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedInputBorder,
        errorBorder: errorInputBorder,
        focusedErrorBorder: errorInputBorder,
      );
    }

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      if (next.hasError) {
        final friendlyMessage = _friendlyAuthError(next.error!);
        setState(() => _formErrorMessage = friendlyMessage);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWebLayout = kIsWeb && constraints.maxWidth >= 900;
            final showHeroPanel = constraints.maxWidth >= 1024;

            final formShell = SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWebLayout ? 0 : 24,
                vertical: isWebLayout ? 0 : 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: isWebLayout ? 8 : 24),
                    Image.asset(
                      'assets/images/agapay_icon.png',
                      height: 68,
                      width: 68,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Sign Up',
                      style: textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join our community for personalized wellness insights.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Display Name',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _displayNameController,
                      decoration: buildInputDecoration(
                        hint: 'Enter your display name...',
                        prefixIcon: Icons.person_outline,
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Display name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Email Address',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _emailController,
                      decoration: buildInputDecoration(
                        hint: 'Enter your email...',
                        prefixIcon: Icons.email_outlined,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Invalid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Password',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordController,
                      decoration: buildInputDecoration(
                        hint: 'Enter your password...',
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Password Confirmation',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: buildInputDecoration(
                        hint: 'Confirm your password...',
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                      obscureText: _obscureConfirmPassword,
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    if (_formErrorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.35,
                          ),
                          border: Border.all(color: colorScheme.error),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 18,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formErrorMessage!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    authState.isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              backgroundColor: colorScheme.primary,
                              foregroundColor: isLightMode
                                  ? Colors.white
                                  : colorScheme.onPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              'SIGN UP',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: isLightMode
                                    ? Colors.white
                                    : colorScheme.onPrimary,
                              ),
                            ),
                          ),

                    const SizedBox(height: 18),

                    TextButton(
                      onPressed: () => context.go('/login'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          children: [
                            TextSpan(
                              text: 'Sign In',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isWebLayout ? 8 : 16),
                  ],
                ),
              ),
            );

            if (!isWebLayout) return formShell;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Palette.lightSurfaceContainerColor,
                    colorScheme.surface,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.zero,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: Palette.greenColor, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 10,
                          child: Container(
                            color: colorScheme.surface,
                            padding: const EdgeInsets.fromLTRB(30, 26, 30, 22),
                            child: formShell,
                          ),
                        ),
                        if (showHeroPanel)
                          Expanded(
                            flex: 11,
                            child: _WebRegisterHero(colorScheme: colorScheme),
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
}

class _WebRegisterHero extends StatelessWidget {
  const _WebRegisterHero({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Palette.greenColor, Palette.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/agapay_icon.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Text(
                'Agapay',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  right: -120,
                  top: 36,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                ),
                Positioned(
                  left: -80,
                  bottom: -120,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Center(
                  child: Lottie.asset(
                    'assets/images/Doctor.json',
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Welcome to Agapay',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join our community and unlock personalized wellness insights.',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}