import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../shared/widgets/glass_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late TextEditingController _nicknameController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  final TapGestureRecognizer _signUpRecognizer = TapGestureRecognizer();

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final nickname = _nicknameController.text.trim();
    final password = _passwordController.text;

    final nicknameError = PocketBaseService.validateNickname(nickname);
    if (nicknameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nicknameError),
          backgroundColor: const Color(0xFFFF6B6B),
        ),
      );
      return;
    }

    final passwordError = PocketBaseService.validatePassword(password);
    if (passwordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(passwordError),
          backgroundColor: const Color(0xFFFF6B6B),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    ref.read(authErrorProvider.notifier).state = null;

    try {
      final service = await ref.read(pocketbaseServiceProvider.future);
      await service.login(
        nickname: nickname,
        password: password,
      );

      if (!mounted) return;

      // Update auth state
      ref.read(authStateProvider.notifier).state = true;
      ref.read(currentUserProvider.notifier).state = service.currentUser;
      ref.read(userNicknameProvider.notifier).state =
          service.currentUser?.getStringValue('nickname') ?? nickname;

      Navigator.of(context).pushReplacementNamed('/rooms');
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      ref.read(authErrorProvider.notifier).state = errorMsg;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.darkBg,
                  AppTheme.darkSurfaceVariant.withOpacity(0.5),
                ],
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),
                  // Header
                  Center(
                    child: Column(
                      children: [
                        // Icon(
                        //   Icons.lock_outline,
                        //   size: 64,
                        //   color: AppTheme.glassAccent.withOpacity(0.8),
                        // ),
                        const SizedBox(height: 24),
                        const SizedBox(height: 24),
                        Text(
                          'Login',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your anonymous nickname',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Form
                  TextField(
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      hintText: 'Enter your nickname',
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: AppTheme.glassAccent,
                      ),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: AppTheme.glassAccent,
                      ),
                    ),
                    obscureText: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 32),
                  // Login button
                  GlassButton(
                    label: _isLoading ? 'Logging in...' : 'Login',
                    onPressed: _handleLogin,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  // Sign up link
                  Center(
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                        children: [
                          TextSpan(
                            text: 'Sign Up',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.glassAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                            recognizer: _signUpRecognizer
                              ..onTap = () {
                                Navigator.of(context)
                                    .pushReplacementNamed('/signup');
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
