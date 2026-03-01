import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_firebase.dart';
import '../services/i18n_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AppFirebase.auth.currentUser;

    return Drawer(
      child: SafeArea(
        child: user == null
            ? const _AnonymousDrawer()
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: AppFirebase.firestore
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data =
                      snapshot.data?.data() ?? const <String, dynamic>{};
                  final displayName = user.displayName ??
                      (data['displayName'] as String?) ??
                      I18nService.translate('you');
                  final email = user.email ??
                      (data['email'] as String?) ??
                      I18nService.translate('add_your_email');
                  final photoUrl = user.photoURL;
                  final planRaw = (data['plan'] as String?) ??
                      I18nService.translate('free_plan');
                  final planLower = planRaw.toLowerCase();
                  final planLabel = planLower == 'pro'
                      ? I18nService.translate('pro_plan')
                      : planLower == 'free'
                          ? I18nService.translate('free_plan')
                          : planRaw;
                  final creditsLeft = (data['scanCredits'] as num?)?.toInt();
                  final creditsTotal = (data['creditsTotal'] as num?)?.toInt();
                  final creditsUsedStored =
                      (data['creditsUsed'] as num?)?.toInt();
                  final int? creditsUsedCalculated = creditsUsedStored ??
                      (creditsTotal != null && creditsLeft != null
                          ? (creditsTotal - creditsLeft).clamp(0, creditsTotal)
                          : null);

                  double? progress;
                  String creditsSummary;
                  final hasUnlimitedCredits = planLower == 'pro' &&
                      (creditsTotal == null || creditsTotal <= 0);
                  if (hasUnlimitedCredits) {
                    creditsSummary =
                        I18nService.translate('unlimited_credits_included');
                  } else if (creditsTotal != null &&
                      creditsTotal > 0 &&
                      creditsUsedCalculated != null) {
                    progress =
                        (creditsUsedCalculated / creditsTotal).clamp(0.0, 1.0);
                    creditsSummary = I18nService.translate(
                      'credits_used_summary',
                      params: {
                        'used': '$creditsUsedCalculated',
                        'total': '$creditsTotal',
                      },
                    );
                  } else if (creditsLeft != null) {
                    creditsSummary = I18nService.translate(
                      'credits_remaining_summary',
                      params: {'count': '$creditsLeft'},
                    );
                  } else {
                    creditsSummary =
                        I18nService.translate('credits_info_unavailable');
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    children: [
                      _UserHeader(
                        name: displayName,
                        email: email,
                        photoUrl: photoUrl,
                      ),
                      const SizedBox(height: 24),
                      _PlanCard(
                        plan: planLabel,
                        creditsSummary: creditsSummary,
                        progress: progress,
                        onUpgrade: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushNamed('/pricing');
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(I18nService.translate('quick_links'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _DrawerLink(
                        icon: Icons.home_outlined,
                        label: I18nService.translate('home'),
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      _DrawerLink(
                        icon: Icons.category_outlined,
                        label: I18nService.translate('categories'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushNamed('/categories');
                        },
                      ),
                      _DrawerLink(
                        icon: Icons.history,
                        label: I18nService.translate('history'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushNamed('/history');
                        },
                      ),
                      _DrawerLink(
                        icon: Icons.account_circle_outlined,
                        label: I18nService.translate('profile_settings'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushNamed('/settings');
                        },
                      ),
                      _DrawerLink(
                        icon: Icons.help_outline,
                        label: I18nService.translate('faqs_support'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushNamed('/faqs');
                        },
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await AppFirebase.auth.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                                '/splash', (route) => false);
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: Text(I18nService.translate('sign_out')),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _AnonymousDrawer extends StatelessWidget {
  const _AnonymousDrawer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(I18nService.translate('welcome_to_clutter_zen'),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            I18nService.translate('sign_in_track_progress'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(77),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed('/sign-in');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(I18nService.translate('sign_in_or_create_account')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.name,
    required this.email,
    this.photoUrl,
  });

  final String name;
  final String email;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: [
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.secondary,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withAlpha(60),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? Text(
                    _initials(name),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withAlpha(210),
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.creditsSummary,
    required this.onUpgrade,
    this.progress,
  });

  final String plan;
  final String creditsSummary;
  final VoidCallback onUpgrade;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  plan,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(32),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  I18nService.translate('current_plan'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            creditsSummary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onUpgrade,
              icon: const Icon(Icons.rocket_launch_outlined),
              label: Text(I18nService.translate('upgrade_plan')),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _DrawerLink extends StatelessWidget {
  const _DrawerLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
