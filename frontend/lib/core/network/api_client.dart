import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';  

class ApiClient {
  final String baseUrl;
  final FirebaseAuth firebaseAuth;
  final String? functionKey;
  final Dio _dio;

  ApiClient({
    required this.baseUrl,
    required this.firebaseAuth,
    this.functionKey,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               contentType: Headers.jsonContentType,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final bool requiresAuth = options.extra['requiresAuth'] != false;
            final headers = await _buildHeaders(requiresAuth: requiresAuth);
            options.headers.addAll(headers);
            handler.next(options);
          } catch (error) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: error,
                type: DioExceptionType.unknown,
              ),
            );
          }
        },
      ),
    );
  }

  Future<Map<String, String>> _buildHeaders({
    required bool requiresAuth,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    final key = functionKey?.trim();
    if (key != null && key.isNotEmpty) {
      headers['x-functions-key'] = key;
    }

    final idToken = await firebaseAuth.currentUser?.getIdToken(true);

    if (idToken == null || idToken.isEmpty) {
      if (!requiresAuth) {
        return headers;
      }

      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'No Firebase user session found for API call.',
      );
    }

    headers['Authorization'] = 'Bearer $idToken';

    return headers;
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: Options(extra: <String, dynamic>{'requiresAuth': requiresAuth}),
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    return _dio.post(
      path,
      data: body,
      queryParameters: queryParameters,
      options: Options(extra: <String, dynamic>{'requiresAuth': requiresAuth}),
    );
  }

  Future<Response<dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    return _dio.put(
      path,
      data: body,
      queryParameters: queryParameters,
      options: Options(extra: <String, dynamic>{'requiresAuth': requiresAuth}),
    );
  }

  Future<Response<dynamic>> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    return _dio.delete(
      path,
      queryParameters: queryParameters,
      options: Options(extra: <String, dynamic>{'requiresAuth': requiresAuth}),
    );
  }

  Future<Response<dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    return _dio.patch(
      path,
      data: body,
      queryParameters: queryParameters,
      options: Options(extra: <String, dynamic>{'requiresAuth': requiresAuth}),
    );
  }

  Future<Response<dynamic>> postBytes(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    return _dio.post(
      path,
      data: body,
      options: Options(
        responseType: ResponseType.bytes,
        extra: <String, dynamic>{'requiresAuth': requiresAuth},
      ),
    );
  }

  Future<Response<dynamic>> getBytes(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: Options(
        responseType: ResponseType.bytes,
        extra: <String, dynamic>{'requiresAuth': requiresAuth},
      ),
    );
  }

  Future<Response<dynamic>> postMultipart(
    String path, {
    required FormData formData,
    bool requiresAuth = true,
  }) async {
    return _dio.post(
      path,
      data: formData,
      options: Options(extra: <String, dynamic>{'requiresAuth': requiresAuth}),
    );
  }
}