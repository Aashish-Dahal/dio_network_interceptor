import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Wraps [InternetConnection] to provide real internet access checks
/// via actual HTTP HEAD requests — not just network interface availability.
///
/// ```dart
/// // Default — uses package built-in URIs:
/// final service = ConnectivityService();
///
/// // Custom URIs — e.g. verify your own backend or bypass firewall:
/// final service = ConnectivityService(
///   customCheckOptions: [
///     InternetCheckOption(uri: Uri.parse('https://api.yourapp.com/health')),
///   ],
/// );
/// ```
class ConnectivityService {
  final InternetConnection _checker;

  /// If [customCheckOptions] is provided and non-empty, only those URIs
  /// are used for checks (`useDefaultOptions: false`).
  /// Otherwise falls back to the package's built-in URIs.
  ConnectivityService({List<InternetCheckOption>? customCheckOptions})
    : _checker = customCheckOptions != null && customCheckOptions.isNotEmpty
          ? InternetConnection.createInstance(
              customCheckOptions: customCheckOptions,
              useDefaultOptions: false,
            )
          : InternetConnection();

  /// Returns `true` if the device has real internet access.
  ///
  /// A device on WiFi with no internet will correctly return `false`.
  Future<bool> hasInternetAccess() => _checker.hasInternetAccess;

  /// Emits [InternetStatus.connected] or [InternetStatus.disconnected]
  /// whenever connectivity changes. Always cancel the subscription on dispose.
  Stream<InternetStatus> get onStatusChange => _checker.onStatusChange;
}
