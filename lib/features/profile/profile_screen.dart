import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../auth/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _users = FirebaseFirestore.instance.collection('users');
  final _authService = AuthService();

  bool _isLoggingOut = false;
  bool _isDeleting = false;
  bool _isRefreshing = false;

  User? get user => _auth.currentUser;

  Future<void> _updateUserData(Map<String, dynamic> data) async {
    final currentUser = user;
    if (currentUser == null) return;

    await _users.doc(currentUser.uid).set(
      {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _saveProfileIcon(String iconKey) async {
    try {
      await _updateUserData({
        'profileIcon': iconKey,
      });

      _showMessage('Profile icon updated.');
    } catch (_) {
      _showMessage('Could not update icon.');
    }
  }

  Future<void> _editDisplayName(String currentName) async {
    final controller = TextEditingController(text: currentName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'TradeMind Trader',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) return;

    final cleanName = result.trim();

    if (cleanName.isEmpty) {
      _showMessage('Name cannot be empty.');
      return;
    }

    if (cleanName.length > 30) {
      _showMessage('Name is too long.');
      return;
    }

    try {
      await user?.updateDisplayName(cleanName);

      await _updateUserData({
        'displayName': cleanName,
      });

      _showMessage('Name updated.');
    } catch (_) {
      _showMessage('Could not update name.');
    }
  }

  Future<void> _showIconPicker(String selectedIcon) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.64,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose icon',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GridView.builder(
                      itemCount: _profileIcons.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.95,
                      ),
                      itemBuilder: (context, index) {
                        final option = _profileIcons[index];
                        final isSelected = option.key == selectedIcon;

                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await _saveProfileIcon(option.key);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.12)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.50)
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  height: 38,
                                  width: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textMuted.withOpacity(0.08),
                                  ),
                                  child: Icon(
                                    option.icon,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textMuted,
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  option.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendPasswordReset() async {
    final email = user?.email;

    if (email == null || email.isEmpty) {
      _showMessage('No email found.');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showMessage('Password reset link sent.');
    } catch (_) {
      _showMessage('Could not send reset email.');
    }
  }

  Future<void> _sendEmailVerification() async {
    final currentUser = user;

    if (currentUser == null) return;

    await currentUser.reload();

    final refreshedUser = _auth.currentUser;

    if (refreshedUser == null) return;

    if (refreshedUser.emailVerified) {
      await _updateUserData({
        'emailVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Email is already verified.');
      setState(() {});
      return;
    }

    try {
      await refreshedUser.sendEmailVerification();
      _showMessage('Verification email sent.');
    } catch (_) {
      _showMessage('Could not send verification email.');
    }
  }

  Future<void> _reloadUser() async {
    setState(() => _isRefreshing = true);

    try {
      await user?.reload();

      final refreshedUser = _auth.currentUser;

      if (refreshedUser != null) {
        await _updateUserData({
          'email': refreshedUser.email,
          'emailVerified': refreshedUser.emailVerified,
        });
      }

      if (!mounted) return;

      setState(() {});
      _showMessage('Profile refreshed.');
    } catch (_) {
      _showMessage('Could not refresh profile.');
    }

    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await _confirmDialog(
      title: 'Logout?',
      message: 'You will need to login again to use TradeMind.',
      confirmText: 'Logout',
      destructive: true,
    );

    if (!confirm) return;

    setState(() => _isLoggingOut = true);

    try {
      await _authService.logout();
    } catch (_) {
      _showMessage('Could not logout.');
    }

    if (mounted) {
      setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _deleteAccount() async {
    final currentUser = user;

    if (currentUser == null) return;

    final confirm = await _confirmDialog(
      title: 'Delete account?',
      message:
          'This will delete your TradeMind account. This action cannot be undone.',
      confirmText: 'Delete',
      destructive: true,
    );

    if (!confirm) return;

    setState(() => _isDeleting = true);

    try {
      final uid = currentUser.uid;

      /*
        Delete Firestore profile first.
        If you delete Firebase Auth first, Firestore rules may block doc delete.
      */
      try {
        await _users.doc(uid).delete();
      } catch (_) {}

      await currentUser.delete();

      _showMessage('Account deleted.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showMessage('Please logout, login again, then delete account.');
      } else {
        _showMessage(e.message ?? 'Could not delete account.');
      }
    } catch (_) {
      _showMessage('Could not delete account.');
    }

    if (mounted) {
      setState(() => _isDeleting = false);
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required bool destructive,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: AppColors.loss,
                    )
                  : null,
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  void _openDangerActions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        final busy = _isLoggingOut || _isDeleting;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Account actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _DangerTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  subtitle: 'Sign out from this device.',
                  loading: _isLoggingOut,
                  onTap: busy
                      ? null
                      : () {
                          Navigator.pop(context);
                          _logout();
                        },
                ),
                const SizedBox(height: 10),
                _DangerTile(
                  icon: Icons.delete_forever_rounded,
                  title: 'Delete account',
                  subtitle: 'Permanently remove your account.',
                  loading: _isDeleting,
                  onTap: busy
                      ? null
                      : () {
                          Navigator.pop(context);
                          _deleteAccount();
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = user;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login again.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isRefreshing ? null : _reloadUser,
            icon: _isRefreshing
                ? const SizedBox(
                    height: 19,
                    width: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Account actions',
            onPressed: _openDangerActions,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _users.doc(currentUser.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load profile.'),
            );
          }

          final data = snapshot.data?.data() ?? {};

          final displayName =
              '${data['displayName'] ?? currentUser.displayName ?? 'TradeMind Trader'}';

          final email = currentUser.email ?? '${data['email'] ?? 'No email'}';

          final selectedIcon = '${data['profileIcon'] ?? 'chart'}';
          final selectedIconData = _iconForKey(selectedIcon);

          final verified =
              currentUser.emailVerified || data['emailVerified'] == true;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
            children: [
              _ProfileHeader(
                displayName: displayName,
                email: email,
                emailVerified: verified,
                icon: selectedIconData.icon,
                onEditName: () => _editDisplayName(displayName),
                onPickIcon: () => _showIconPicker(selectedIcon),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Account',
                children: [
                  _ProfileTile(
                    icon: Icons.lock_reset_rounded,
                    title: 'Reset password',
                    subtitle: 'Send a reset link to your email.',
                    color: AppColors.primary,
                    onTap: _sendPasswordReset,
                  ),
                  const SizedBox(height: 10),
                  _ProfileTile(
                    icon: verified
                        ? Icons.verified_rounded
                        : Icons.mark_email_unread_rounded,
                    title: verified ? 'Email verified' : 'Verify email',
                    subtitle: verified
                        ? 'Your email is confirmed.'
                        : 'Send a verification link.',
                    color: verified ? AppColors.profit : AppColors.primary,
                    onTap: _sendEmailVerification,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SmallInfoCard(
                icon: Icons.school_rounded,
                text:
                    'TradeMind is for journal tracking and educational trading review. Profit is not guaranteed.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openDangerActions,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Account actions'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final bool emailVerified;
  final IconData icon;
  final VoidCallback onEditName;
  final VoidCallback onPickIcon;

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.emailVerified,
    required this.icon,
    required this.onEditName,
    required this.onPickIcon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onPickIcon,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 72,
                      width: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF2563EB),
                            Color(0xFF7C3AED),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.20),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        height: 27,
                        width: 27,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 9),
                    _VerifiedBadge(
                      emailVerified: emailVerified,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 43,
            child: OutlinedButton.icon(
              onPressed: onEditName,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(
                'Edit display name',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  final bool emailVerified;

  const _VerifiedBadge({
    required this.emailVerified,
  });

  @override
  Widget build(BuildContext context) {
    final color = emailVerified ? AppColors.profit : AppColors.loss;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            emailVerified
                ? Icons.verified_rounded
                : Icons.error_outline_rounded,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            emailVerified ? 'Verified' : 'Not verified',
            style: TextStyle(
              color: color,
              fontSize: 10.8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.055),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: color.withOpacity(0.11),
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 37,
                width: 37,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.8,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallInfoCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallInfoCard({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.textMuted,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.7,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  const _DangerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.loss.withOpacity(0.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.loss.withOpacity(0.13),
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: AppColors.loss.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        icon,
                        color: AppColors.loss,
                        size: 21,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.loss,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileIconOption {
  final String key;
  final String label;
  final IconData icon;

  const _ProfileIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}

const List<_ProfileIconOption> _profileIcons = [
  _ProfileIconOption(
    key: 'chart',
    label: 'Chart',
    icon: Icons.show_chart_rounded,
  ),
  _ProfileIconOption(
    key: 'person',
    label: 'Trader',
    icon: Icons.person_rounded,
  ),
  _ProfileIconOption(
    key: 'rocket',
    label: 'Rocket',
    icon: Icons.rocket_launch_rounded,
  ),
  _ProfileIconOption(
    key: 'bolt',
    label: 'Fast',
    icon: Icons.bolt_rounded,
  ),
  _ProfileIconOption(
    key: 'diamond',
    label: 'Pro',
    icon: Icons.diamond_rounded,
  ),
  _ProfileIconOption(
    key: 'shield',
    label: 'Risk',
    icon: Icons.shield_rounded,
  ),
  _ProfileIconOption(
    key: 'brain',
    label: 'Smart',
    icon: Icons.psychology_rounded,
  ),
  _ProfileIconOption(
    key: 'target',
    label: 'Target',
    icon: Icons.track_changes_rounded,
  ),
  _ProfileIconOption(
    key: 'trophy',
    label: 'Winner',
    icon: Icons.emoji_events_rounded,
  ),
  _ProfileIconOption(
    key: 'fire',
    label: 'Fire',
    icon: Icons.local_fire_department_rounded,
  ),
  _ProfileIconOption(
    key: 'robot',
    label: 'AI',
    icon: Icons.smart_toy_rounded,
  ),
  _ProfileIconOption(
    key: 'wallet',
    label: 'Wallet',
    icon: Icons.account_balance_wallet_rounded,
  ),
];

_ProfileIconOption _iconForKey(String key) {
  return _profileIcons.firstWhere(
    (option) => option.key == key,
    orElse: () => _profileIcons.first,
  );
}
