import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:intl/intl.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../app_firebase.dart';
import '../../env.dart';
import '../../models/professional_service.dart';
import '../../services/stripe_service.dart';

/// Screen for booking and paying for a professional service
class BookServiceScreen extends StatefulWidget {
  const BookServiceScreen({
    super.key,
    required this.professional,
    this.hours = 2.0,
  });

  final ProfessionalService professional;
  final double hours;

  @override
  State<BookServiceScreen> createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends State<BookServiceScreen> {
  double _hours = 2.0;
  DateTime? _selectedDate;
  String? _notes;
  bool _processing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hours = widget.hours;
    _selectedDate = DateTime.now().add(const Duration(days: 7));
    _initializeStripe();
  }

  Future<void> _initializeStripe() async {
    try {
      await StripeService.initialize();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize payment system: $e';
        });
      }
    }
  }

  double get _totalAmount => widget.professional.ratePerHour * _hours;
  double get _platformFee => _totalAmount * 0.10; // 10% platform fee
  double get _grandTotal => _totalAmount;

  Future<void> _bookAndPay() async {
    if (!StripeService.isInitialized) {
      setState(() {
        _errorMessage =
            'Payment system not available. Please configure STRIPE_PUBLISHABLE_KEY.';
      });
      return;
    }

    if (widget.professional.stripeAccountId == null) {
      setState(() {
        _errorMessage =
            'Professional has not connected their Stripe account yet.';
      });
      return;
    }

    if (_selectedDate == null) {
      setState(() {
        _errorMessage = 'Please select a service date.';
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
        throw Exception('User not authenticated');
      }

      final idToken = await AppFirebase.auth.currentUser!.getIdToken();

      // Create payment intent via Firebase Function
      final functionsUrl = Env.firebaseFunctionsUrl;
      final response = await http.post(
        Uri.parse('$functionsUrl/stripe/connect/create-payment-intent'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'accountId': widget.professional.stripeAccountId,
          'amount': _grandTotal,
          'currency': 'usd',
          'applicationFeeAmount': _platformFee,
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to create payment intent');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final clientSecret = data['data']?['clientSecret'] as String?;
      final paymentIntentId = data['data']?['paymentIntentId'] as String?;

      if (clientSecret == null) {
        throw Exception('No client secret in response');
      }

      // Initialize and present payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: widget.professional.name,
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // Payment successful - update booking status
      if (paymentIntentId != null) {
        await _updateBookingStatus(paymentIntentId, 'confirmed');
      }

      if (!mounted) return;

      Navigator.of(context).pop(true); // Return success

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Booking confirmed! ${widget.professional.name} will contact you soon.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } on StripeException catch (e) {
      setState(() {
        _errorMessage = e.error.message ?? 'Payment failed. Please try again.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Booking failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _updateBookingStatus(
      String paymentIntentId, String status) async {
    try {
      final uid = AppFirebase.auth.currentUser?.uid;
      if (uid == null) return;

      final bookings = await AppFirebase.firestore
          .collection('service_bookings')
          .where('userId', isEqualTo: uid)
          .where('paymentIntentId', isEqualTo: paymentIntentId)
          .limit(1)
          .get();

      if (bookings.docs.isNotEmpty) {
        await bookings.docs.first.reference.update({
          'status': status,
          'professionalName': widget.professional.name,
          'hours': _hours,
          'serviceDate': _selectedDate,
          'notes': _notes,
          if (status == 'confirmed')
            'confirmedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      // Non-critical error, don't fail the payment
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Professional info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        widget.professional.initials,
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.professional.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            widget.professional.specialty,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Service details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Hours selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hours:'),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _hours > 1
                                  ? () => setState(() => _hours -= 1)
                                  : null,
                            ),
                            Text(
                              _hours.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setState(() => _hours += 0.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Date selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Service Date:'),
                        OutlinedButton.icon(
                          onPressed: _selectDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            _selectedDate != null
                                ? DateFormat('MMM dd, yyyy')
                                    .format(_selectedDate!)
                                : 'Select date',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'Any special requests or details...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) => setState(() => _notes = value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pricing breakdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pricing',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${_hours.toStringAsFixed(1)} hours @ ${widget.professional.formattedRate}'),
                        Text(_totalAmount.toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Platform fee (10%)',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          '\$${_platformFee.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          '\$${_grandTotal.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
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

            // Book button
            ElevatedButton(
              onPressed:
                  _processing || widget.professional.stripeAccountId == null
                      ? null
                      : _bookAndPay,
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
                      'Book & Pay \$${_grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),

            if (widget.professional.stripeAccountId == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This professional has not connected their payment account yet. '
                        'Please contact them directly.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
