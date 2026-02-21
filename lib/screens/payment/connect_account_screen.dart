import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_firebase.dart';
import '../../services/stripe_connect_service.dart';
import '../../services/stripe_oauth_handler.dart';

/// Screen for connecting a Stripe account (for professionals)
///
/// This screen allows professionals to:
/// - Connect their existing Stripe account via OAuth
/// - Create a new Stripe account
/// - View their connection status
///
/// OAuth flow is handled server-side by Firebase Functions.
class ConnectAccountScreen extends StatefulWidget {
  const ConnectAccountScreen({super.key});

  @override
  State<ConnectAccountScreen> createState() => _ConnectAccountScreenState();
}

class _ConnectAccountScreenState extends State<ConnectAccountScreen> {
  bool _loading = false;
  String? _errorMessage;
  String? _connectedAccountId;
  bool _accountReady = false;

  @override
  void initState() {
    super.initState();
    _loadConnectedAccount();
  }

  Future<void> _loadConnectedAccount() async {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loading = true);

    try {
      final doc = await AppFirebase.firestore
          .collection('stripe_connected_accounts')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final accountId = data['accountId'] as String?;

        if (accountId != null) {
          setState(() {
            _connectedAccountId = accountId;
          });

          // Check if account is ready
          final isReady = await StripeConnectService.isAccountReady(accountId);
          setState(() {
            _accountReady = isReady;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading account: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _connectExistingAccount() async {
    if (!StripeConnectService.isConfigured) {
      setState(() {
        _errorMessage =
            'Stripe Connect is not configured. Please contact support.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (AppFirebase.auth.currentUser?.uid == null) {
        throw Exception('User not authenticated');
      }

      // Launch OAuth flow via server-generated one-time state.
      await StripeConnectService.launchOAuthFlow();

      // Note: After OAuth, Stripe redirects to the return URL
      // The Firebase Function handles the callback and saves to Firestore
      // The user will need to return to the app to see the updated status
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'OAuth flow launched. Complete authorization in the browser, '
              'then return to the app to see your connected account.',
            ),
            duration: Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting account: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createNewAccount() async {
    if (!StripeConnectService.isConfigured) {
      setState(() {
        _errorMessage =
            'Stripe Connect is not configured. Please contact support.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = AppFirebase.auth.currentUser;
      final email = user?.email;

      if (user == null || email == null) {
        throw Exception('User not authenticated or email not available');
      }

      // Create connected account
      final accountId = await StripeConnectService.createConnectedAccount(
        email: email,
        type: 'standard',
        country: 'US', // Default, can be made configurable
      );

      // Create account link via Firebase Function.
      final accountLinkUrl =
          await StripeOAuthHandler.createAccountLinkViaFunction(
        accountId: accountId,
      );

      // Launch account link in browser
      final uri = Uri.parse(accountLinkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created! Complete onboarding in the browser to start accepting payments.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }

        // Reload account status
        await _loadConnectedAccount();
      } else {
        throw Exception('Could not launch account link');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating account: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Stripe Account'),
      ),
      body: _loading && _connectedAccountId == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Stripe Connect',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Accept payments for your services',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

                  // Account status
                  if (_connectedAccountId != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _accountReady
                                      ? Icons.check_circle
                                      : Icons.pending,
                                  color: _accountReady
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _accountReady
                                        ? 'Account Ready'
                                        : 'Account Pending',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _accountReady
                                  ? 'Your Stripe account is connected and ready to accept payments.'
                                  : 'Complete the onboarding process to start accepting payments.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_connectedAccountId != null) const SizedBox(height: 24),

                  // Connect existing account
                  if (_connectedAccountId == null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connect Existing Account',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'If you already have a Stripe account, connect it to start accepting payments.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed:
                                  _loading ? null : _connectExistingAccount,
                              icon: const Icon(Icons.link),
                              label: const Text('Connect Existing Account'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'You will be redirected to Stripe to '
                                      'authorize your existing account.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_connectedAccountId == null) const SizedBox(height: 16),

                  // Create new account
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _connectedAccountId == null
                                ? 'Create New Account'
                                : 'Update Account',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _connectedAccountId == null
                                ? 'Create a new Stripe account to accept payments for your professional services.'
                                : 'Update your account settings or complete onboarding.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _createNewAccount,
                            icon: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_circle_outline),
                            label: Text(
                              _connectedAccountId == null
                                  ? 'Create New Account'
                                  : 'Update Account',
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'How it works',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '- Connect your Stripe account to accept payments\n'
                          '- Customers pay you directly through the platform\n'
                          '- Funds are transferred to your bank account\n'
                          '- Platform fees are automatically deducted',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
