import 'package:flutter/material.dart';

import '../../app_firebase.dart';
import '../../models/subscription_plan.dart';
import '../../services/stripe_service.dart';
import '../../services/user_service.dart';
import 'checkout_screen.dart';

/// Screen for managing user subscriptions
class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  String? _currentPlanId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSubscription();
  }

  Future<void> _loadCurrentSubscription() async {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final doc =
          await AppFirebase.firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? const <String, dynamic>{};
      setState(() {
        _currentPlanId = _resolvePlanId(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _currentPlanId = 'free';
        _loading = false;
      });
    }
  }

  String _resolvePlanId(Map<String, dynamic> data) {
    final subscriptionPlan =
        (data['subscriptionPlan'] as String?)?.trim().toLowerCase();
    if (subscriptionPlan == 'free' || subscriptionPlan == 'pro') {
      return subscriptionPlan!;
    }

    final plan = (data['plan'] as String?)?.trim().toLowerCase();
    if (plan == 'free' || plan == 'pro') {
      return plan!;
    }

    return 'free';
  }

  Future<void> _upgradeToPlan(SubscriptionPlan plan) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(plan: plan),
      ),
    );

    if (result == true) {
      // Reload subscription info
      await _loadCurrentSubscription();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _downgradeToFree() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Downgrade to Free Plan'),
        content: const Text(
          'Are you sure you want to downgrade to the Free plan? '
          'You will lose access to Pro features and your subscription will be canceled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Downgrade'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Cancel Stripe subscription if exists
      final userDoc =
          await AppFirebase.firestore.collection('users').doc(uid).get();
      final stripeSubscriptionId =
          userDoc.data()?['stripeSubscriptionId'] as String?;

      if (stripeSubscriptionId != null) {
        try {
          await StripeService.cancelSubscription(stripeSubscriptionId);
        } catch (e) {
          debugPrint('Error canceling Stripe subscription: $e');
          // Continue with downgrade even if Stripe cancel fails
        }
      }

      // Downgrade plan server-side.
      await UserService.setFreePlan();

      await _loadCurrentSubscription();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downgraded to Free plan successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downgrading: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscription')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentPlan = SubscriptionPlan.getById(_currentPlanId ?? 'free');
    final isPro = _currentPlanId == 'pro';

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current plan card
          if (currentPlan != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Plan',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentPlan.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isPro
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isPro ? 'Active' : 'Free',
                            style: TextStyle(
                              color: isPro
                                  ? Colors.green.shade900
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentPlan.formattedPrice,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    if (isPro) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _downgradeToFree,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Cancel Subscription'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Available plans
          Text(
            'Available Plans',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...SubscriptionPlan.plans.map((plan) {
            final isCurrentPlan = plan.id == _currentPlanId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plan.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  plan.description,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          if (plan.isPopular)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Popular',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        plan.formattedPrice,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                      ),
                      const SizedBox(height: 12),
                      ...plan.features.map((feature) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(feature)),
                              ],
                            ),
                          )),
                      const SizedBox(height: 16),
                      if (isCurrentPlan)
                        OutlinedButton(
                          onPressed: null,
                          child: const Text('Current Plan'),
                        )
                      else
                        ElevatedButton(
                          onPressed: () => _upgradeToPlan(plan),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: Text(
                            plan.price == 0 ? 'Switch to Free' : 'Upgrade',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
