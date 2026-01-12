import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../data/ops_provider.dart';
class PaymentRequestsPage extends ConsumerStatefulWidget {
  const PaymentRequestsPage({super.key});

  @override
  ConsumerState<PaymentRequestsPage> createState() => _PaymentRequestsPageState();
}

class _PaymentRequestsPageState extends ConsumerState<PaymentRequestsPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  _PaymentMethod _paymentMethod = _PaymentMethod.card;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentRequestsProvider);
    final colors = _PaymentColors.fromTheme(Theme.of(context));
    final payments = paymentsAsync.asData?.value ?? const <PaymentRequest>[];
    final entries = _entriesFromRequests(payments);
    final totals = _PaymentTotals.fromEntries(entries);

    return Scaffold(
      backgroundColor: colors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (paymentsAsync.isLoading) const LinearProgressIndicator(),
          if (paymentsAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ErrorBanner(message: paymentsAsync.error.toString()),
            ),
          _Header(muted: colors.muted),
          const SizedBox(height: 16),
          if (entries.isEmpty && !paymentsAsync.isLoading) ...[
            _EmptyState(
              colors: colors,
              onCreate: () => _openCreate(),
            ),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final left = _NewPaymentCard(
                colors: colors,
                amountController: _amountController,
                descriptionController: _descriptionController,
                paymentMethod: _paymentMethod,
                onMethodChanged: (method) =>
                    setState(() => _paymentMethod = method),
                onSubmit: _isSubmitting ? null : _submitPayment,
                isSubmitting: _isSubmitting,
              );
              final right = _RecentPaymentsCard(
                colors: colors,
                entries: entries,
                totals: totals,
              );
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 16),
                    Expanded(child: right),
                  ],
                );
              }
              return Column(
                children: [
                  left,
                  const SizedBox(height: 16),
                  right,
                ],
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _submitPayment() async {
    final amount = double.tryParse(_amountController.text.trim());
    final description = _descriptionController.text.trim();
    if (amount == null || amount <= 0 || description.isEmpty) {
      _showSnackBar('Please fill in all required fields');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref.read(opsRepositoryProvider).createPaymentRequest(
            amount: amount,
            description: description,
          );
      _amountController.clear();
      _descriptionController.clear();
      setState(() => _paymentMethod = _PaymentMethod.card);
      ref.invalidate(paymentRequestsProvider);
      _showSnackBar('Payment request submitted');
    } catch (e) {
      _showSnackBar('Payment request failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _openCreate() {
    setState(() => _paymentMethod = _PaymentMethod.card);
    _amountController.clear();
    _descriptionController.clear();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<_PaymentEntry> _entriesFromRequests(List<PaymentRequest> requests) {
    return requests.map((req) {
      final status = req.status;
      final description = req.description ?? 'Payment request';
      return _PaymentEntry(
        id: req.id,
        amount: req.amount,
        status: _normalizeStatus(status),
        date: req.requestedAt,
        project: description,
        method: 'Card',
      );
    }).toList();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF111827);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Requests',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Request payment from the job site and get paid before leaving',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
        ),
      ],
    );
  }
}

class _NewPaymentCard extends StatelessWidget {
  const _NewPaymentCard({
    required this.colors,
    required this.amountController,
    required this.descriptionController,
    required this.paymentMethod,
    required this.onMethodChanged,
    required this.onSubmit,
    required this.isSubmitting,
  });

  final _PaymentColors colors;
  final TextEditingController amountController;
  final TextEditingController descriptionController;
  final _PaymentMethod paymentMethod;
  final ValueChanged<_PaymentMethod> onMethodChanged;
  final VoidCallback? onSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final timestamp = DateFormat('M/d/yyyy h:mm a').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, color: colors.success),
              const SizedBox(width: 8),
              Text(
                'New Payment Request',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.title,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label: 'Amount *',
            colors: colors,
            child: TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0.00',
                filled: true,
                fillColor: colors.subtleSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Project / Description *',
            colors: colors,
            child: TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter project name and payment description...',
                filled: true,
                fillColor: colors.subtleSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Payment Method',
            colors: colors,
            child: Row(
              children: _PaymentMethod.values.map((method) {
                final selected = paymentMethod == method;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: () => onMethodChanged(method),
                      style: TextButton.styleFrom(
                        backgroundColor:
                            selected ? colors.success : colors.subtleSurface,
                        foregroundColor:
                            selected ? Colors.white : colors.body,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_methodLabel(method)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Attachments (Optional)',
            colors: colors,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.dashedBorder, width: 2),
              ),
              child: Column(
                children: [
                  Icon(Icons.photo_camera_outlined, color: colors.muted, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Upload invoices, photos, or receipts',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.muted,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send_outlined),
              label: Text(isSubmitting ? 'Submitting...' : 'Request Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'GPS: Enabled | Timestamp: $timestamp',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.muted,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RecentPaymentsCard extends StatelessWidget {
  const _RecentPaymentsCard({
    required this.colors,
    required this.entries,
    required this.totals,
  });

  final _PaymentColors colors;
  final List<_PaymentEntry> entries;
  final _PaymentTotals totals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Recent Payment Requests',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.title,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...entries.map((entry) => _PaymentCard(entry: entry, colors: colors)),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryTile(
                label: 'Paid',
                value: _formatCurrency(totals.paid),
                color: colors.success,
                colors: colors,
              ),
              const SizedBox(width: 8),
              _SummaryTile(
                label: 'Approved',
                value: _formatCurrency(totals.approved),
                color: colors.primary,
                colors: colors,
              ),
              const SizedBox(width: 8),
              _SummaryTile(
                label: 'Pending',
                value: _formatCurrency(totals.pending),
                color: colors.warning,
                colors: colors,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.entry, required this.colors});

  final _PaymentEntry entry;
  final _PaymentColors colors;

  @override
  Widget build(BuildContext context) {
    final statusStyle = colors.statusStyles[entry.status]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.subtleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatCurrency(entry.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.title,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.project,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.muted,
                        ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusStyle.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusStyle.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusStyle.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.credit_card_outlined,
                  size: 14, color: colors.muted),
              const SizedBox(width: 4),
              Text(
                entry.method,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                    ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.schedule_outlined,
                  size: 14, color: colors.muted),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM d, yyyy').format(entry.date),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
  });

  final String label;
  final String value;
  final Color color;
  final _PaymentColors colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.subtleSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.colors,
    required this.child,
  });

  final String label;
  final _PaymentColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.body,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF7F1D1D)),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PaymentMethod { card, ach, check }

