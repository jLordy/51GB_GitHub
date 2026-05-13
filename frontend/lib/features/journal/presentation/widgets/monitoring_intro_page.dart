import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The landing / intro scaffold shown before the user starts a monitoring
/// session. Displays the Nurse Aga mascot, a welcome message, an optional
/// error banner, and a "start" arrow button.
class MonitoringIntroPage extends StatelessWidget {
  const MonitoringIntroPage({
    super.key,
    required this.onStart,
    this.errorMsg,
    this.patientName,
  });

  final VoidCallback onStart;
  final String? errorMsg;

  /// When non-null, the screen is in caregiver mode and questions target this
  /// patient. The intro text switches to 2nd-person ("how [name] is feeling").
  final String? patientName;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 26,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () => context.go('/journal'),
                ),
              ),
              const Spacer(),
              Text(
                'Hi, I am Nurse Aga!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 36),
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Image.asset(
                    'assets/images/agapay_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                patientName != null
                    ? "Tell us how $patientName is feeling right now."
                    : "Tell us how you're feeling right now.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.4,
                  color: scheme.onSurface,
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMsg!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      minimumSize: const Size(56, 56),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      elevation: 0,
                    ),
                    onPressed: onStart,
                    child: const Icon(Icons.arrow_forward_rounded, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
