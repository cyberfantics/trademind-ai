import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();

  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegister = false;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  String get _password => _passwordController.text.trim();

  bool get _hasMinLength => _password.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_password);
  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_password);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_password);
  bool get _hasSpecialChar =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=]').hasMatch(_password);

  bool get _isStrongPassword {
    return _hasMinLength &&
        _hasUppercase &&
        _hasLowercase &&
        _hasNumber &&
        _hasSpecialChar;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_isRegister && !_isStrongPassword) {
      _showMessage('Please use a stronger password.');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      if (_isRegister) {
        await _authService.register(
          email: email,
          password: password,
        );

        if (!mounted) return;

        _showMessage('Account created. Please verify your email.');
      } else {
        await _authService.login(
          email,
          password,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(_friendlyAuthError(e));
    } catch (_) {
      _showMessage('Something went wrong. Please try again.');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    if (!_isValidEmail(email)) {
      _showMessage('Enter your email first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.sendPasswordResetEmail(email);

      if (!mounted) return;

      _showMessage('Password reset link sent.');
    } on FirebaseAuthException catch (e) {
      _showMessage(_friendlyAuthError(e));
    } catch (_) {
      _showMessage('Could not send reset email.');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleMode(bool register) {
    if (_isRegister == register) return;

    setState(() {
      _isRegister = register;
      _showPassword = false;
      _showConfirmPassword = false;
      _confirmPasswordController.clear();
    });
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'This email is already registered. Please login.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegister ? 'Create account' : 'Login';
    final buttonText = _isRegister ? 'Create account' : 'Login';

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 430,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isRegister
                              ? 'Verify email before using TradeMind.'
                              : 'Welcome back to TradeMind.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: AutofillGroup(
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    textInputAction: TextInputAction.next,
                                    decoration: _inputDecoration(
                                      label: 'Email',
                                      icon: Icons.email_rounded,
                                    ),
                                    validator: (value) {
                                      final email = value?.trim() ?? '';

                                      if (email.isEmpty) {
                                        return 'Enter email.';
                                      }

                                      if (!_isValidEmail(email)) {
                                        return 'Enter valid email.';
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_showPassword,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    textInputAction: _isRegister
                                        ? TextInputAction.next
                                        : TextInputAction.done,
                                    decoration: _inputDecoration(
                                      label: 'Password',
                                      icon: Icons.lock_rounded,
                                      suffix: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _showPassword = !_showPassword;
                                          });
                                        },
                                        icon: Icon(
                                          _showPassword
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                        ),
                                      ),
                                    ),
                                    onChanged: (_) {
                                      if (_isRegister) setState(() {});
                                    },
                                    onFieldSubmitted: (_) {
                                      if (!_isRegister && !_isLoading) {
                                        _submit();
                                      }
                                    },
                                    validator: (value) {
                                      final password = value?.trim() ?? '';

                                      if (password.isEmpty) {
                                        return 'Enter password.';
                                      }

                                      if (_isRegister && password.length < 8) {
                                        return 'Minimum 8 characters.';
                                      }

                                      return null;
                                    },
                                  ),
                                  if (_isRegister) ...[
                                    const SizedBox(height: 10),
                                    _PasswordStrengthMini(
                                      hasMinLength: _hasMinLength,
                                      hasUppercase: _hasUppercase,
                                      hasLowercase: _hasLowercase,
                                      hasNumber: _hasNumber,
                                      hasSpecialChar: _hasSpecialChar,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: !_showConfirmPassword,
                                      textInputAction: TextInputAction.done,
                                      decoration: _inputDecoration(
                                        label: 'Confirm password',
                                        icon: Icons.verified_user_rounded,
                                        suffix: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _showConfirmPassword =
                                                  !_showConfirmPassword;
                                            });
                                          },
                                          icon: Icon(
                                            _showConfirmPassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                          ),
                                        ),
                                      ),
                                      onFieldSubmitted: (_) {
                                        if (!_isLoading) _submit();
                                      },
                                      validator: (value) {
                                        if (!_isRegister) return null;

                                        final confirm = value?.trim() ?? '';

                                        if (confirm.isEmpty) {
                                          return 'Confirm password.';
                                        }

                                        if (confirm !=
                                            _passwordController.text.trim()) {
                                          return 'Passwords do not match.';
                                        }

                                        return null;
                                      },
                                    ),
                                  ],
                                  if (!_isRegister) ...[
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed:
                                            _isLoading ? null : _forgotPassword,
                                        child: const Text('Forgot password?'),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: FilledButton(
                                      onPressed: _isLoading ? null : _submit,
                                      style: FilledButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(17),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 21,
                                              width: 21,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              buttonText,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Email verification is required.',
                          style: TextStyle(
                            color: AppColors.textMuted.withOpacity(0.85),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _AuthModeSwitch(
                          isRegister: _isRegister,
                          onChanged: _toggleMode,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      isDense: true,
      filled: true,
      fillColor: AppColors.surface.withOpacity(0.55),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 13,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppColors.border.withOpacity(0.8),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppColors.border.withOpacity(0.8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.3,
        ),
      ),
    );
  }
}

class _AuthModeSwitch extends StatelessWidget {
  final bool isRegister;
  final void Function(bool register) onChanged;

  const _AuthModeSwitch({
    required this.isRegister,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitchItem(
              text: 'Login',
              selected: !isRegister,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _SwitchItem(
              text: 'Create',
              selected: isRegister,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _SwitchItem({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textMuted,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordStrengthMini extends StatelessWidget {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecialChar;

  const _PasswordStrengthMini({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialChar,
  });

  @override
  Widget build(BuildContext context) {
    final passed = [
      hasMinLength,
      hasUppercase,
      hasLowercase,
      hasNumber,
      hasSpecialChar,
    ].where((item) => item).length;

    final color = passed >= 5
        ? AppColors.profit
        : passed >= 3
            ? AppColors.primary
            : AppColors.loss;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withOpacity(0.13),
        ),
      ),
      child: Row(
        children: [
          Icon(
            passed >= 5 ? Icons.verified_rounded : Icons.shield_outlined,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: passed / 5,
                minHeight: 6,
                color: color,
                backgroundColor: color.withOpacity(0.12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$passed/5',
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
