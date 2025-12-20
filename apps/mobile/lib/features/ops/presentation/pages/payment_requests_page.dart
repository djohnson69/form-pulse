import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ops_provider.dart';

class PaymentRequestsPage extends ConsumerWidget {
  const PaymentRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Requests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (payments) {
          if (payments.isEmpty) {
            return const Center(child: Text('No payment requests yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final req = payments[index];
              final isPaid = req.status == 'paid';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.payment),
                  title: Text('\$${req.amount.toStringAsFixed(2)} ${req.currency}'),
                  subtitle: Text(req.description ?? req.status),
                  trailing: isPaid
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : TextButton(
                          onPressed: () async {
                            await ref
                                .read(opsRepositoryProvider)
                                .updatePaymentStatus(
                                  id: req.id,
                                  status: 'paid',
                                );
                            ref.invalidate(paymentRequestsProvider);
                          },
                          child: const Text('Mark paid'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    bool isSaving = false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Request payment',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final amount =
                                double.tryParse(amountController.text.trim());
                            if (amount == null || amount <= 0) return;
                            setState(() => isSaving = true);
                            await ref.read(opsRepositoryProvider).createPaymentRequest(
                                  amount: amount,
                                  description: descController.text.trim().isEmpty
                                      ? null
                                      : descController.text.trim(),
                                );
                            if (context.mounted) Navigator.of(context).pop(true);
                          },
                    child: Text(isSaving ? 'Saving...' : 'Create request'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    amountController.dispose();
    descController.dispose();
    if (result == true) {
      ref.invalidate(paymentRequestsProvider);
    }
  }
}