String _methodLabel(_PaymentMethod method) {
  switch (method) {
    case _PaymentMethod.ach:
      return 'ACH';
    case _PaymentMethod.check:
      return 'Check';
    default:
      return 'Card';
  }
}

class _PaymentEntry {
  const _PaymentEntry({
    required this.id,
    required this.amount,
    required this.status,
    required this.date,
    required this.project,
    required this.method,
  });

  final String id;
  final double amount;
  final _PaymentStatus status;
  final DateTime date;
  final String project;
  final String method;
}

class _PaymentTotals {
  const _PaymentTotals({
    required this.paid,
    required this.approved,
    required this.pending,
  });

  final double paid;
  final double approved;
  final double pending;

  factory _PaymentTotals.fromEntries(List<_PaymentEntry> entries) {
    double paid = 0;
    double approved = 0;
    double pending = 0;
    for (final entry in entries) {
      switch (entry.status) {
        case _PaymentStatus.paid:
          paid += entry.amount;
          break;
        case _PaymentStatus.approved:
          approved += entry.amount;
          break;
        case _PaymentStatus.pending:
          pending += entry.amount;
          break;
      }
    }
    return _PaymentTotals(paid: paid, approved: approved, pending: pending);
  }
}

enum _PaymentStatus { paid, approved, pending }

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors, required this.onCreate});

  final _PaymentColors colors;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No payment requests yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.title,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submit a payment request to track approvals and payouts.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.muted),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('New payment request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentColors {
  const _PaymentColors({
    required this.background,
    required this.surface,
    required this.subtleSurface,
    required this.border,
    required this.dashedBorder,
    required this.muted,
    required this.title,
    required this.body,
    required this.primary,
    required this.success,
    required this.warning,
    required this.statusStyles,
  });

  final Color background;
  final Color surface;
  final Color subtleSurface;
  final Color border;
  final Color dashedBorder;
  final Color muted;
  final Color title;
  final Color body;
  final Color primary;
  final Color success;
  final Color warning;
  final Map<_PaymentStatus, _StatusStyle> statusStyles;

  factory _PaymentColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF2563EB);
    const success = Color(0xFF16A34A);
    const warning = Color(0xFFF59E0B);
    return _PaymentColors(
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      subtleSurface:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      dashedBorder: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      title: isDark ? Colors.white : const Color(0xFF111827),
      body: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      primary: primary,
      success: success,
      warning: warning,
      statusStyles: {
        _PaymentStatus.paid: _StatusStyle(
          label: 'paid',
          background: success.withValues(alpha: isDark ? 0.25 : 0.2),
          foreground: isDark ? const Color(0xFF4ADE80) : success,
        ),
        _PaymentStatus.approved: _StatusStyle(
          label: 'approved',
          background: primary.withValues(alpha: isDark ? 0.25 : 0.2),
          foreground: isDark ? const Color(0xFF93C5FD) : primary,
        ),
        _PaymentStatus.pending: _StatusStyle(
          label: 'pending',
          background: warning.withValues(alpha: isDark ? 0.25 : 0.2),
          foreground: isDark ? const Color(0xFFFBBF24) : warning,
        ),
      },
    );
  }
}

_PaymentStatus _normalizeStatus(String raw) {
  final value = raw.toLowerCase();
  if (value.contains('paid')) return _PaymentStatus.paid;
  if (value.contains('approved')) return _PaymentStatus.approved;
  return _PaymentStatus.pending;
}

String _formatCurrency(double amount) {
  final format = NumberFormat.currency(symbol: '\$');
  return format.format(amount);
}
