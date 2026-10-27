import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import 'auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _authService = AuthService();

  bool _isChecking = false;
  bool _isResending = false;
  bool _isDeleting = false;

  int _resendSecondsLeft = 0;
  Timer? _resendTimer;

  User? get _user => FirebaseAuth.instance.currentUser;

  String get _email => _user?.email ?? 'your email';

  bool get _isBusy => _isChecking || _isResending || _isDeleting;

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);

    try {
      final verified = await _authService.reloadAndCheckEmailVerified();

      if (!mounted) return;

      if (verified) {
        _showMessage('Email verified successfully.');
      } else {
        _showMessage('Email is not verified yet.');
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(_friendlyAuthError(e));
    } catch (_) {
      _showMessage('Something went wrong. Please try again.');
    }

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    if (_resendSecondsLeft > 0) return;

    setState(() => _isResending = true);

    try {
      await _authService.resendVerificationEmail();

      if (!mounted) return;

      _showMessage('Verification email sent.');
      _startResendCooldown();
    } on FirebaseAuthException catch (e) {
      _showMessage(_friendlyAuthError(e));
    } catch (_) {
      _showMessage('Could not resend email. Please try again.');
    }

    if (mounted) {
      setState(() => _isResending = false);
    }
  }

  Future<void> _useDifferentEmail() async {
    await _authService.logout();
  }

  Future<void> _deleteUnverifiedAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This will delete this unverified account so you can create a new one.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      await _authService.deleteCurrentUnverifiedAccount();

      if (!mounted) return;

      _showMessage('Account deleted.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showMessage('Please login again, then try deleting.');
      } else {
        _showMessage(_friendlyAuthError(e));
      }
    } catch (_) {
      _showMessage('Could not delete account.');
    }

    if (mounted) {
      setState(() => _isDeleting = false);
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();

    setState(() {
      _resendSecondsLeft = 45;
    });

    _resendTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_resendSecondsLeft <= 1) {
          timer.cancel();
          setState(() {
            _resendSecondsLeft = 0;
          });
        } else {
          setState(() {
            _resendSecondsLeft--;
          });
        }
      },
    );
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet.';
      case 'user-token-expired':
        return 'Session expired. Please login again.';
      case 'requires-recent-login':
        return 'Please login again before doing this.';
      case 'already-verified':
        return e.message ?? 'This account is already verified.';
      default:
        return e.message ?? 'Something went wrong.';
    }
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
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resendText = _resendSecondsLeft > 0
        ? 'Resend in $_resendSecondsLeft s'
        : 'Resend email';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _VerifyIcon(),
                  const SizedBox(height: 18),
                  const Text(
                    'Check your email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We sent a verification link.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _EmailChip(
                    email: _email,
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const _ShortHelpBox(),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _isBusy ? null : _checkVerification,
                            icon: _isChecking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.verified_rounded),
                            label: Text(
                              _isChecking ? 'Checking...' : 'I verified',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isBusy || _resendSecondsLeft > 0
                                ? null
                                : _resendEmail,
                            icon: _isResending
                                ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            label: Text(
                              resendText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _BottomActions(
                    isBusy: _isBusy,
                    isDeleting: _isDeleting,
                    onUseDifferentEmail: _useDifferentEmail,
                    onDeleteAccount: _deleteUnverifiedAccount,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifyIcon extends StatelessWidget {
  const _VerifyIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.17),
        ),
      ),
      child: const Icon(
        Icons.mark_email_read_rounded,
        color: AppColors.primary,
        size: 38,
      ),
    );
  }
}

class _EmailChip extends StatelessWidget {
  final String email;

  const _EmailChip({
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.email_rounded,
            color: AppColors.textMuted,
            size: 16,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortHelpBox extends StatelessWidget {
  const _ShortHelpBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.12),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 19,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Open the link in your email, then come back and tap verify.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.3,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool isBusy;
  final bool isDeleting;
  final VoidCallback onUseDifferentEmail;
  final VoidCallback onDeleteAccount;

  const _BottomActions({
    required this.isBusy,
    required this.isDeleting,
    required this.onUseDifferentEmail,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: isBusy ? null : onUseDifferentEmail,
          child: const Text(
            'Use different email',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed: isBusy ? null : onDeleteAccount,
          child: Text(
            isDeleting ? 'Deleting...' : 'Delete unverified account',
            style: const TextStyle(
              color: AppColors.loss,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
