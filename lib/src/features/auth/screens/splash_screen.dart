import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup pulsing animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.1, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Check for auto-login after a short delay
    _checkAuthAndNavigate();
  }

  void _checkAuthAndNavigate() async {
    try {
      // Give some time for the PocketBase to initialize
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;

      final pbAsync = ref.read(pocketbaseProvider);
      
      // Handle both loading and actual value
      pbAsync.when(
        data: (pb) {
          if (!mounted) return;
          
          // Check if user is authenticated
          if (pb.authStore.isValid) {
            final model = pb.authStore.model as RecordModel?;
            if (model != null) {
              final nickname = model.getStringValue('nickname');
              ref.read(authStateProvider.notifier).state = true;
              ref.read(currentUserProvider.notifier).state = model;
              ref.read(userNicknameProvider.notifier).state = nickname;
              Navigator.of(context).pushReplacementNamed('/rooms');
            } else {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          } else {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        },
        error: (error, stack) {
          // On error, go to login
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        },
        loading: () {
          // Wait for loading to complete
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              _checkAuthAndNavigate();
            }
          });
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          // Dark gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.darkBg,
                  AppTheme.darkSurfaceVariant.withOpacity(0.7),
                ],
              ),
            ),
          ),
          // Center owl image with pulsing glow
          Center(
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: size.width * 0.8,
                  height: size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.glassAccent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.glassAccent
                            .withOpacity(_glowAnimation.value),
                        blurRadius: 40,
                        spreadRadius: 15,
                      ),
                      BoxShadow(
                        color: AppTheme.glassAccentSecondary
                            .withOpacity(_glowAnimation.value * 0.6),
                        blurRadius: 60,
                        spreadRadius: 25,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/owl2.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
          // Top text
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Incogni Owl',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Anonymous Chat',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.glassAccent,
                          fontWeight: FontWeight.w300,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          // Bottom tagline
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Stay Anonymous. Stay Safe.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary.withOpacity(0.8),
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
