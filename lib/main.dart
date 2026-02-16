import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';



void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KK Tours',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => WebViewScreen()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.travel_explore, size: 100, color: Colors.white),
                SizedBox(height: 20),
                Text(
                  'KK Tours',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Your Travel Partner',
                  style: TextStyle(fontSize: 16, color: Colors.white70, letterSpacing: 1),
                ),
                SizedBox(height: 40),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _didRetry = false;

  final String homeUrl = 'https://kktoursrls.com/pantheon/';

  static const Map<String, String> _noCacheHeaders = {
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
    'Expires': '0',
  };

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36',
      )
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() { _isLoading = true; _hasError = false; });
          },
          onPageFinished: (_) {
            if (mounted) setState(() {
              _isLoading = false;
              _hasError = false;
              _didRetry = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error [${error.errorType}]: ${error.description}');

            // Ignore sub-resource errors (images, fonts, ads)
            if (error.isForMainFrame != true) return;

            // Retry once with no-cache headers on ERR_CACHE_MISS
            if (!_didRetry &&
                error.errorType == WebResourceErrorType.unknown &&
                error.description.contains('ERR_CACHE_MISS')) {
              _didRetry = true;
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted) {
                  _controller.loadRequest(
                    Uri.parse(homeUrl),
                    headers: _noCacheHeaders,
                  );
                }
              });
              return;
            }

            if (mounted) setState(() { _isLoading = false; _hasError = true; });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://kktoursrls.com')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(homeUrl), headers: _noCacheHeaders);
  }

  void _refreshPage() {
    setState(() { _hasError = false; _didRetry = false; });
    _controller.loadRequest(Uri.parse(homeUrl), headers: _noCacheHeaders);
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pantheon Audio Tours'),
          backgroundColor: const Color(0xFF1565C0),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshPage),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading && !_hasError)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
                ),
              ),
            if (_hasError)
              Container(
                color: Colors.white,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 72, color: Color(0xFF1565C0)),
                        const SizedBox(height: 20),
                        const Text(
                          'Connection Failed',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Please check your internet connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          onPressed: _refreshPage,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'home',
              mini: true,
              backgroundColor: const Color(0xFF1565C0),
              child: const Icon(Icons.home),
              onPressed: _refreshPage,
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'forward',
              mini: true,
              backgroundColor: const Color(0xFF1565C0),
              child: const Icon(Icons.arrow_forward),
              onPressed: () async {
                if (await _controller.canGoForward()) _controller.goForward();
              },
            ),
          ],
        ),
      ),
    );
  }
}