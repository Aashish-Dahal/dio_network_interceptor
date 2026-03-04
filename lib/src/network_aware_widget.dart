import 'dart:async';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'connectivity_service.dart';

/// A widget that swaps its content based on internet connectivity.
///
/// Shows [child] when online, [offlineBuilder] (or default offline UI)
/// when offline. Automatically recovers when internet is restored.
///
/// ```dart
/// NetworkAwareWidget(
///   // optional — custom offline UI:
///   offlineBuilder: (context) => YourOfflineWidget(),
///   child: YourPageContent(),
/// )
/// ```
class NetworkAwareWidget extends StatefulWidget {
  /// Shown when the device is online.
  final Widget child;

  /// Shown when offline. Falls back to [_DefaultOfflineWidget] if null.
  final WidgetBuilder? offlineBuilder;

  /// Optional custom [ConnectivityService] — useful for testing.
  final ConnectivityService? connectivityService;

  const NetworkAwareWidget({
    super.key,
    required this.child,
    this.offlineBuilder,
    this.connectivityService,
  });

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  late final ConnectivityService _connectivityService;

  /// Holds online state — avoids setState, only rebuilds [ValueListenableBuilder].
  late final ValueNotifier<bool> _isOnline;
  StreamSubscription<InternetStatus>? _subscription;

  @override
  void initState() {
    super.initState();
    _connectivityService = widget.connectivityService ?? ConnectivityService();
    _isOnline = ValueNotifier<bool>(true); // optimistic default
    _checkInitialStatus();
    _startListening();
  }

  /// Performs a one-time real internet check on widget mount.
  Future<void> _checkInitialStatus() async {
    final hasInternet = await _connectivityService.hasInternetAccess();
    if (mounted) _isOnline.value = hasInternet;
  }

  /// Listens to connectivity changes and updates [_isOnline].
  /// Skips update if value hasn't changed to avoid redundant rebuilds.
  void _startListening() {
    _subscription = _connectivityService.onStatusChange.listen((
      InternetStatus status,
    ) {
      if (!mounted) return;
      final online = status == InternetStatus.connected;
      if (_isOnline.value != online) _isOnline.value = online;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _isOnline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isOnline,
      builder: (context, isOnline, _) {
        if (isOnline) return widget.child;

        return widget.offlineBuilder?.call(context) ??
            _DefaultOfflineWidget(
              onRetry: () async {
                final hasInternet = await _connectivityService
                    .hasInternetAccess();
                if (mounted) _isOnline.value = hasInternet;
              },
            );
      },
    );
  }
}

/// Default offline UI shown when [NetworkAwareWidget.offlineBuilder] is null.
class _DefaultOfflineWidget extends StatelessWidget {
  final VoidCallback onRetry;
  const _DefaultOfflineWidget({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'You are Offline',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your internet connection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
