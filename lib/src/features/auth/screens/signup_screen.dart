import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../shared/widgets/glass_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  late TextEditingController _nicknameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  final TapGestureRecognizer _loginRecognizer = TapGestureRecognizer();
  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignup() async {
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validate nickname
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

    // Validate password
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
      await service.signup(
        nickname: nickname,
        password: password,
        email: email.isNotEmpty ? email : null,
      );

      // After signup, automatically login
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
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurfaceVariant,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.glassAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account'),
      ),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  // Header
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_add_outlined,
                          size: 64,
                          color: AppTheme.glassAccent.withOpacity(0.8),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Create Anonymous Account',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join anonymous rooms and chat freely',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Form
                  TextField(
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      hintText: 'Choose a nickname',
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
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'Email (optional)',
                      prefixIcon: const Icon(
                        Icons.mail_outline,
                        color: AppTheme.glassAccent,
                      ),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    keyboardType: TextInputType.emailAddress,
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
                  // Signup button
                  GlassButton(
                    label: _isLoading ? 'Creating account...' : 'Sign Up',
                    onPressed: _handleSignup,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  // Login link
                  Center(
                    child: RichText(
                      text: TextSpan(
                        text: "Already have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                        children: [
                          TextSpan(
                            text: 'Login',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.glassAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                            recognizer: _loginRecognizer
                              ..onTap = () {
                                Navigator.of(context)
                                    .pushReplacementNamed('/login');
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
