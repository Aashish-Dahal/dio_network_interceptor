/// Categorizes the type of network failure that occurred.
///
/// ```dart
/// switch (exception.type) {
///   case NetworkErrorType.noInternet: // show offline UI
///   case NetworkErrorType.timeout:    // show retry button
///   case NetworkErrorType.serverError: // use exception.statusCode
///   case NetworkErrorType.cancelled:  // silently ignore
///   case NetworkErrorType.unknown:    // show generic error
/// }
/// ```
enum NetworkErrorType {
  /// No active internet connection.
  noInternet,

  /// Connect, send, or receive timeout exceeded.
  timeout,

  /// Server returned a non-2xx status code.
  serverError,

  /// Request was cancelled via [CancelToken].
  cancelled,

  /// Unrecognized or unexpected error.
  unknown,
}

/// Typed exception wrapping all network errors from [NetworkInterceptor].
///
/// ```dart
/// } on DioException catch (e) {
///   if (e.error is NetworkException) {
///     final error = e.error as NetworkException;
///     // use error.type, error.message, error.statusCode
///   }
/// }
/// ```
class NetworkException implements Exception {
  /// Category of the network failure.
  final NetworkErrorType type;

  /// Human-readable error description. Safe to display or log.
  final String message;

  /// HTTP status code — only set when [type] is [NetworkErrorType.serverError].
  final int? statusCode;

  const NetworkException({
    required this.type,
    required this.message,
    this.statusCode,
  });

  /// No internet connection detected.
  factory NetworkException.noInternet() => const NetworkException(
    type: NetworkErrorType.noInternet,
    message: 'No internet connection. Please check your network.',
  );

  /// Request timed out (connect, send, or receive).
  factory NetworkException.timeout() => const NetworkException(
    type: NetworkErrorType.timeout,
    message: 'The request timed out. Please try again.',
  );

  /// Server returned a non-2xx response.
  /// Use [statusCode] to handle specific codes (401, 404, 500, etc.)
  factory NetworkException.serverError(int statusCode) => NetworkException(
    type: NetworkErrorType.serverError,
    message: 'Server responded with an error.',
    statusCode: statusCode,
  );

  /// Request was explicitly cancelled.
  factory NetworkException.cancelled() => const NetworkException(
    type: NetworkErrorType.cancelled,
    message: 'Request was cancelled.',
  );

  /// Unexpected or unrecognized error.
  factory NetworkException.unknown([String? msg]) => NetworkException(
    type: NetworkErrorType.unknown,
    message: msg ?? 'An unexpected error occurred.',
  );

  /// `true` if [type] is [NetworkErrorType.noInternet].
  bool get isNoInternet => type == NetworkErrorType.noInternet;

  /// `true` if [type] is [NetworkErrorType.timeout].
  bool get isTimeout => type == NetworkErrorType.timeout;

  /// `true` if [type] is [NetworkErrorType.serverError].
  bool get isServerError => type == NetworkErrorType.serverError;

  @override
  String toString() =>
      'NetworkException(type: $type, message: $message'
      '${statusCode != null ? ', statusCode: $statusCode' : ''})';
}
