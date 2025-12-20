import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/partners_provider.dart';

class ClientEditorPage extends ConsumerStatefulWidget {
  const ClientEditorPage({this.existing, super.key});

  final Client? existing;

  @override
  ConsumerState<ClientEditorPage> createState() => _ClientEditorPageState();
}

class _ClientEditorPageState extends ConsumerState<ClientEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _websiteController = TextEditingController();
  final _jobSitesController = TextEditingController();
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _companyController.text = existing.companyName;
      _contactController.text = existing.contactName ?? '';
      _emailController.text = existing.email ?? '';
      _phoneController.text = existing.phoneNumber ?? '';
      _addressController.text = existing.address ?? '';
      _websiteController.text = existing.website ?? '';
      _jobSitesController.text =
          (existing.assignedJobSites ?? const []).join(', ');
      _isActive = existing.isActive;
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _jobSitesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Client' : 'New Client')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Company name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Primary contact',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(
                  labelText: 'Website',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jobSitesController,
                decoration: const InputDecoration(
                  labelText: 'Assigned job sites (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active client'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save client'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(partnersRepositoryProvider);
      final jobSites = _jobSitesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final existing = widget.existing;
      final client = Client(
        id: existing?.id ?? '',
        companyName: _companyController.text.trim(),
        contactName: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        email:
            _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phoneNumber:
            _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address:
            _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        website:
            _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        assignedJobSites: jobSites.isEmpty ? null : jobSites,
        isActive: _isActive,
        createdAt: existing?.createdAt ?? DateTime.now(),
        metadata: existing?.metadata,
      );
      final saved = existing == null
          ? await repo.createClient(client)
          : await repo.updateClient(client);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
