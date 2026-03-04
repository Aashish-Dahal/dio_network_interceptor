import 'package:dio/dio.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'connectivity_service.dart';
import 'network_exception.dart';

/// Callback triggered when no internet is detected before or after a request.
/// Receives the [RequestOptions] of the failed request — use to show UI feedback.
typedef NoInternetCallback = Future<void> Function(RequestOptions options)?;

/// Callback triggered for every [NetworkException] that occurs.
/// Use for global error logging, analytics, or crash reporting.
typedef NetworkErrorCallback = void Function(NetworkException exception)?;

/// A Dio [Interceptor] that globally handles internet connectivity.
///
/// Hooks into three stages of every request:
/// - [onRequest]  — blocks requests when offline
/// - [onResponse] — catches internet loss mid-response
/// - [onError]    — maps all [DioException]s to typed [NetworkException]s
///
/// ## Setup
/// ```dart
/// dio.interceptors.add(
///   NetworkInterceptor(
///     onNoInternet: (options) async => showSnackBar('No internet'),
///     onNetworkError: (e) => FirebaseCrashlytics.instance.recordError(e, null),
///   ),
/// );
/// ```
class NetworkInterceptor extends Interceptor {
  final ConnectivityService _connectivity;

  /// Called when no internet is detected — use to show snackbar, dialog, etc.
  final NoInternetCallback onNoInternet;

  /// Called for every mapped [NetworkException] — use for logging or analytics.
  final NetworkErrorCallback onNetworkError;

  /// If `true`, checks internet connectivity before sending each request.
  /// Defaults to `true`. Set to `false` to skip the pre-flight check.
  final bool checkBeforeRequest;

  /// If `true`, verifies internet is still available when a response arrives.
  /// Catches edge cases where internet drops mid-transfer.
  /// Defaults to `true`.
  final bool checkOnResponse;

  /// Creates a [NetworkInterceptor].
  ///
  /// Provide a [connectivityService] to inject a custom instance (useful
  /// for testing). Or pass [customCheckOptions] to override the default
  /// URIs used for connectivity checks.
  NetworkInterceptor({
    ConnectivityService? connectivityService,
    List<InternetCheckOption>? customCheckOptions,
    this.onNoInternet,
    this.onNetworkError,
    this.checkBeforeRequest = true,
    this.checkOnResponse = true,
  }) : _connectivity =
           connectivityService ??
           ConnectivityService(customCheckOptions: customCheckOptions);

  // ─── onRequest ────────────────────────────────────────────────────────────

  /// Checks internet before the request is sent.
  /// Rejects immediately with [NetworkException.noInternet] if offline.
  /// If internet drops mid-send, Dio throws [DioExceptionType.connectionError]
  /// which is caught and mapped in [onError].
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!checkBeforeRequest) return handler.next(options);

    final hasInternet = await _connectivity.hasInternetAccess();
    if (!hasInternet) return _rejectNoInternet(options, handler);

    return handler.next(options);
  }

  // ─── onResponse ───────────────────────────────────────────────────────────

  /// Verifies internet is still alive when the response arrives.
  /// Handles the edge case where internet was on when the request was sent
  /// but dropped before the full response was received.
  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    if (!checkOnResponse) return handler.next(response);

    final hasInternet = await _connectivity.hasInternetAccess();
    if (!hasInternet) {
      final exception = NetworkException.noInternet();
      await onNoInternet?.call(response.requestOptions);
      onNetworkError?.call(exception);

      // Partial response is preserved for debugging purposes
      return handler.reject(
        _buildDioException(
          options: response.requestOptions,
          response: response,
          exception: exception,
          type: DioExceptionType.connectionError,
        ),
      );
    }

    return handler.next(response);
  }

  // ─── onError ──────────────────────────────────────────────────────────────

  /// Maps all [DioException]s to typed [NetworkException]s.
  ///
  /// Handles all failure scenarios:
  /// - Rejected from [onRequest] or [onResponse]
  /// - Internet dropped mid-send or mid-receive
  /// - Timeout, server errors, cancellations
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is NetworkException) return handler.next(err);

    final exception = _mapDioException(err);
    onNetworkError?.call(exception);

    handler.next(
      _buildDioException(
        options: err.requestOptions,
        response: err.response,
        exception: exception,
        type: err.type,
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Fires [onNoInternet] and [onNetworkError] callbacks then rejects
  /// the request with a [NetworkException.noInternet] wrapped [DioException].
  Future<void> _rejectNoInternet(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final exception = NetworkException.noInternet();
    await onNoInternet?.call(options);
    onNetworkError?.call(exception);

    return handler.reject(
      _buildDioException(
        options: options,
        exception: exception,
        type: DioExceptionType.connectionError,
      ),
      true, // forwards to onError
    );
  }

  /// Maps a [DioException] to the appropriate [NetworkException] type.
  NetworkException _mapDioException(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return NetworkException.timeout();
      case DioExceptionType.badResponse:
        return NetworkException.serverError(err.response?.statusCode ?? 0);
      case DioExceptionType.cancel:
        return NetworkException.cancelled();
      case DioExceptionType.connectionError:
        return NetworkException.noInternet();
      default:
        return NetworkException.unknown(err.message);
    }
  }

  /// Wraps a [NetworkException] into a [DioException] for Dio to propagate.
  /// Preserves the original [response] when available for debugging.
  DioException _buildDioException({
    required RequestOptions options,
    required NetworkException exception,
    required DioExceptionType type,
    Response? response,
  }) {
    return DioException(
      requestOptions: options,
      response: response,
      error: exception,
      type: type,
      message: exception.message,
    );
  }
}
