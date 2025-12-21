import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
              final checkoutUrl = _checkoutUrl(req);
              final statusLabel = _formatStatus(req.status);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.payment),
                  title: Text('\$${req.amount.toStringAsFixed(2)} ${req.currency}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.description ?? 'Status: $statusLabel'),
                      const SizedBox(height: 4),
                      Text(
                        checkoutUrl == null
                            ? 'Status: $statusLabel'
                            : 'Status: $statusLabel • Link ready',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: isPaid
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : PopupMenuButton<_PaymentAction>(
                          tooltip: 'Actions',
                          onSelected: (action) => _handleAction(
                            context,
                            ref,
                            action,
                            req,
                            checkoutUrl,
                          ),
                          itemBuilder: (_) => _buildActions(
                            hasLink: checkoutUrl != null,
                          ),
                          icon: const Icon(Icons.more_vert),
                        ),
                  isThreeLine: true,
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

  List<PopupMenuEntry<_PaymentAction>> _buildActions({
    required bool hasLink,
  }) {
    final entries = <PopupMenuEntry<_PaymentAction>>[];
    if (hasLink) {
      entries.add(
        const PopupMenuItem(
          value: _PaymentAction.openLink,
          child: Text('Open payment link'),
        ),
      );
      entries.add(
        const PopupMenuItem(
          value: _PaymentAction.shareLink,
          child: Text('Share payment link'),
        ),
      );
    } else {
      entries.add(
        const PopupMenuItem(
          value: _PaymentAction.generateLink,
          child: Text('Generate payment link'),
        ),
      );
    }
    entries.add(
      const PopupMenuItem(
        value: _PaymentAction.markPaid,
        child: Text('Mark paid'),
      ),
    );
    return entries;
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _PaymentAction action,
    PaymentRequest req,
    String? checkoutUrl,
  ) async {
    final repo = ref.read(opsRepositoryProvider);
    switch (action) {
      case _PaymentAction.generateLink:
        try {
          await repo.createPaymentCheckout(request: req);
          ref.invalidate(paymentRequestsProvider);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment link failed: $e')),
          );
        }
        break;
      case _PaymentAction.openLink:
        if (checkoutUrl == null) return;
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        break;
      case _PaymentAction.shareLink:
        if (checkoutUrl == null) return;
        await SharePlus.instance.share(
          ShareParams(text: 'Payment link: $checkoutUrl'),
        );
        break;
      case _PaymentAction.markPaid:
        await repo.updatePaymentStatus(id: req.id, status: 'paid');
        ref.invalidate(paymentRequestsProvider);
        break;
    }
  }

  String? _checkoutUrl(dynamic req) {
    final meta = req.metadata;
    final raw = meta?['checkoutUrl'] ?? meta?['checkout_url'];
    final url = raw?.toString();
    return (url == null || url.isEmpty) ? null : url;
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ');
  }
}

enum _PaymentAction { generateLink, openLink, shareLink, markPaid }
