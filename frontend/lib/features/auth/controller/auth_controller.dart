import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/auth/data/user_profile_repository.dart';
import 'package:frontend/features/auth/data/register_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// 1. The Provider Definition
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      return AuthController(
        ref,
        ref.read(authRepositoryProvider),
        ref.read(backendSessionRepositoryProvider),
      );
    });

// 2. The Controller Class
class AuthController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final AuthRepository _authRepository;
  final UserProfileRepository _userProfileRepository;

  AuthController(this._ref, this._authRepository, this._userProfileRepository)
    : super(const AsyncValue.data(null));

  Future<void> _loadBackendProfile() async {
    try {
      final profile = await _userProfileRepository.fetchCurrentUser();
      _ref.read(currentUserProvider.notifier).state = profile;
      return;
    } on DioException catch (e) {
      // Right after sign-in, web auth state/token propagation can lag briefly.
      if (e.response?.statusCode != 401) rethrow;
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _authRepository.getUserToken();
    final profile = await _userProfileRepository.fetchCurrentUser();
    _ref.read(currentUserProvider.notifier).state = profile;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.loginWithEmail(email, password);
      await _loadBackendProfile();
      _ref.read(forceAuthRedirectAfterSignOutProvider.notifier).state = false;
    });
  }

  Future<void> register(RegisterRequest request) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.registerWithBackend(request);
      await _authRepository.loginWithEmail(request.email, request.password);
      await _loadBackendProfile();
      _ref.read(forceAuthRedirectAfterSignOutProvider.notifier).state = false;
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signInWithGoogle();
      await _loadBackendProfile();
      _ref.read(forceAuthRedirectAfterSignOutProvider.notifier).state = false;
    });
  }

  Future<void> signInAsGuest() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signInAnonymously();
      _ref.read(forceAuthRedirectAfterSignOutProvider.notifier).state = false;
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    _ref.read(forceAuthRedirectAfterSignOutProvider.notifier).state = true;
    state = await AsyncValue.guard(() async {
      await _authRepository.signOut();
      _ref.read(currentUserProvider.notifier).state = null;
      _ref.invalidate(usersListProvider);
    });
  }

  /// Deletes the current user's backend profile and Firebase Auth account.
  /// Re-authentication must be performed by the caller before invoking this.
  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    _ref.read(forceAuthRedirectAfterSignOutProvider.notifier).state = true;
    state = await AsyncValue.guard(() async {
      await _userProfileRepository.deleteOwnAccount();
      await _authRepository.deleteCurrentUser();
      _ref.read(currentUserProvider.notifier).state = null;
      _ref.invalidate(usersListProvider);
    });
  }
}

// ─────────────────────── Password reset (OTP) controller ─────────────────────

final passwordResetControllerProvider =
    StateNotifierProvider.autoDispose<
      PasswordResetController,
      AsyncValue<void>
    >((ref) => PasswordResetController(ref.read(authRepositoryProvider)));

class PasswordResetController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repo;

  PasswordResetController(this._repo) : super(const AsyncValue.data(null));

  Future<bool> sendOtp(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.sendPasswordResetOtp(email));
    return !state.hasError;
  }

  Future<bool> verifyOtp(String email, String otp) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.verifyPasswordResetOtp(email, otp),
    );
    return !state.hasError;
  }

  Future<bool> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.resetPasswordWithOtp(email, otp, newPassword),
    );
    return !state.hasError;
  }
}

final registrationOtpControllerProvider =
    StateNotifierProvider<RegistrationOtpController, AsyncValue<void>>(
      (ref) => RegistrationOtpController(ref.read(authRepositoryProvider)),
    );

class RegistrationOtpController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repo;

  RegistrationOtpController(this._repo) : super(const AsyncValue.data(null));

  Future<bool> sendOtp(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.sendRegistrationOtp(email));
    return !state.hasError;
  }

  Future<bool> verifyOtp(String email, String otp) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.verifyRegistrationOtp(email, otp),
    );
    return !state.hasError;
  }
}