import 'dart:async';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'connectivity_service.dart';

/// A root-level widget that globally monitors internet connectivity
/// and shows offline UI (dialog or full page) when the device goes offline.
///
/// Place this above [MaterialApp] and pass the same [navigatorKey]:
///
/// ```dart
/// final navigatorKey = GlobalKey<NavigatorState>();
///
/// NetworkObserver(
///   navigatorKey: navigatorKey,
///   // Option A — default dialog:    nothing extra needed
///   // Option B — custom dialog:     dialogBuilder: (ctx) => YourDialog()
///   // Option C — full offline page: pageBuilder: (ctx) => YourOfflinePage()
///   child: MaterialApp(navigatorKey: navigatorKey, ...),
/// )
/// ```
class NetworkObserver extends StatefulWidget {
  /// The app widget — typically [MaterialApp].
  final Widget child;

  /// Must match the [navigatorKey] passed to [MaterialApp].
  /// Used to access context and push/pop offline UI safely.
  final GlobalKey<NavigatorState> navigatorKey;

  /// Custom dialog shown when offline.
  /// Falls back to [_DefaultNoInternetDialog] if null.
  /// Ignored if [pageBuilder] is set — page takes priority.
  final WidgetBuilder? dialogBuilder;

  /// Full-page offline UI pushed onto the navigator stack when offline.
  /// Takes priority over [dialogBuilder] when set.
  final WidgetBuilder? pageBuilder;

  /// Optional custom [ConnectivityService] — useful for testing.
  final ConnectivityService? connectivityService;

  const NetworkObserver({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.dialogBuilder,
    this.pageBuilder,
    this.connectivityService,
  });

  @override
  State<NetworkObserver> createState() => _NetworkObserverState();
}

class _NetworkObserverState extends State<NetworkObserver> {
  late final ConnectivityService _connectivityService;

  /// Tracks current [InternetStatus] — drives [ValueListenableBuilder]
  /// without triggering a full widget tree rebuild.
  late final ValueNotifier<InternetStatus> _statusNotifier;
  StreamSubscription<InternetStatus>? _subscription;

  /// Guards against showing duplicate dialogs or pages.
  bool _isDialogShowing = false;
  bool _isPageShowing = false;

  // ─── Context Guard ────────────────────────────────────────────────────────

  /// Returns a valid, mounted [BuildContext] from [navigatorKey] or null.
  /// Logs a debug message if context is unavailable — no-ops gracefully.
  BuildContext? get _context {
    final context = widget.navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[NetworkObserver] context is null — skipping');
      return null;
    }
    if (!context.mounted) {
      debugPrint('[NetworkObserver] context is not mounted — skipping');
      return null;
    }
    return context;
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _connectivityService = widget.connectivityService ?? ConnectivityService();
    _statusNotifier = ValueNotifier<InternetStatus>(InternetStatus.connected);
    _checkInitialStatus();
    _startListening();
  }

  /// One-time real internet check on startup.
  /// Shows offline UI immediately if device is already offline.
  Future<void> _checkInitialStatus() async {
    final hasInternet = await _connectivityService.hasInternetAccess();
    if (!mounted) return;
    final status = hasInternet
        ? InternetStatus.connected
        : InternetStatus.disconnected;
    if (_statusNotifier.value != status) {
      _statusNotifier.value = status;
      if (!hasInternet) _showOfflineUI();
    }
  }

  /// Subscribes to [ConnectivityService.onStatusChange].
  /// Skips duplicate events — only reacts when status actually changes.
  void _startListening() {
    _subscription = _connectivityService.onStatusChange.listen((
      InternetStatus status,
    ) {
      if (!mounted || _statusNotifier.value == status) return;
      _statusNotifier.value = status;
      status == InternetStatus.disconnected
          ? _showOfflineUI()
          : _dismissOfflineUI();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _statusNotifier.dispose();
    super.dispose();
  }

  // ─── Show ─────────────────────────────────────────────────────────────────

  /// Shows [_showPage] if [pageBuilder] is set, otherwise [_showDialog].
  void _showOfflineUI() =>
      widget.pageBuilder != null ? _showPage() : _showDialog();

  /// Pushes a full-page offline UI onto the navigator stack.
  /// Uses a semi-transparent fade route so the app remains visible beneath.
  void _showPage() {
    final context = _context;
    if (context == null || _isPageShowing) return;
    _isPageShowing = true;
    widget.navigatorKey.currentState?.push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (ctx, _, _) =>
            PopScope(canPop: false, child: widget.pageBuilder!(ctx)),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Shows an offline dialog — custom [dialogBuilder] or default.
  /// [barrierDismissible] and [canPop] are both false to force user action.
  void _showDialog() {
    final context = _context;
    if (context == null || _isDialogShowing) return;
    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child:
            widget.dialogBuilder?.call(ctx) ??
            _DefaultNoInternetDialog(
              onRetry: () async {
                final hasInternet = await _connectivityService
                    .hasInternetAccess();
                if (hasInternet) _dismissOfflineUI();
              },
            ),
      ),
    );
  }

  // ─── Dismiss ──────────────────────────────────────────────────────────────

  /// Dismisses whichever offline UI is currently showing.
  void _dismissOfflineUI() =>
      widget.pageBuilder != null ? _dismissPage() : _dismissDialog();

  /// Pops the offline page from the navigator stack.
  void _dismissPage() {
    if (!_isPageShowing) return;
    _isPageShowing = false;
    if (_context == null) return;
    widget.navigatorKey.currentState?.pop();
  }

  /// Pops the offline dialog from the navigator stack.
  void _dismissDialog() {
    if (!_isDialogShowing) return;
    _isDialogShowing = false;
    if (_context == null) return;
    widget.navigatorKey.currentState?.pop();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  /// [child] is passed as the 3rd arg — never rebuilt when status changes.
  /// [builder] simply passes it through — zero widget construction overhead.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InternetStatus>(
      valueListenable: _statusNotifier,
      child: widget.child,
      builder: (context, status, child) => child!,
    );
  }
}

// ─── Default Dialog ───────────────────────────────────────────────────────────

/// Fallback offline dialog shown when [NetworkObserver.dialogBuilder] is null.
class _DefaultNoInternetDialog extends StatelessWidget {
  final VoidCallback onRetry;
  const _DefaultNoInternetDialog({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.wifi_off, color: Colors.red, size: 48),
      title: const Text('No Internet Connection'),
      content: const Text(
        'Please check your network settings and try again.',
        textAlign: TextAlign.center,
      ),
      actions: [TextButton(onPressed: onRetry, child: const Text('Retry'))],
    );
  }
}
