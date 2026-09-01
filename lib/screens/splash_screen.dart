import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/onboarding_service.dart';
import '../services/encryption_service.dart';
import '../utils/responsive.dart';

/// Modern Gradient + Glass UI Colors
class ModernColors {
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color accentBlue = Color(0xFF42A5F5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1E1E1E);
  static const Color textLight = Color(0xFF9E9E9E);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.elasticOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      // User is signed in, check if they have unlocked the vault
      final hasKey = await EncryptionService.hasCachedKey();
      if (hasKey) {
        await EncryptionService.initializeFromCache();
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/master-password');
      }
      return;
    }

    // Check onboarding status
    final isOnboardingCompleted = await OnboardingService.isOnboardingCompleted();

    if (!mounted) return;

    if (isOnboardingCompleted) {
      // Onboarding completed but not signed in, show login
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      // Show onboarding
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ModernColors.primaryBlue,
              ModernColors.accentBlue,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ResponsiveLayout(
            maxWidth: 600,
            centerContent: true,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Glass-effect icon container
                          Container(
                            width: ResponsiveBreakpoints.responsive<double>(
                              context,
                              mobile: 120,
                              tablet: 140,
                              desktop: 160,
                            ),
                            height: ResponsiveBreakpoints.responsive<double>(
                              context,
                              mobile: 120,
                              tablet: 140,
                              desktop: 160,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                ResponsiveBreakpoints.responsive<double>(
                                  context,
                                  mobile: 24,
                                  tablet: 28,
                                  desktop: 32,
                                ),
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              size: ResponsiveBreakpoints.responsive<double>(
                                context,
                                mobile: 60,
                                tablet: 70,
                                desktop: 80,
                              ),
                              color: ModernColors.white,
                            ),
                          ),

                          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
                            context,
                            mobile: 24,
                            tablet: 28,
                            desktop: 32,
                          )),

                          // App Name
                          Text(
                            'LinkCrypta',
                            style: TextStyle(
                              fontSize: ResponsiveBreakpoints.responsiveFontSize(
                                context,
                                mobile: 32,
                                tablet: 36,
                                desktop: 40,
                              ),
                              fontWeight: FontWeight.bold,
                              color: ModernColors.white,
                              letterSpacing: 1.5,
                            ),
                          ),

                          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
                            context,
                            mobile: 8,
                            tablet: 10,
                            desktop: 12,
                          )),

                          // Tagline
                          Text(
                            'Secure Password & Link Vault',
                            style: TextStyle(
                              fontSize: ResponsiveBreakpoints.responsiveFontSize(
                                context,
                                mobile: 16,
                                tablet: 18,
                                desktop: 20,
                              ),
                              color: ModernColors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
                            context,
                            mobile: 40,
                            tablet: 44,
                            desktop: 48,
                          )),

                          // Progress Indicator
                          SizedBox(
                            width: ResponsiveBreakpoints.responsive<double>(
                              context,
                              mobile: 24,
                              tablet: 28,
                              desktop: 32,
                            ),
                            height: ResponsiveBreakpoints.responsive<double>(
                              context,
                              mobile: 24,
                              tablet: 28,
                              desktop: 32,
                            ),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(ModernColors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
