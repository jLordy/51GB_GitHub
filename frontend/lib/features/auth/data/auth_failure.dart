enum AuthFailureCode { userNotFound, wrongPassword, emailAlreadyInUse, unknown }

class AuthFailure implements Exception {
  const AuthFailure(this.code, {this.message});

  final AuthFailureCode code;
  final String? message;

  @override
  String toString() => 'AuthFailure(code: $code, message: $message)';
}