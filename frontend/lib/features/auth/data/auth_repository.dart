import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:frontend/features/auth/data/auth_failure.dart';
import 'package:frontend/features/auth/data/register_request.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final String? _functionKey;
  final Dio _publicDio;
  Future<void>? _ongoingSignOut;

  AuthRepository(
    this._firebaseAuth,
    this._googleSignIn,
    String backendBaseUrl,
    this._functionKey,
  ) : _publicDio = Dio(
        BaseOptions(
          baseUrl: backendBaseUrl,
          contentType: Headers.jsonContentType,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> _waitForOngoingSignOut() async {
    final inFlightSignOut = _ongoingSignOut;
    if (inFlightSignOut != null) {
      await inFlightSignOut;
    }
  }

  Future<User?> signInWithGoogle() async {
    await _waitForOngoingSignOut();

    try {
      if (kIsWeb) {
        // Web: Firebase opens a Google popup directly — no google_sign_in needed
        final userCredential = await _firebaseAuth.signInWithPopup(
          GoogleAuthProvider(),
        );
        return userCredential.user;
      } else {
        // Mobile: use google_sign_in package
        final GoogleSignInAccount googleUser = await _googleSignIn
            .authenticate();
        final googleAuth = googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        final userCredential = await _firebaseAuth.signInWithCredential(
          credential,
        );
        return userCredential.user;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    _ongoingSignOut ??= _performSignOut();
    try {
      await _ongoingSignOut;
    } finally {
      _ongoingSignOut = null;
    }
  }

  Future<void> _performSignOut() async {
    if (!kIsWeb) {
      try {
        // Disconnect revokes Google access on device when available.
        await _googleSignIn.disconnect();
      } catch (_) {
        // Ignore disconnect failures and continue with sign-out.
      }

      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google signOut failed: $e');
      }
    }

    // Always clear Firebase session, even if Google sign-out had issues.
    await _firebaseAuth.signOut();
  }

  Future<void> signInAnonymously() async {
    await _firebaseAuth.signInAnonymously();
  }

  // Helper to get the token for your Python Backend
  Future<String?> getUserToken() async {
    // forceRefresh: true ensures we handle token expiration automatically
    return await _firebaseAuth.currentUser?.getIdToken(true);
  }

  // Register via backend so Firebase Auth + Firestore profile are created consistently.
  Future<void> registerWithBackend(RegisterRequest request) async {
    final body = request.toJson();
    final headers = <String, String>{'Content-Type': 'application/json'};
    final key = _functionKey?.trim();
    if (key != null && key.isNotEmpty) {
      headers['x-functions-key'] = key;
    }

    try {
      final response = await _publicDio.post(
        '/api/register',
        data: body,
        options: Options(headers: headers),
      );
      if ((response.statusCode ?? 500) >= 300) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Rethrow for status codes that _friendlyAuthError maps explicitly,
      // so the HTTP status is preserved for the UI layer.
      if (status == 409 ||
          status == 404 ||
          status == 429 ||
          (status != null && status >= 500)) {
        rethrow;
      }

      final data = e.response?.data;
      final detail = data is Map<String, dynamic> ? data['detail'] : null;

      if (detail is String && detail.trim().isNotEmpty) {
        throw Exception(detail);
      }

      if (detail is List) {
        final messages = <String>[];
        for (final item in detail) {
          if (item is Map<String, dynamic>) {
            final loc = item['loc'];
            final msg = item['msg'];
            if (msg is String) {
              if (loc is List && loc.isNotEmpty) {
                messages.add('${loc.join('.')}: $msg');
              } else {
                messages.add(msg);
              }
            }
          }
        }

        if (messages.isNotEmpty) {
          throw Exception(messages.join('\n'));
        }
      }

      rethrow;
    }
  }

  /// Signs in an existing user with email and password.
  /// Throws [AuthFailure] for known Firebase error codes.
  Future<User?> loginWithEmail(String email, String password) async {
    await _waitForOngoingSignOut();

    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw switch (e.code) {
        'user-not-found' => AuthFailure(AuthFailureCode.userNotFound),
        'wrong-password' => AuthFailure(AuthFailureCode.wrongPassword),
        _ => AuthFailure(AuthFailureCode.unknown, message: e.message),
      };
    }
  }

  /// Creates a new user account with email and password.
  /// Throws [AuthFailure] for known Firebase error codes.
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw switch (e.code) {
        'email-already-in-use' => AuthFailure(
          AuthFailureCode.emailAlreadyInUse,
        ),
        _ => AuthFailure(AuthFailureCode.unknown, message: e.message),
      };
    }
  }

  /// Deletes the currently signed-in user's Firebase Auth account.
  /// The caller must re-authenticate before calling this if the last sign-in
  /// was too long ago ([FirebaseAuthException] with code 'requires-recent-login').
  Future<void> deleteCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    await user.delete();
  }

  // ─────────────────────── OTP password reset ───────────────────────────────

  /// Requests a 6-digit OTP to be sent to [email].
  Future<void> sendPasswordResetOtp(String email) async {
    try {
      await _publicDio.post(
        '/api/auth/forgot-password',
        data: {'email': email},
        options: Options(extra: {'requiresAuth': false}),
      );
    } on DioException catch (e) {
      _throwFriendlyDioError(e);
    }
  }

  /// Verifies the [otp] for [email] without resetting the password.
  Future<void> verifyPasswordResetOtp(String email, String otp) async {
    try {
      await _publicDio.post(
        '/api/auth/verify-otp',
        data: {'email': email, 'otp': otp},
        options: Options(extra: {'requiresAuth': false}),
      );
    } on DioException catch (e) {
      _throwFriendlyDioError(e);
    }
  }

  /// Verifies the [otp] and sets [newPassword] for [email].
  Future<void> resetPasswordWithOtp(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      await _publicDio.post(
        '/api/auth/reset-password',
        data: {'email': email, 'otp': otp, 'new_password': newPassword},
        options: Options(extra: {'requiresAuth': false}),
      );
    } on DioException catch (e) {
      _throwFriendlyDioError(e);
    }
  }

  /// Sends a 6-digit registration verification code to [email].
  Future<void> sendRegistrationOtp(String email) async {
    try {
      await _publicDio.post(
        '/api/auth/register/send-otp',
        data: {'email': email},
        options: Options(extra: {'requiresAuth': false}),
      );
    } on DioException catch (e) {
      _throwFriendlyDioError(e);
    }
  }

  /// Verifies the registration OTP for [email].
  Future<void> verifyRegistrationOtp(String email, String otp) async {
    try {
      await _publicDio.post(
        '/api/auth/register/verify-otp',
        data: {'email': email, 'otp': otp},
        options: Options(extra: {'requiresAuth': false}),
      );
    } on DioException catch (e) {
      _throwFriendlyDioError(e);
    }
  }

  void _throwFriendlyDioError(DioException e) {
    final data = e.response?.data;
    final detail = data is Map<String, dynamic> ? data['detail'] : null;
    if (detail is String && detail.trim().isNotEmpty) {
      throw Exception(detail);
    }
    throw Exception('Something went wrong. Please try again.');
  }
}