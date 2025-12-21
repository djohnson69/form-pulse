import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String? _categoryFilter;
  String? _locationFilter;
  String? _contactFilter;
  RealtimeChannel? _assetsChannel;

  @override
  void initState() {
    super.initState();
    _subscribeToAssetChanges();
  }

  @override
  void dispose() {
    _assetsChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToAssetChanges() {
    final client = Supabase.instance.client;
    _assetsChannel = client.channel('assets-changes')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'equipment',
        callback: (_) {
          if (!mounted) return;
          ref.invalidate(equipmentProvider);
        },
      )
      ..subscribe();
  }

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
          final categories = assets
              .map((asset) => asset.category)
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final locations = assets
              .map((asset) => asset.currentLocation)
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final contacts = assets
              .map((asset) => asset.contactName)
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
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
              if (categories.isNotEmpty ||
                  locations.isNotEmpty ||
                  contacts.isNotEmpty)
                const SizedBox(height: 12),
              if (categories.isNotEmpty) _buildCategoryFilter(categories),
              if (locations.isNotEmpty) const SizedBox(height: 8),
              if (locations.isNotEmpty) _buildLocationFilter(locations),
              if (contacts.isNotEmpty) const SizedBox(height: 8),
              if (contacts.isNotEmpty) _buildContactFilter(contacts),
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
          (asset.rfidTag ?? '').toLowerCase().contains(query) ||
          (asset.currentLocation ?? '').toLowerCase().contains(query) ||
          (asset.assignedTo ?? '').toLowerCase().contains(query) ||
          (asset.contactName ?? '').toLowerCase().contains(query) ||
          (asset.contactEmail ?? '').toLowerCase().contains(query) ||
          (asset.contactPhone ?? '').toLowerCase().contains(query);
      final matchesActive = !_activeOnly || asset.isActive;
      final matchesMaintenance = !_maintenanceOnly || asset.isMaintenanceDue;
      final matchesCategory =
          _categoryFilter == null || _categoryFilter == asset.category;
      final matchesLocation =
          _locationFilter == null || _locationFilter == asset.currentLocation;
      final matchesContact =
          _contactFilter == null || _contactFilter == asset.contactName;
      return matchesQuery &&
          matchesActive &&
          matchesMaintenance &&
          matchesCategory &&
          matchesLocation &&
          matchesContact;
    }).toList();
  }

  Widget _buildCategoryFilter(List<String> categories) {
    return DropdownButtonFormField<String?>(
      key: ValueKey(_categoryFilter),
      initialValue: _categoryFilter,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All categories')),
        ...categories.map(
          (category) => DropdownMenuItem(
            value: category,
            child: Text(category),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _categoryFilter = value),
    );
  }

  Widget _buildLocationFilter(List<String> locations) {
    return DropdownButtonFormField<String?>(
      key: ValueKey(_locationFilter),
      initialValue: _locationFilter,
      decoration: const InputDecoration(
        labelText: 'Location',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All locations')),
        ...locations.map(
          (location) => DropdownMenuItem(
            value: location,
            child: Text(location),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _locationFilter = value),
    );
  }

  Widget _buildContactFilter(List<String> contacts) {
    return DropdownButtonFormField<String?>(
      key: ValueKey(_contactFilter),
      initialValue: _contactFilter,
      decoration: const InputDecoration(
        labelText: 'Contact',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All contacts')),
        ...contacts.map(
          (contact) => DropdownMenuItem(
            value: contact,
            child: Text(contact),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _contactFilter = value),
    );
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
