import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ops_provider.dart';

class GuestInvitesPage extends ConsumerWidget {
  const GuestInvitesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(guestInvitesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Guest Access')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Invite guest'),
      ),
      body: invitesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (invites) {
          if (invites.isEmpty) {
            return const Center(child: Text('No guest invites yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            itemBuilder: (context, index) {
              final invite = invites[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(invite.email),
                  subtitle: Text(invite.status.toUpperCase()),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    final roleController = TextEditingController();
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
                  Text('Invite guest',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: roleController,
                    decoration: const InputDecoration(
                      labelText: 'Role (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (emailController.text.trim().isEmpty) return;
                            setState(() => isSaving = true);
                            await ref.read(opsRepositoryProvider).createGuestInvite(
                                  email: emailController.text.trim(),
                                  role: roleController.text.trim().isEmpty
                                      ? null
                                      : roleController.text.trim(),
                                );
                            if (context.mounted) Navigator.of(context).pop(true);
                          },
                    child: Text(isSaving ? 'Saving...' : 'Send invite'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    emailController.dispose();
    roleController.dispose();
    if (result == true) {
      ref.invalidate(guestInvitesProvider);
    }
  }
}
