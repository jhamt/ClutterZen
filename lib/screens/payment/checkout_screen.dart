import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

import '../../models/subscription_plan.dart';
import '../../services/stripe_service.dart';
import '../../services/user_service.dart';
import '../../app_firebase.dart';

import '../../services/i18n_service.dart';

/// Screen for processing payment and subscription checkout
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.plan,
  });

  final SubscriptionPlan plan;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _processing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeStripe();
  }

  Future<void> _initializeStripe() async {
    try {
      await StripeService.initialize();
      if (!StripeService.isInitialized) {
        setState(() {
          _errorMessage = I18nService.translate(
              "Stripe is not configured. Please add STRIPE_PUBLISHABLE_KEY to .env.public.");
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            '${I18nService.translate("Failed to initialize payment system")}: $e';
      });
    }
  }

  Future<void> _processPayment() async {
    if (!StripeService.isInitialized) {
      setState(() {
        _errorMessage = I18nService.translate(
            "Payment system not available. Please configure client/public Stripe settings.");
      });
      return;
    }

    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    try {
      final uid = AppFirebase.auth.currentUser?.uid;
      if (uid == null) {
        throw Exception(I18nService.translate("User not authenticated"));
      }

      // For free plan, just apply it without payment
      if (widget.plan.price == 0) {
        await UserService.setFreePlan();

        if (!mounted) return;
        Navigator.of(context).pop(true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${widget.plan.name} ${I18nService.translate("plan activated successfully!")}'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      // For paid plans, process payment
      if (widget.plan.priceId.isEmpty) {
        throw Exception(I18nService.translate(
            "Plan price ID not configured. Please set up Stripe Price IDs in subscription_plan.dart"));
      }

      // Process subscription payment
      await StripeService.presentSubscriptionSheet(
        priceId: widget.plan.priceId,
        customerId: null, // Will create customer automatically
      );

      final subscriptionId = StripeService.lastCreatedSubscriptionId;
      if (subscriptionId == null || subscriptionId.isEmpty) {
        throw Exception(
            I18nService.translate("Missing subscription ID after payment"));
      }

      // Payment successful, activate plan server-side after ownership/status verification.
      await StripeService.activateSubscription(
        subscriptionId: subscriptionId,
        planId: widget.plan.id,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true); // Return success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${widget.plan.name} ${I18nService.translate("plan activated successfully!")}'),
          backgroundColor: Colors.green,
        ),
      );
    } on StripeException catch (e) {
      setState(() {
        _errorMessage = e.error.message ??
            I18nService.translate("Payment failed. Please try again.");
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            '${I18nService.translate("Payment failed")}: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18nService.translate("Checkout")),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Plan summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan.name,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.plan.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.plan.formattedPrice,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        I18nService.translate("Features:"),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 8),
                      ...widget.plan.features.map((feature) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(feature)),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null) const SizedBox(height: 16),

              // Payment button
              ElevatedButton(
                onPressed: _processing || !StripeService.isInitialized
                    ? null
                    : _processPayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _processing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.plan.price == 0
                            ? I18nService.translate("Activate Free Plan")
                            : I18nService.translate("Subscribe Now"),
                        style: const TextStyle(fontSize: 16),
                      ),
              ),

              const SizedBox(height: 16),

              // Security notice
              Row(
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      I18nService.translate(
                          "Your payment is secure and encrypted"),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                ],
              ),

              if (!StripeService.isInitialized) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text(
                            I18nService.translate("Stripe Not Configured"),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        I18nService.translate(
                            "To enable payments:\n1. Configure STRIPE_PUBLISHABLE_KEY in .env.public\n2. Configure STRIPE_SECRET_KEY in Firebase Functions env\n3. Deploy functions and restart the app"),
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
