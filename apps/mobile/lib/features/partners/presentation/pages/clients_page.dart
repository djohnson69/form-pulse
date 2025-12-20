import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/partners_provider.dart';
import 'client_editor_page.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  String _query = '';
  bool _activeOnly = false;

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(clientsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Client'),
      ),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _ErrorView(error: e.toString()),
        data: (clients) {
          final filtered = _applyFilters(clients);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search clients',
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
                  (client) => _ClientCard(
                    client: client,
                    onTap: () => _openEditor(context, existing: client),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  List<Client> _applyFilters(List<Client> clients) {
    final query = _query.toLowerCase();
    return clients.where((client) {
      final matchesQuery = query.isEmpty ||
          client.companyName.toLowerCase().contains(query) ||
          (client.contactName ?? '').toLowerCase().contains(query) ||
          (client.email ?? '').toLowerCase().contains(query);
      final matchesActive = !_activeOnly || client.isActive;
      return matchesQuery && matchesActive;
    }).toList();
  }

  Future<void> _openEditor(BuildContext context, {Client? existing}) async {
    final result = await Navigator.of(context).push<Client?>(
      MaterialPageRoute(builder: (_) => ClientEditorPage(existing: existing)),
    );
    if (!mounted) return;
    if (result != null) {
      ref.invalidate(clientsProvider);
    }
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client, required this.onTap});

  final Client client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: client.isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.grey.shade200,
          child: Icon(
            Icons.business,
            color: client.isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
        ),
        title: Text(client.companyName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((client.contactName ?? '').isNotEmpty)
              Text(client.contactName!),
            if ((client.email ?? '').isNotEmpty)
              Text(client.email!, style: Theme.of(context).textTheme.bodySmall),
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
              'No clients found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Add clients to enable portal communication and sharing.'),
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
