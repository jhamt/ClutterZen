import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app_firebase.dart';
import '../../services/i18n_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AppFirebase.auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFBFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Profile',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('Please sign in to view your profile'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            AppFirebase.firestore.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final displayName = user.displayName ??
              (data['displayName'] as String?) ??
              'Guest User';
          final email =
              user.email ?? (data['email'] as String?) ?? 'No email provided';
          final photoUrl = user.photoURL;
          final plan = (data['plan'] as String?) ?? 'Free';
          final planNameLower = plan.toLowerCase();
          final planLabel = planNameLower == 'pro'
              ? 'Pro Plan'
              : planNameLower == 'free'
                  ? 'Free Plan'
                  : plan;
          final creditsLeft = (data['scanCredits'] as num?)?.toInt() ?? 0;
          final creditsTotal = (data['creditsTotal'] as num?)?.toInt();
          final bool unlimitedCredits = planNameLower == 'pro' &&
              (creditsTotal == null || creditsTotal <= 0);
          final creditsLabel = unlimitedCredits
              ? 'Unlimited'
              : '$creditsLeft${creditsTotal != null ? ' of $creditsTotal' : ''}';
          final phoneNumber = user.phoneNumber ?? 'No phone number';
          final address = (data['address'] as String?) ?? 'No address provided';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Profile Header Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Profile Picture
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEEF1F6),
                          border: Border.all(
                            color: const Color(0xFF111111),
                            width: 3,
                          ),
                        ),
                        child: photoUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  photoUrl,
                                  width: 74,
                                  height: 74,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: 40,
                                      color: const Color(0xFF111111),
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 40,
                                color: const Color(0xFF111111),
                              ),
                      ),
                      const SizedBox(width: 16),

                      // Profile Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: planNameLower == 'pro'
                                    ? const Color(0xFF111111)
                                    : const Color(0xFFEEF1F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                planLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: planNameLower == 'pro'
                                      ? Colors.white
                                      : const Color(0xFF475467),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Edit Button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () => Navigator.of(context)
                              .pushNamed('/update-profile'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Personal Info Section
                _InfoSection(
                  title: 'Personal info',
                  items: [
                    _InfoItem(
                      icon: Icons.person_outline,
                      label: 'Name',
                      value: displayName,
                    ),
                    _InfoItem(
                      icon: Icons.email_outlined,
                      label: 'E-mail',
                      value: email,
                    ),
                    _InfoItem(
                      icon: Icons.phone_outlined,
                      label: 'Phone number',
                      value: phoneNumber,
                    ),
                    _InfoItem(
                      icon: Icons.home_outlined,
                      label: 'Home address',
                      value: address,
                    ),
                  ],
                  onEdit: () =>
                      Navigator.of(context).pushNamed('/update-profile'),
                ),

                const SizedBox(height: 16),

                // Account Info Section
                _InfoSection(
                  title: 'Account info',
                  items: [
                    _InfoItem(
                      icon: Icons.card_membership_outlined,
                      label: 'Current Plan',
                      value: planLabel,
                    ),
                    _InfoItem(
                      icon: Icons.stars_outlined,
                      label: 'Credits Remaining',
                      value: creditsLabel,
                    ),
                    _InfoItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Member Since',
                      value: _formatDate(data['createdAt']),
                    ),
                  ],
                  onEdit: () => Navigator.of(context).pushNamed('/pricing'),
                ),

                const SizedBox(height: 24),

                // Settings Items
                _LanguageCard(),
                const SizedBox(height: 12),

                _SettingsCard(
                  icon: Icons.notifications_outlined,
                  iconColor: const Color(0xFF111111),
                  title: 'Notification Settings',
                  trailing: const Icon(Icons.keyboard_arrow_right,
                      color: Colors.grey),
                  onTap: () =>
                      Navigator.of(context).pushNamed('/notification-settings'),
                ),
                const SizedBox(height: 12),

                _SettingsCard(
                  icon: Icons.history,
                  iconColor: const Color(0xFF111111),
                  title: 'Scan history',
                  trailing: const Icon(Icons.keyboard_arrow_right,
                      color: Colors.grey),
                  onTap: () => Navigator.of(context).pushNamed('/history'),
                ),
                const SizedBox(height: 12),

                _SettingsCard(
                  icon: Icons.card_membership,
                  iconColor: const Color(0xFF111111),
                  title: 'Manage Subscription',
                  trailing: const Icon(Icons.keyboard_arrow_right,
                      color: Colors.grey),
                  onTap: () => Navigator.of(context).pushNamed('/subscription'),
                ),
                const SizedBox(height: 12),

                _SettingsCard(
                  icon: Icons.account_balance_wallet,
                  iconColor: const Color(0xFF111111),
                  title: 'Connect Stripe Account',
                  trailing: const Icon(Icons.keyboard_arrow_right,
                      color: Colors.grey),
                  onTap: () =>
                      Navigator.of(context).pushNamed('/connect-account'),
                ),
                const SizedBox(height: 24),

                // App Settings Section Header
                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 12),
                  child: Text(
                    'App Settings',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                _SettingsCard(
                  icon: Icons.help_outline,
                  iconColor: const Color(0xFF111111),
                  title: 'Support',
                  trailing: const Icon(Icons.keyboard_arrow_right,
                      color: Colors.grey),
                  onTap: () => Navigator.of(context).pushNamed('/contact-us'),
                ),
                const SizedBox(height: 12),

                _SettingsCard(
                  icon: Icons.security,
                  iconColor: Colors.black,
                  title: 'Terms of Service',
                  trailing: const Icon(Icons.keyboard_arrow_right,
                      color: Colors.grey),
                  onTap: () => Navigator.of(context).pushNamed('/terms'),
                ),
                const SizedBox(height: 12),

                _SettingsCard(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: const Color(0xFF111111),
                  title: 'Privacy Policy',
                  trailing: const Icon(Icons.keyboard_arrow_right,
                      color: Colors.grey),
                  onTap: () =>
                      Navigator.of(context).pushNamed('/privacy-policy'),
                ),
                const SizedBox(height: 12),

                _SettingsCard(
                  icon: Icons.logout,
                  iconColor: Colors.red,
                  title: 'Log Out',
                  trailing: null,
                  onTap: () async {
                    await AppFirebase.auth.signOut();
                    if (context.mounted) {
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/splash', (_) => false);
                    }
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.month}/${date.day}/${date.year}';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.items,
    required this.onEdit,
  });

  final String title;
  final List<_InfoItem> items;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: item,
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _LanguageCard extends StatefulWidget {
  const _LanguageCard();

  @override
  State<_LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends State<_LanguageCard> {
  @override
  Widget build(BuildContext context) {
    final currentLocale = I18nService.currentLocale;
    final currentLanguage = I18nService.getLocaleDisplayName(currentLocale);

    return _SettingsCard(
      icon: Icons.language,
      iconColor: const Color(0xFF111111),
      title: currentLanguage,
      trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
      onTap: () => _showLanguageDialog(context),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: I18nService.supportedLocales.map((locale) {
            final isSelected = locale == I18nService.currentLocale;
            return ListTile(
              title: Text(I18nService.getLocaleDisplayName(locale)),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Color(0xFF111111))
                  : null,
              onTap: () {
                I18nService.setLocale(locale);
                Navigator.of(context).pop();
                setState(() {}); // Update UI
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Language changed to ${I18nService.getLocaleDisplayName(locale)}',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
