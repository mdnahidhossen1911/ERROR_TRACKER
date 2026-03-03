import 'package:error_tracker/error_tracker.dart';
import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════
///  CONSOLE-ONLY MODE (no server needed):
/// ══════════════════════════════════════════════════════════
///
///   void main() => ErrorTracker.runApp(
///     config: ErrorTrackerConfig(
///       appName: 'MyApp', appVersion: '1.0.0', buildNumber: '1',
///     ),
///     app: const MyApp(),
///   );
///
/// ══════════════════════════════════════════════════════════
///  WITH YOUR REST API:
/// ══════════════════════════════════════════════════════════
///
///   void main() => ErrorTracker.runApp(
///     config: ErrorTrackerConfig(
///       appName: 'MyApp', appVersion: '1.0.0', buildNumber: '1',
///       apiConfig: ErrorTrackerApiConfig(
///         endpoint: 'https://api.yourserver.com/v1/crashes',
///         apiKey: 'your-secret-key',
///       ),
///     ),
///     app: const MyApp(),
///   );

void main() => ErrorTracker.runApp(
      config: ErrorTrackerConfig(
        appName: 'MyApp',
        appVersion: '1.0.0',
        buildNumber: '12',
        minimumLevel: ErrorLevel.info,
        // Uncomment + fill in to enable remote reporting:
        // apiConfig: ErrorTrackerApiConfig(
        //   endpoint: 'https://api.yourserver.com/v1/crashes',
        //   apiKey: 'your-secret-key',
        // ),
      ),
      app: const ExampleApp(),
    );

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ErrorTracker Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
        useMaterial3: true,
      ),
      // Auto-record navigation breadcrumbs
      navigatorObservers: [_BreadcrumbObserver()],
      home: const HomeScreen(),
    );
  }
}

/// Automatically records every route push/pop as a navigation breadcrumb.
class _BreadcrumbObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) =>
      ErrorTracker.navigation(route.settings.name ?? route.runtimeType.toString());

  @override
  void didPop(Route route, Route? previousRoute) =>
      ErrorTracker.navigation(previousRoute?.settings.name ?? 'back');
}

// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // ── Set user context (call after login) ──────────────────────────────────
    ErrorTracker.setUser(UserInfo(
      id: 'user_42',
      email: 'demo@example.com',
      name: 'Demo User',
    ));
    // ── Set custom context keys ──────────────────────────────────────────────
    ErrorTracker.setCustomKey('subscription', 'premium');
    ErrorTracker.setCustomKey('onboarding_complete', true);
    ErrorTracker.setCustomKey('app_theme', 'dark');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ErrorTracker — Full Demo'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Section 1: Auto-captured ───────────────────────────────────────
          const _SectionHeader(
            '🔴 AUTO-CAPTURED',
            'These are caught by the 3 layers — zero manual code',
          ),

          _Btn(
            icon: '💥',
            label: 'Null Check Crash',
            sub: 'FlutterError → Layer 1',
            color: Colors.red.shade700,
            onTap: () {
              ErrorTracker.action('tapped_null_crash_demo');
              final String? s = null;
              debugPrint(s!); // throws Null check on null
            },
          ),

          _Btn(
            icon: '⏳',
            label: 'Unhandled Future',
            sub: 'AsyncError → Zone (Layer 2)',
            color: Colors.orange.shade800,
            onTap: () {
              ErrorTracker.action('tapped_future_error_demo');
              Future.delayed(
                const Duration(milliseconds: 50),
                () => throw Exception('Future threw — no one caught me'),
              );
            },
          ),

          _Btn(
            icon: '🌀',
            label: 'async/await Throw',
            sub: 'AsyncError → Zone (Layer 2)',
            color: Colors.orange.shade600,
            onTap: () async {
              ErrorTracker.stateChange('starting_async_demo');
              await Future.delayed(const Duration(milliseconds: 10));
              throw StateError('Unhandled state error in async gap');
            },
          ),

          _Btn(
            icon: '🔴',
            label: 'Unhandled Stream Error',
            sub: 'AsyncError → Zone (Layer 2)',
            color: Colors.deepOrange,
            onTap: () {
              ErrorTracker.stateChange('stream_demo_started');
              final ctrl = Stream<int>.error(
                  Exception('Stream emitted error with no handler'));
              ctrl.listen((_) {});
            },
          ),

          // ── Section 2: Breadcrumb trail ────────────────────────────────────
          const _SectionHeader(
            '🟡 BREADCRUMB TRAIL',
            'Crash report will include all steps below',
          ),

          _Btn(
            icon: '🗺️',
            label: 'Crash with Full Trail',
            sub: 'navigation → action → network → state → CRASH',
            color: Colors.purple.shade700,
            onTap: () {
              // Simulate a realistic user journey before crash
              ErrorTracker.navigation('/cart');
              ErrorTracker.action('add_to_cart', data: {'sku': 'PROD_001', 'qty': 2});
              ErrorTracker.navigation('/checkout');
              ErrorTracker.action('entered_card_details');
              ErrorTracker.networkCall('POST', '/api/v1/payments', statusCode: 500);
              ErrorTracker.stateChange('payment_failed', data: {'reason': 'gateway_timeout'});
              ErrorTracker.networkCall('POST', '/api/v1/payments/retry', statusCode: 500);
              // Crash — report includes the 7 breadcrumbs above
              throw Exception('Payment service unresponsive after 2 attempts');
            },
          ),

          // ── Section 3: Optional manual API ────────────────────────────────
          const _SectionHeader(
            '🔵 OPTIONAL MANUAL API',
            'These exist but are never required',
          ),

          _Btn(
            icon: '📡',
            label: 'API Error 503',
            sub: 'logApiError() — HTTP error helper',
            color: Colors.teal.shade700,
            onTap: () {
              ErrorTracker.networkCall('GET', '/api/v1/products', statusCode: 503);
              ErrorTracker.logApiError(
                '/api/v1/products',
                statusCode: 503,
                message: 'Product service unavailable',
              );
            },
          ),

          _Btn(
            icon: '📡',
            label: 'API Error 404',
            sub: 'logApiError() — 4xx client error',
            color: Colors.teal.shade500,
            onTap: () {
              ErrorTracker.logApiError(
                '/api/v1/users/99999',
                statusCode: 404,
                message: 'User not found',
              );
            },
          ),

          _Btn(
            icon: '📝',
            label: 'Manual Info Log',
            sub: 'log() with INFO level',
            color: Colors.blueGrey.shade600,
            onTap: () => ErrorTracker.log('User navigated to settings'),
          ),

          _Btn(
            icon: '⚠️',
            label: 'Manual Warning',
            sub: 'log() with WARNING level',
            color: Colors.blueGrey.shade700,
            onTap: () => ErrorTracker.log(
              'Low storage detected',
              level: ErrorLevel.warning,
            ),
          ),

          _Btn(
            icon: '🚨',
            label: 'Critical with Stack',
            sub: 'log() with CRITICAL + stackTrace',
            color: Colors.blueGrey.shade800,
            onTap: () => ErrorTracker.log(
              'Database write failed — data loss possible',
              level: ErrorLevel.critical,
              stackTrace: StackTrace.current,
            ),
          ),

          // ── Section 4: User context ────────────────────────────────────────
          const _SectionHeader(
            '👤 USER CONTEXT',
            'Attached to all subsequent reports',
          ),

          _Btn(
            icon: '🔑',
            label: 'Update Custom Keys',
            sub: 'setCustomKey() — then trigger a log',
            color: Colors.indigo.shade600,
            onTap: () {
              ErrorTracker.setCustomKey('last_screen', 'home');
              ErrorTracker.setCustomKey('session_action_count', 12);
              ErrorTracker.log('Custom keys updated', level: ErrorLevel.info);
            },
          ),

          _Btn(
            icon: '👋',
            label: 'Logout — Clear User',
            sub: 'setUser(null) — clears identity from future reports',
            color: Colors.indigo.shade400,
            onTap: () {
              ErrorTracker.setUser(null);
              ErrorTracker.log('User logged out', level: ErrorLevel.info);
            },
          ),

          // ── Section 5: Offline queue ───────────────────────────────────────
          const _SectionHeader(
            '📦 OFFLINE QUEUE',
            'Reports saved locally when no internet',
          ),

          _Btn(
            icon: '🔄',
            label: 'Flush Offline Queue',
            sub: 'Retry all queued reports now',
            color: Colors.green.shade700,
            onTap: () async {
              await ErrorTracker.flushOfflineQueue();
              final count = await ErrorTracker.pendingQueueCount;
              ErrorTracker.log(
                'Queue flushed. Remaining: $count',
                level: ErrorLevel.info,
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.black54)),
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.black38)),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(sub,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.white.withOpacity(0.5), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
