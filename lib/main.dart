// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'KK Tours - Pantheon',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A3A5C)),
//         useMaterial3: true,
//       ),
//       home: const WebViewScreen(),
//     );
//   }
// }

// class WebViewScreen extends StatefulWidget {
//   const WebViewScreen({super.key});

//   @override
//   State<WebViewScreen> createState() => _WebViewScreenState();
// }

// class _WebViewScreenState extends State<WebViewScreen> {
//   late final WebViewController _controller;

//   bool _isLoading = true;
//   bool _hasError = false;
//   String _errorMessage = '';
//   int _loadingProgress = 0;
//   String _currentUrl = 'https://kktoursrls.com/pantheon/';
//   bool _canGoBack = false;
//   bool _canGoForward = false;

//   // Retry tracking
//   int _retryCount = 0;
//   static const int _maxRetries = 3;
//   Timer? _retryTimer;

//   @override
//   void initState() {
//     super.initState();
//     _initWebView();
//   }

//   void _initWebView() {
//     // ✅ KEY FIX: WebViewController with proper cache & settings
//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       // ✅ FIX 1: Set cache mode to LOAD_DEFAULT — fixes ERR_CACHE_MISS in release
//       ..setBackgroundColor(Colors.white)
//       // ✅ FIX 2: Navigation delegate handles all error types including cache miss
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onProgress: (int progress) {
//             if (mounted) {
//               setState(() {
//                 _loadingProgress = progress;
//               });
//             }
//           },

//           onPageStarted: (String url) {
//             if (mounted) {
//               setState(() {
//                 _isLoading = true;
//                 _hasError = false;
//                 _currentUrl = url;
//                 _retryCount = 0; // reset on new page start
//               });
//             }
//           },

//           onPageFinished: (String url) async {
//             // ✅ ZOOM FIX: Inject viewport meta + CSS to fully disable pinch-zoom
//             await _controller.runJavaScript('''
//               (function() {
//                 // 1) Remove any existing viewport meta tags
//                 var existingMeta = document.querySelectorAll('meta[name="viewport"]');
//                 existingMeta.forEach(function(m) { m.parentNode.removeChild(m); });

//                 // 2) Inject new viewport that disables user scaling
//                 var meta = document.createElement('meta');
//                 meta.name = 'viewport';
//                 meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no';
//                 document.head.appendChild(meta);

//                 // 3) CSS touch-action: pan-x pan-y blocks pinch-zoom gesture
//                 var style = document.createElement('style');
//                 style.innerHTML = '* { touch-action: pan-x pan-y !important; }';
//                 document.head.appendChild(style);
//               })();
//             ''');

//             if (mounted) {
//               final canGoBack = await _controller.canGoBack();
//               final canGoForward = await _controller.canGoForward();
//               setState(() {
//                 _isLoading = false;
//                 _hasError = false;
//                 _currentUrl = url;
//                 _canGoBack = canGoBack;
//                 _canGoForward = canGoForward;
//               });
//             }
//           },

//           // ✅ FIX 3: Handle WebResourceError — auto retry for cache miss
//           onWebResourceError: (WebResourceError error) {
//             debugPrint(
//               'WebView Error: ${error.description} | Code: ${error.errorCode}',
//             );

//             // ERR_CACHE_MISS = -400 on Android
//             // Only show error for main frame failures
//             if (error.isForMainFrame == true) {
//               if (_retryCount < _maxRetries) {
//                 _scheduleRetry();
//               } else {
//                 if (mounted) {
//                   setState(() {
//                     _isLoading = false;
//                     _hasError = true;
//                     _errorMessage = _friendlyError(
//                       error.description,
//                       error.errorCode,
//                     );
//                   });
//                 }
//               }
//             }
//           },

//           // ✅ FIX 4: Allow all navigation (including redirects from Nitro CDN)
//           onNavigationRequest: (NavigationRequest request) {
//             return NavigationDecision.navigate;
//           },
//         ),
//       )
//       // ✅ FIX 5: User agent — some servers block default WebView UA in release
//       ..setUserAgent(
//         'Mozilla/5.0 (Linux; Android 11; Mobile) '
//         'AppleWebKit/537.36 (KHTML, like Gecko) '
//         'Chrome/120.0.0.0 Mobile Safari/537.36',
//       );

//     // ✅ FIX 6: Disable zoom — both Android & iOS
//     _controller.enableZoom(false);

//     // Load the URL with no-cache request to bypass ERR_CACHE_MISS
//     _loadUrlWithCacheBypass(_currentUrl);
//   }

//   // ✅ FIX 7: Load URL with cache-bypass headers
//   void _loadUrlWithCacheBypass(String url) {
//     _controller.loadRequest(
//       Uri.parse(url),
//       headers: {
//         // Force fresh response — fixes ERR_CACHE_MISS caused by Nitro plugin
//         'Cache-Control': 'no-cache, no-store, must-revalidate',
//         'Pragma': 'no-cache',
//         'Expires': '0',
//         // Accept modern content
//         'Accept':
//             'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
//         'Accept-Language': 'en-US,en;q=0.5',
//         'Connection': 'keep-alive',
//         'Upgrade-Insecure-Requests': '1',
//       },
//     );
//   }

//   void _scheduleRetry() {
//     _retryTimer?.cancel();
//     _retryTimer = Timer(Duration(seconds: 2 * (_retryCount + 1)), () {
//       if (mounted) {
//         _retryCount++;
//         debugPrint('Retrying... attempt $_retryCount');
//         _loadUrlWithCacheBypass(_currentUrl);
//       }
//     });
//   }

//   String _friendlyError(String description, int? code) {
//     if (description.contains('CACHE') || code == -400) {
//       return 'Cache error occurred. The page failed to load from cache.\n\nPlease check your internet connection and try again.';
//     } else if (description.contains('NET') || description.contains('network')) {
//       return 'No internet connection.\n\nPlease check your network and try again.';
//     } else if (description.contains('timeout') || code == -8) {
//       return 'Connection timed out.\n\nThe server is taking too long to respond.';
//     } else {
//       return 'Failed to load page.\n\n$description';
//     }
//   }

//   Future<void> _reload() async {
//     setState(() {
//       _isLoading = true;
//       _hasError = false;
//       _retryCount = 0;
//     });
//     _loadUrlWithCacheBypass(_currentUrl);
//   }

//   Future<bool> _onWillPop() async {
//     if (await _controller.canGoBack()) {
//       await _controller.goBack();
//       return false;
//     }
//     return true;
//   }

//   @override
//   void dispose() {
//     _retryTimer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: !_canGoBack,
//       onPopInvoked: (didPop) async {
//         if (!didPop && await _controller.canGoBack()) {
//           await _controller.goBack();
//         }
//       },
//       child: Scaffold(
//         backgroundColor: const Color(0xFF1A3A5C),
//         appBar: _buildAppBar(),
//         body: _buildBody(),
//       ),
//     );
//   }

//   PreferredSizeWidget _buildAppBar() {
//     return AppBar(
//       backgroundColor: const Color(0xFF1A3A5C),
//       foregroundColor: Colors.white,
//       elevation: 0,
//       title: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'KK Tours',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           Text(
//             _isLoading ? 'Loading...' : 'Pantheon Audio Guide',
//             style: const TextStyle(color: Colors.white70, fontSize: 11),
//           ),
//         ],
//       ),
//       actions: [
//         // Back button
//         IconButton(
//           icon: const Icon(Icons.arrow_back_ios, size: 18),
//           onPressed: _canGoBack ? () => _controller.goBack() : null,
//           color: _canGoBack ? Colors.white : Colors.white30,
//           tooltip: 'Back',
//         ),
//         // Forward button
//         IconButton(
//           icon: const Icon(Icons.arrow_forward_ios, size: 18),
//           onPressed: _canGoForward ? () => _controller.goForward() : null,
//           color: _canGoForward ? Colors.white : Colors.white30,
//           tooltip: 'Forward',
//         ),
//         // Refresh button
//         IconButton(
//           icon: const Icon(Icons.refresh),
//           onPressed: _reload,
//           tooltip: 'Reload',
//         ),
//       ],
//       bottom: _isLoading
//           ? PreferredSize(
//               preferredSize: const Size.fromHeight(3),
//               child: LinearProgressIndicator(
//                 value: _loadingProgress < 100 ? _loadingProgress / 100.0 : null,
//                 backgroundColor: Colors.white24,
//                 valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
//                 minHeight: 3,
//               ),
//             )
//           : null,
//       systemOverlayStyle: SystemUiOverlayStyle.light,
//     );
//   }

//   Widget _buildBody() {
//     return Stack(
//       children: [
//         // ✅ WebView always present in tree (avoids reload on error recovery)
//         AnimatedOpacity(
//           opacity: _hasError ? 0.0 : 1.0,
//           duration: const Duration(milliseconds: 300),
//           child: WebViewWidget(controller: _controller),
//         ),

//         // Error overlay
//         if (_hasError) _buildErrorView(),

//         // Initial loading overlay (only before first paint)
//         if (_isLoading && _loadingProgress == 0)
//           const Center(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 CircularProgressIndicator(color: Colors.amber),
//                 SizedBox(height: 16),
//                 Text(
//                   'Loading KK Tours...',
//                   style: TextStyle(color: Colors.white70),
//                 ),
//               ],
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _buildErrorView() {
//     return Container(
//       color: const Color(0xFF1A3A5C),
//       width: double.infinity,
//       padding: const EdgeInsets.all(32),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.signal_wifi_off, size: 80, color: Colors.white38),
//           const SizedBox(height: 24),
//           const Text(
//             'Connection Error',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 22,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             _errorMessage,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               color: Colors.white70,
//               fontSize: 14,
//               height: 1.5,
//             ),
//           ),
//           const SizedBox(height: 32),

//           // Retry button
//           ElevatedButton.icon(
//             onPressed: _reload,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.amber,
//               foregroundColor: Colors.black87,
//               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             icon: const Icon(Icons.refresh),
//             label: const Text(
//               'Try Again',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ),

//           const SizedBox(height: 16),

//           // Load homepage fallback
//           TextButton(
//             onPressed: () {
//               setState(() {
//                 _currentUrl = 'https://kktoursrls.com/';
//                 _hasError = false;
//                 _isLoading = true;
//                 _retryCount = 0;
//               });
//               _loadUrlWithCacheBypass('https://kktoursrls.com/');
//             },
//             child: const Text(
//               'Go to Homepage',
//               style: TextStyle(color: Colors.amber),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

// ─────────────────────────────────────────────
//  App Root
// ─────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KK Tours - Pantheon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A3A5C)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ─────────────────────────────────────────────
//  SPLASH SCREEN
// ─────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Content appear animations
  late AnimationController _contentController;
  late Animation<double> _contentFade;
  late Animation<double> _contentScale;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _taglineFade;

  // Slide-up exit animation
  late AnimationController _slideUpController;
  late Animation<Offset> _slideUpOffset;
  late Animation<double> _slideUpFade;

  // Loading dots animation
  late AnimationController _dotsController;
  late Animation<double> _dot1;
  late Animation<double> _dot2;
  late Animation<double> _dot3;

  @override
  void initState() {
    super.initState();

    // ── 1. Content appear (800ms)
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _contentScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _contentController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // ── 2. Dots (repeating)
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _dot1 = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _dotsController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeInOut),
      ),
    );
    _dot2 = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _dotsController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeInOut),
      ),
    );
    _dot3 = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _dotsController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeInOut),
      ),
    );

    // ── 3. Slide-up exit (600ms)
    _slideUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideUpOffset =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1.0)).animate(
          CurvedAnimation(
            parent: _slideUpController,
            curve: Curves.easeInCubic,
          ),
        );
    _slideUpFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _slideUpController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _contentController.forward();

    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    await _slideUpController.forward();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => const WebViewScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _slideUpController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0D2137),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _contentController,
          _slideUpController,
          _dotsController,
        ]),
        builder: (context, _) {
          return SlideTransition(
            position: _slideUpOffset,
            child: FadeTransition(
              opacity: _slideUpFade,
              child: Container(
                width: size.width,
                height: size.height,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0D2137),
                      Color(0xFF1A3A5C),
                      Color(0xFF0F2940),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative background circles
                    _buildDecorativeCircles(size),

                    // Main content
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo / icon
                          FadeTransition(
                            opacity: _contentFade,
                            child: ScaleTransition(
                              scale: _contentScale,
                              child: _buildLogoArea(),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Company name
                          FadeTransition(
                            opacity: _contentFade,
                            child: ScaleTransition(
                              scale: _contentScale,
                              child: _buildCompanyName(),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Tagline slides up
                          SlideTransition(
                            position: _taglineSlide,
                            child: FadeTransition(
                              opacity: _taglineFade,
                              child: _buildTagline(),
                            ),
                          ),

                          const SizedBox(height: 56),

                          // Animated loading dots
                          SlideTransition(
                            position: _taglineSlide,
                            child: FadeTransition(
                              opacity: _taglineFade,
                              child: _buildLoadingDots(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom credit
                    Positioned(
                      bottom: 36,
                      left: 0,
                      right: 0,
                      child: FadeTransition(
                        opacity: _taglineFade,
                        child: const Text(
                          'Powered by KK Tours Srls  •  Rome',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDecorativeCircles(Size size) {
    return Stack(
      children: [
        Positioned(
          top: -size.width * 0.3,
          right: -size.width * 0.2,
          child: Container(
            width: size.width * 0.7,
            height: size.width * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.03),
            ),
          ),
        ),
        Positioned(
          bottom: -size.width * 0.25,
          left: -size.width * 0.15,
          child: Container(
            width: size.width * 0.6,
            height: size.width * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withOpacity(0.04),
            ),
          ),
        ),
        Positioned(
          top: size.height * 0.3,
          left: -size.width * 0.1,
          child: Container(
            width: size.width * 0.3,
            height: size.width * 0.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.02),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoArea() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.35),
            blurRadius: 32,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.temple_buddhist_rounded,
        size: 48,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCompanyName() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'KK ',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              TextSpan(
                text: 'TOURS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 60,
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: [Colors.transparent, Colors.amber, Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagline() {
    return const Text(
      'PANTHEON  •  AUDIO GUIDE',
      style: TextStyle(
        color: Colors.white54,
        fontSize: 12,
        letterSpacing: 3,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(_dot1),
        const SizedBox(width: 8),
        _buildDot(_dot2),
        const SizedBox(width: 8),
        _buildDot(_dot3),
      ],
    );
  }

  Widget _buildDot(Animation<double> anim) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.amber,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WEBVIEW SCREEN
// ─────────────────────────────────────────────
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _loadingProgress = 0;
  String _currentUrl = 'https://kktoursrls.com/pantheon/';
  bool _canGoBack = false;
  bool _canGoForward = false;

  // Smooth fade-in when WebView first renders
  late AnimationController _fadeInController;
  late Animation<double> _fadeIn;

  // Retry tracking
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _fadeInController, curve: Curves.easeIn);
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) setState(() => _loadingProgress = progress);
          },

          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
                _currentUrl = url;
                _retryCount = 0;
              });
            }
          },

          onPageFinished: (String url) async {
            // Disable zoom via viewport meta + CSS
            await _controller.runJavaScript('''
              (function() {
                var existingMeta = document.querySelectorAll('meta[name="viewport"]');
                existingMeta.forEach(function(m) { m.parentNode.removeChild(m); });
                var meta = document.createElement('meta');
                meta.name = 'viewport';
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no';
                document.head.appendChild(meta);
                var style = document.createElement('style');
                style.innerHTML = '* { touch-action: pan-x pan-y !important; }';
                document.head.appendChild(style);
              })();
            ''');

            if (mounted) {
              final canGoBack = await _controller.canGoBack();
              final canGoForward = await _controller.canGoForward();
              setState(() {
                _isLoading = false;
                _hasError = false;
                _currentUrl = url;
                _canGoBack = canGoBack;
                _canGoForward = canGoForward;
              });
              if (!_fadeInController.isCompleted) {
                _fadeInController.forward();
              }
            }
          },

          onWebResourceError: (WebResourceError error) {
            debugPrint('Error: ${error.description} | ${error.errorCode}');
            if (error.isForMainFrame == true) {
              if (_retryCount < _maxRetries) {
                _scheduleRetry();
              } else {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                    _errorMessage = _friendlyError(
                      error.description,
                      error.errorCode,
                    );
                  });
                }
              }
            }
          },

          onNavigationRequest: (NavigationRequest request) =>
              NavigationDecision.navigate,
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 11; Mobile) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..enableZoom(false);

    _loadUrlWithCacheBypass(_currentUrl);
  }

  void _loadUrlWithCacheBypass(String url) {
    _controller.loadRequest(
      Uri.parse(url),
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      },
    );
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: 2 * (_retryCount + 1)), () {
      if (mounted) {
        _retryCount++;
        _loadUrlWithCacheBypass(_currentUrl);
      }
    });
  }

  String _friendlyError(String description, int? code) {
    if (description.contains('CACHE') || code == -400) {
      return 'Cache error occurred.\n\nPlease check your internet connection and try again.';
    } else if (description.contains('NET') || description.contains('network')) {
      return 'No internet connection.\n\nPlease check your network and try again.';
    } else if (description.contains('timeout') || code == -8) {
      return 'Connection timed out.\n\nThe server is taking too long to respond.';
    }
    return 'Failed to load page.\n\n$description';
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _retryCount = 0;
    });
    _loadUrlWithCacheBypass(_currentUrl);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvoked: (didPop) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A3A5C),
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A3A5C),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KK Tours',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _isLoading ? 'Loading...' : 'Pantheon Audio Guide',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: _canGoBack ? () => _controller.goBack() : null,
          color: _canGoBack ? Colors.white : Colors.white30,
          tooltip: 'Back',
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          onPressed: _canGoForward ? () => _controller.goForward() : null,
          color: _canGoForward ? Colors.white : Colors.white30,
          tooltip: 'Forward',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _reload,
          tooltip: 'Reload',
        ),
      ],
      bottom: _isLoading
          ? PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: LinearProgressIndicator(
                value: _loadingProgress < 100 ? _loadingProgress / 100.0 : null,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 3,
              ),
            )
          : null,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        // WebView with smooth fade-in on first load
        FadeTransition(
          opacity: _fadeIn,
          child: AnimatedOpacity(
            opacity: _hasError ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: WebViewWidget(controller: _controller),
          ),
        ),

        // Error screen
        if (_hasError) _buildErrorView(),

        // Initial spinner before first paint
        if (_isLoading && _loadingProgress == 0)
          Container(
            color: const Color(0xFF1A3A5C),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Colors.amber,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading KK Tours...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: const Color(0xFF1A3A5C),
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.signal_wifi_off, size: 80, color: Colors.white24),
          const SizedBox(height: 24),
          const Text(
            'Connection Error',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _reload,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _currentUrl = 'https://kktoursrls.com/';
                _hasError = false;
                _isLoading = true;
                _retryCount = 0;
              });
              _loadUrlWithCacheBypass('https://kktoursrls.com/');
            },
            child: const Text(
              'Go to Homepage',
              style: TextStyle(color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }
}
