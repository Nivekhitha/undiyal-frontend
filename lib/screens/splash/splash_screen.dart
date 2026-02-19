import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../services/sms_notification_listener.dart';
import '../../services/app_init_service.dart';
import '../permissions/notification_listener_permission_screen.dart';
import '../auth/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Single animation controller for both fade and scale
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Logo fade-in animation (0ms - 500ms)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeInOut),
      ),
    );

    // White circle scale animation (800ms - 2000ms)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 50.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Start the animation sequence
    _startAnimation();
  }

  void _startAnimation() async {
    // Perform lightweight initialization
    await _performLightweightInit();
    
    // Start the animation
    await _animationController.forward();
    
    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Navigate after animation completes (2.5 seconds total)
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      // Check if user has already seen the notification listener permission screen
      final prefs = await SharedPreferences.getInstance();
      final hasSeenListenerPermission = prefs.getBool('has_seen_listener_permission') ?? false;
      final Widget destination = hasSeenListenerPermission
          ? const AuthGate()
          : const NotificationListenerPermissionScreen();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => destination,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  Future<void> _performLightweightInit() async {
    try {
      // Silent notification listener check (no user prompting)
      final listener = SmsNotificationListener();
      final hasNotificationAccess = await listener.isListenerEnabled();
      debugPrint('Notification listener access: $hasNotificationAccess');
      
      // Initialize core services without heavy operations
      await AppInitService.initialize();
      
      debugPrint('Lightweight initialization completed');
    } catch (e) {
      debugPrint('Lightweight init error: $e');
      // Continue even if init fails - don't block user experience
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.primary,
      child: Stack(
        children: [
          // White circle zoom animation
          Center(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: const BoxDecoration(
                      color: CupertinoColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),

          // App logo with fade animation
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Image.asset(
                'assets/icon/undiyal-logo-transparent.gif',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}