import 'dart:async';

import 'package:frontend/core/router/app_router.dart';

import 'package:frontend/firebase_options.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/theme/palette.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

const _webClientId =
    '1066022819611-ua41rka1j68k30tq5824v26n54rs4gv0.apps.googleusercontent.com';

/// Top-level FCM background handler (required to be a top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // App may not be initialised yet when woken from terminated state.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await GoogleSignIn.instance.initialize(
    clientId: kIsWeb ? _webClientId : null,
    serverClientId: kIsWeb ? null : _webClientId,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authSessionSyncProvider);
    final router = ref.watch(routerProvider);
    final theme = ref.watch(themeNotifierProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Agapay',
      theme: theme,
      routerConfig: router,
    );
  }
}