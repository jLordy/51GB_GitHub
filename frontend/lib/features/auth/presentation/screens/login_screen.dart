
import 'package:frontend/core/widgets/custom_snackbar.dart';
import 'package:frontend/features/auth/controller/auth_controller.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Controllers for text inputs
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  bool _isGoogleCancelError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('googlesigninexceptioncode.canceled') ||
        message.contains('canceled by user') ||
        message.contains('cancelled by user');
  }

  String _friendlyAuthError(Object error) {
    final raw = error.toString();
    final message = raw.toLowerCase();

    if (message.contains('googlesigninexceptioncode.canceled') ||
        message.contains('canceled by user') ||
        message.contains('cancelled by user')) {
      return 'Google sign-in was cancelled.';
    }

    if (message.contains('network')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    if (message.contains('user-not-found')) {
      return 'No account found with this email.';
    }

    if (message.contains('invalid-credential') ||
        message.contains('wrong-password')) {
      return 'Invalid email or password.';
    }

    if (message.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    return 'Unable to sign in right now. Please try again.';
  }

  @override
  void dispose() {
    // Always dispose controllers to free memory (React: cleanup function in useEffect)
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Helper to submit form
  void _submit() {
    if (!_formKey.currentState!.validate()) return; // Stop if regex fails

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    ref.read(authControllerProvider.notifier).login(email, password);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the state to show Loading Spinner or Error
    final authState = ref.watch(authControllerProvider);

    // Pull the color scheme once; all color references below derive from it
    // so the widget automatically reflects theme changes without manual
    // provider subscriptions.
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    final roundedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    final focusedRoundedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
    );

    // specific_syntax: ref.listen fires ONLY when state changes (perfect for Snackbars/Navigation)
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      if (next.hasError) {
        final isGoogleCancel = _isGoogleCancelError(next.error!);
        final friendlyMessage = _friendlyAuthError(next.error!);
        AppSnackBar.show(
          context,
          friendlyMessage,
          type: isGoogleCancel ? SnackBarType.info : SnackBarType.error,
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWebLayout = kIsWeb && constraints.maxWidth >= 900;
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

                    // ── App icon ──────────────────────────────────────────────
                    Image.asset(
                      'assets/images/agapay_icon.png',
                      height: isWebLayout ? 64 : 75,
                      width: isWebLayout ? 64 : 75,
                    ),
                    SizedBox(height: isWebLayout ? 14 : 18),

                    // ── App title ─────────────────────────────────────────────
                    Text(
                      'Sign In',
                      style: textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        fontSize: isWebLayout ? 34 : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back to AGAPAY.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: isWebLayout ? 24 : 28),

                    // ── Email field ───────────────────────────────────────────
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
                        focusedBorder: focusedRoundedBorder,
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

                    // ── Password field ────────────────────────────────────────
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
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
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
                        filled: true,
                        fillColor: colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        border: roundedBorder,
                        enabledBorder: roundedBorder,
                        focusedBorder: focusedRoundedBorder,
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password too short';
                        }
                        return null;
                      },
                    ),

                    // ── Forgot password ───────────────────────────────────────
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Log In button ─────────────────────────────────────────
                    authState.isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(),
                          )
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
                              'LOG IN',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: isLightMode
                                    ? Colors.white
                                    : colorScheme.onPrimary,
                              ),
                            ),
                          ),

                    const SizedBox(height: 24),

                    if (isWebLayout)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(color: colorScheme.outlineVariant),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'or',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: colorScheme.outlineVariant),
                            ),
                          ],
                        ),
                      ),

                    // ── Continue with Google ──────────────────────────────────
                    OutlinedButton.icon(
                      onPressed: authState.isLoading
                          ? null
                          : () => ref
                                .read(authControllerProvider.notifier)
                                .signInWithGoogle(),
                      icon: Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        height: 20,
                        width: 20,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.g_mobiledata,
                          size: 24,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        foregroundColor: colorScheme.onSurface,
                        side: BorderSide(color: colorScheme.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Continue as Guest ─────────────────────────────────────
                    TextButton(
                      onPressed: authState.isLoading
                          ? null
                          : () async {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .signInAsGuest();
                              if (context.mounted &&
                                  !ref.read(authControllerProvider).hasError) {
                                context.go('/community');
                              }
                            },
                      child: Text(
                        'Continue as Guest',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── Footer links ──────────────────────────────────────────
                    TextButton(
                      onPressed: () => context.go('/register'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: "Don't have an account? ",
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          children: [
                            TextSpan(
                              text: 'Register',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: isWebLayout ? 8 : 24),
                  ],
                ),
              ),
            );

            if (!isWebLayout) return formShell;
            final showHeroPanel = constraints.maxWidth >= 1024;

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
                        if (showHeroPanel)
                          Expanded(
                            flex: 11,
                            child: _WebLoginHero(colorScheme: colorScheme),
                          ),
                        Expanded(
                          flex: 10,
                          child: Container(
                            color: colorScheme.surface,
                            padding: const EdgeInsets.fromLTRB(30, 26, 30, 22),
                            child: formShell,
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
}

class _WebLoginHero extends StatelessWidget {
  const _WebLoginHero({required this.colorScheme});

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
            'Sign in to access community tools and your care network.',
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