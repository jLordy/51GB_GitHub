import 'dart:convert';

import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:dio/dio.dart';

class UserProfileRepository {
  final ApiClient _apiClient;

  UserProfileRepository(this._apiClient);

  Future<UserModel> fetchCurrentUser() async {
    final response = await _apiClient.get('/api/me');

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Unable to fetch user profile',
      );
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return UserModel.fromJson(data);
    }

    if (data is String) {
      final parsed = jsonDecode(data);
      if (parsed is Map<String, dynamic>) {
        return UserModel.fromJson(parsed);
      }
    }

    throw const FormatException('Unexpected /api/me response format');
  }

  Future<List<UserModel>> fetchAllUsers() async {
    Response<dynamic> response;
    try {
      response = await _apiClient.get('/api/users');
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) {
        rethrow;
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
      response = await _apiClient.get('/api/users');
    }

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Unable to fetch users list',
      );
    }

    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => UserModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    if (data is String) {
      final parsed = jsonDecode(data);
      if (parsed is List) {
        return parsed
            .whereType<Map>()
            .map((item) => UserModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    }

    throw const FormatException('Unexpected /api/users response format');
  }

  Future<void> updateUserRole({
    required String uid,
    required String role,
  }) async {
    final response = await _apiClient.put(
      '/api/users/$uid/role',
      body: {'role': role},
    );

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Unable to update user role',
      );
    }
  }

  Future<void> toggleUserStatus({
    required String uid,
    required bool disabled,
  }) async {
    final response = await _apiClient.patch(
      '/api/users/$uid/status',
      body: {'disabled': disabled},
    );

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Unable to update user status',
      );
    }
  }

  Future<void> deleteUser({required String uid}) async {
    final response = await _apiClient.delete('/api/users/$uid');

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Unable to delete user',
      );
    }
  }

  Future<void> deleteOwnAccount() async {
    final response = await _apiClient.delete('/api/me');

    if (response.statusCode != 204) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Unable to delete account',
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _apiClient.post(
      '/api/me/password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );

    if (response.statusCode != 204) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Unable to change password',
      );
    }
  }

  Future<void> updateAccountSettings({
    bool? isPrivate,
    bool? notificationsEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (isPrivate != null) body['is_private'] = isPrivate;
    if (notificationsEnabled != null) {
      body['notifications_enabled'] = notificationsEnabled;
    }
    if (body.isEmpty) return;

    final response = await _apiClient.patch('/api/users/me', body: body);

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Unable to update account settings',
      );
    }
  }

  /// Called once after Google sign-in when role == "pending".
  /// Returns the updated [UserModel] with the chosen role.
  Future<UserModel> selectRole(String role) async {
    final response = await _apiClient.post(
      '/api/me/role',
      body: {'role': role},
    );

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Failed to set role',
      );
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return UserModel.fromJson(data);
    }

    if (data is String) {
      final parsed = jsonDecode(data);
      if (parsed is Map<String, dynamic>) {
        return UserModel.fromJson(parsed);
      }
    }

    throw const FormatException('Unexpected /api/me/role response format');
  }
}