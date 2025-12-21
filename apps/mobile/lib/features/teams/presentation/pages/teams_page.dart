import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../tasks/data/tasks_provider.dart';
import '../../data/teams_provider.dart';

class TeamsPage extends ConsumerWidget {
  const TeamsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateTeam(context, ref),
        icon: const Icon(Icons.group_add),
        label: const Text('New team'),
      ),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (teams) {
          if (teams.isEmpty) {
            return const Center(
              child: Text('No teams yet. Create one to group assignments.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.groups),
                  title: Text(team.name),
                  subtitle: Text(
                    team.description?.trim().isNotEmpty == true
                        ? team.description!.trim()
                        : 'No description',
                  ),
                  trailing: TextButton(
                    onPressed: () => _openMemberSheet(context, ref, team),
                    child: const Text('Members'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openCreateTeam(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool saving = false;
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
                  Text('Create team',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Team name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (nameController.text.trim().isEmpty) return;
                            setState(() => saving = true);
                            await ref
                                .read(teamsRepositoryProvider)
                                .createTeam(
                                  name: nameController.text.trim(),
                                  description:
                                      descController.text.trim().isEmpty
                                          ? null
                                          : descController.text.trim(),
                                );
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          },
                    child: Text(saving ? 'Saving...' : 'Save team'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    nameController.dispose();
    descController.dispose();
    if (result == true) {
      ref.invalidate(teamsProvider);
    }
  }

  Future<void> _openMemberSheet(
    BuildContext context,
    WidgetRef ref,
    Team team,
  ) async {
    final assignees = await ref.read(taskAssigneesProvider.future);
    final selected = await ref.read(teamMembersProvider(team.id).future);
    if (!context.mounted) return;
    final current = selected.toSet();
    bool saving = false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Members • ${team.name}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: assignees.map((assignee) {
                        final isSelected = current.contains(assignee.id);
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(assignee.name),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                current.add(assignee.id);
                              } else {
                                current.remove(assignee.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setState(() => saving = true);
                            await ref
                                .read(teamsRepositoryProvider)
                                .updateTeamMembers(
                                  team.id,
                                  current.toList(),
                                );
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          },
                    child: Text(saving ? 'Saving...' : 'Save members'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (result == true) {
      ref.invalidate(teamMembersProvider(team.id));
    }
  }
}
