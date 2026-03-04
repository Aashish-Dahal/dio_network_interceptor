import 'package:dio/dio.dart';
import 'package:dio_network_interceptor/dio_network_interceptor.dart';
import 'package:flutter/material.dart';

final dio = Dio();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return NetworkObserver(
      navigatorKey: navigatorKey,

      // pageBuilder: (context) => Scaffold(
      //   body: const Center(
      //     child: Padding(
      //       padding: EdgeInsets.all(16.0),
      //       child: Column(
      //         mainAxisSize: MainAxisSize.min,
      //         children: [
      //           Icon(Icons.wifi_off, color: Colors.red, size: 48),
      //           SizedBox(height: 20),
      //           Text(
      //             'You are offline. Please check your connection.',
      //             textAlign: .center,
      //             style: TextStyle(fontSize: 20, color: Colors.red),
      //           ),
      //         ],
      //       ),
      //     ),
      //   ),
      // ),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Network Interceptor Demo',
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _result = 'Press the button to fetch data';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupDio();
  }

  void _setupDio() {
    dio.interceptors.add(
      NetworkInterceptor(
        checkBeforeRequest: true,

        // ✅ Receives RequestOptions — matches updated signature
        onNoInternet: (requestOptions) async {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📵 No internet connection!'),
              backgroundColor: Colors.red,
            ),
          );
        },

        onNetworkError: (exception) {
          debugPrint('[NetworkError] ${exception.type}: ${exception.message}');
          // e.g. FirebaseCrashlytics.instance.recordError(exception, null);
        },
      ),
    );
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _result = 'Fetching...';
    });

    try {
      final response = await dio.get(
        'https://jsonplaceholder.typicode.com/posts/1',
      );

      setState(() => _result = response.data.toString());
    } on DioException catch (e) {
      if (e.error is NetworkException) {
        final networkError = e.error as NetworkException;

        switch (networkError.type) {
          case NetworkErrorType.noInternet:
            setState(() => _result = '📵 No internet connection');
            break;
          case NetworkErrorType.timeout:
            setState(() => _result = '⏱ Request timed out');
            break;
          case NetworkErrorType.serverError:
            setState(
              () => _result = '🚨 Server error: ${networkError.statusCode}',
            );
            break;
          case NetworkErrorType.cancelled:
            setState(() => _result = '🚫 Request cancelled');
            break;
          default:
            setState(
              () => _result = '❓ Unknown error: ${networkError.message}',
            );
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Interceptor Demo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _result,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _fetchData,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Fetch Data'),
            ),
          ],
        ),
      ),
    );
  }
}
