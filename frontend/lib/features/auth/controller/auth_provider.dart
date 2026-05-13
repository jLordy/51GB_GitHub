import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/auth/data/user_profile_repository.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(firebaseAuthProvider),
    GoogleSignIn.instance,
    ref.read(backendBaseUrlProvider),
    ref.read(backendFunctionKeyProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(authRepositoryProvider).authStateChanges;
});

final backendBaseUrlProvider = Provider<String>((ref) {
  const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  if (configuredBaseUrl != '') {
    return configuredBaseUrl;
  }

  // Dev-only overrides
  if (kDebugMode) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  // Production default — used by all release builds
  return 'https://agapayapp.online/';
});

final backendFunctionKeyProvider = Provider<String?>((ref) {
  final key = const String.fromEnvironment('AZURE_FUNCTIONS_KEY');
  return key.trim().isEmpty ? null : key;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ref.read(backendBaseUrlProvider),
    firebaseAuth: ref.read(firebaseAuthProvider),
    functionKey: ref.read(backendFunctionKeyProvider),
  );
});

final backendSessionRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(ref.read(apiClientProvider));
});

final currentUserProvider = StateProvider<UserModel?>((ref) => null);

final forceAuthRedirectAfterSignOutProvider = StateProvider<bool>(
  (ref) => false,
);

final usersListProvider = FutureProvider<List<UserModel>>((ref) async {
  final repository = ref.read(backendSessionRepositoryProvider);
  return repository.fetchAllUsers();
});

final authSessionSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) async {
    final authUser = next.asData?.value;

    if (authUser == null) {
      ref.read(currentUserProvider.notifier).state = null;
      ref.invalidate(usersListProvider);
      return;
    }

    // Skip redundant fetches when userChanges() re-emits for the same user
    // (e.g. token refresh, displayName/photoURL update, reload()).
    // Only fetch the backend profile on a genuine sign-in (uid transition).
    final prevUser = previous?.asData?.value;
    if (prevUser != null && prevUser.uid == authUser.uid) return;

    // Guest (anonymous) users have no backend profile — skip the fetch so
    // they are never treated as "pending" and redirected to role-selection.
    if (authUser.isAnonymous) return;

    try {
      final profile = await ref
          .read(backendSessionRepositoryProvider)
          .fetchCurrentUser();

      // Guard: if the user explicitly selected a role while this fetch was
      // in-flight (race condition with userChanges() firing multiple times
      // during sign-in), do NOT overwrite the resolved role back to "pending".
      final existing = ref.read(currentUserProvider);
      final isStaleResult =
          existing != null &&
          existing.uid == profile.uid &&
          existing.role.toLowerCase() != 'pending' &&
          profile.role.toLowerCase() == 'pending';
      if (isStaleResult) return;

      ref.read(currentUserProvider.notifier).state = profile;

      // Persist FCM token to Firestore so other users can notify this device.
      if (!kIsWeb) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(authUser.uid)
              .update({'fcm_token': token});
        }
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(authUser.uid)
              .update({'fcm_token': newToken});
        });
      }
    } catch (_) {
      // Keep previous state if backend profile fetch fails transiently.
    }
  });
});