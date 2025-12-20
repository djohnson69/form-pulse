import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/partners_provider.dart';
import 'vendor_editor_page.dart';

class VendorsPage extends ConsumerStatefulWidget {
  const VendorsPage({super.key});

  @override
  ConsumerState<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends ConsumerState<VendorsPage> {
  String _query = '';
  bool _activeOnly = false;

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(vendorsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Vendor'),
      ),
      body: vendorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _ErrorView(error: e.toString()),
        data: (vendors) {
          final filtered = _applyFilters(vendors);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search vendors',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active only'),
                value: _activeOnly,
                onChanged: (value) => setState(() => _activeOnly = value),
              ),
              if (filtered.isEmpty)
                const _EmptyState()
              else
                ...filtered.map(
                  (vendor) => _VendorCard(
                    vendor: vendor,
                    onTap: () => _openEditor(context, existing: vendor),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  List<Vendor> _applyFilters(List<Vendor> vendors) {
    final query = _query.toLowerCase();
    return vendors.where((vendor) {
      final matchesQuery = query.isEmpty ||
          vendor.companyName.toLowerCase().contains(query) ||
          (vendor.contactName ?? '').toLowerCase().contains(query) ||
          (vendor.email ?? '').toLowerCase().contains(query);
      final matchesActive = !_activeOnly || vendor.isActive;
      return matchesQuery && matchesActive;
    }).toList();
  }

  Future<void> _openEditor(BuildContext context, {Vendor? existing}) async {
    final result = await Navigator.of(context).push<Vendor?>(
      MaterialPageRoute(builder: (_) => VendorEditorPage(existing: existing)),
    );
    if (!mounted) return;
    if (result != null) {
      ref.invalidate(vendorsProvider);
    }
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.vendor, required this.onTap});

  final Vendor vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: vendor.isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.grey.shade200,
          child: Icon(
            Icons.handshake,
            color: vendor.isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
        ),
        title: Text(vendor.companyName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((vendor.serviceCategory ?? '').isNotEmpty)
              Text(vendor.serviceCategory!),
            if ((vendor.email ?? '').isNotEmpty)
              Text(vendor.email!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'No vendors found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Add vendors to manage assignments and communication.'),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error),
        ),
      ),
    );
  }
}
