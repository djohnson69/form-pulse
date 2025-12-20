import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/assets_provider.dart';
import 'asset_detail_page.dart';
import 'asset_editor_page.dart';

class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({super.key});

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  String _query = '';
  bool _activeOnly = true;
  bool _maintenanceOnly = false;

  @override
  Widget build(BuildContext context) {
    final equipmentAsync = ref.watch(equipmentProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(equipmentProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Asset'),
      ),
      body: equipmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _ErrorView(error: e.toString()),
        data: (assets) {
          final filtered = _applyFilters(assets);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search assets',
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Maintenance due only'),
                value: _maintenanceOnly,
                onChanged: (value) => setState(() => _maintenanceOnly = value),
              ),
              if (filtered.isEmpty)
                const _EmptyState()
              else
                ...filtered.map(
                  (asset) => _AssetCard(
                    asset: asset,
                    onTap: () => _openDetail(context, asset),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  List<Equipment> _applyFilters(List<Equipment> assets) {
    final query = _query.toLowerCase();
    return assets.where((asset) {
      final matchesQuery = query.isEmpty ||
          asset.name.toLowerCase().contains(query) ||
          (asset.category ?? '').toLowerCase().contains(query) ||
          (asset.serialNumber ?? '').toLowerCase().contains(query) ||
          (asset.rfidTag ?? '').toLowerCase().contains(query);
      final matchesActive = !_activeOnly || asset.isActive;
      final matchesMaintenance = !_maintenanceOnly || asset.isMaintenanceDue;
      return matchesQuery && matchesActive && matchesMaintenance;
    }).toList();
  }

  Future<void> _openEditor(BuildContext context, {Equipment? existing}) async {
    final result = await Navigator.of(context).push<Equipment?>(
      MaterialPageRoute(builder: (_) => AssetEditorPage(existing: existing)),
    );
    if (!mounted) return;
    if (result != null) {
      ref.invalidate(equipmentProvider);
    }
  }

  Future<void> _openDetail(BuildContext context, Equipment asset) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AssetDetailPage(asset: asset)),
    );
    if (!mounted) return;
    ref.invalidate(equipmentProvider);
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset, required this.onTap});

  final Equipment asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final maintenanceDue = asset.isMaintenanceDue;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: maintenanceDue
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.build,
            color: maintenanceDue
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(asset.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((asset.category ?? '').isNotEmpty) Text(asset.category!),
            if ((asset.serialNumber ?? '').isNotEmpty)
              Text('SN: ${asset.serialNumber}'),
            if (maintenanceDue)
              Text(
                'Maintenance due',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
              'No assets found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Add equipment to start tracking inspections and incidents.'),
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
