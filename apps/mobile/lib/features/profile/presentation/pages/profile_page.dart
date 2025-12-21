import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../tasks/data/tasks_provider.dart';
import '../../../training/data/training_provider.dart';

class ProfileSummary {
  ProfileSummary({
    required this.id,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.phone,
  });

  final String id;
  final String email;
  final UserRole role;
  final String? firstName;
  final String? lastName;
  final String? phone;

  String get displayName {
    final parts = [firstName, lastName].whereType<String>().toList();
    final name = parts.join(' ').trim();
    return name.isEmpty ? email : name;
  }
}

final _employeeIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;
  final res = await client
      .from('employees')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();
  return res?['id']?.toString();
});

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  ProfileSummary? _profile;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await client
          .from('profiles')
          .select('id, email, first_name, last_name, phone, role')
          .eq('id', user.id)
          .maybeSingle();
      if (res == null) {
        setState(() => _loading = false);
        return;
      }
      final rawRole = res['role']?.toString() ?? UserRole.viewer.name;
      final role = UserRole.values.firstWhere(
        (r) => r.name == rawRole,
        orElse: () => UserRole.viewer,
      );
      final profile = ProfileSummary(
        id: res['id'] as String,
        email: res['email']?.toString() ?? user.email ?? '',
        role: role,
        firstName: res['first_name']?.toString(),
        lastName: res['last_name']?.toString(),
        phone: res['phone']?.toString(),
      );
      _firstNameController.text = profile.firstName ?? '';
      _lastNameController.text = profile.lastName ?? '';
      _phoneController.text = profile.phone ?? '';
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final profile = _profile;
    if (profile == null) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('profiles').update({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', profile.id);
      await _loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scheduleTraining(Training training) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: training.nextRecertificationDate ??
          training.expirationDate ??
          DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    final repo = ref.read(trainingRepositoryProvider);
    final metadata = {
      ...?training.metadata,
      'self_scheduled_by': Supabase.instance.client.auth.currentUser?.id,
      'self_scheduled_at': DateTime.now().toIso8601String(),
    };
    await repo.updateTrainingRecord(
      trainingId: training.id,
      nextRecertificationDate: picked,
      metadata: metadata,
    );
    ref.invalidate(trainingRecordsProvider(training.employeeId));
  }

  Future<void> _rescheduleTask(Task task) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    await ref.read(tasksRepositoryProvider).updateTask(
          taskId: task.id,
          dueDate: picked,
        );
    ref.invalidate(tasksProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final profile = _profile;
    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('Profile not available.')),
      );
    }
    final employeeIdAsync = ref.watch(_employeeIdProvider);
    final tasksAsync = ref.watch(tasksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Schedule')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.person, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Chip(
                  label: Text(profile.role.displayName),
                  avatar: const Icon(Icons.badge, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile details',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveProfile,
                      child: Text(_saving ? 'Saving...' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Upcoming training',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          employeeIdAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Unable to load training: $e'),
            data: (employeeId) {
              if (employeeId == null) {
                return const Text('No employee record linked to your account.');
              }
              final trainingAsync =
                  ref.watch(trainingRecordsProvider(employeeId));
              return trainingAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Unable to load training: $e'),
                data: (records) {
                  if (records.isEmpty) {
                    return const Text('No training records assigned.');
                  }
                  final upcoming = records
                      .where((record) =>
                          record.expirationDate != null ||
                          record.nextRecertificationDate != null)
                      .toList();
                  if (upcoming.isEmpty) {
                    return const Text('No upcoming training deadlines.');
                  }
                  return Column(
                    children: upcoming.map((record) {
                      final dueDate =
                          record.nextRecertificationDate ?? record.expirationDate;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.school),
                          title: Text(record.trainingName),
                          subtitle: dueDate == null
                              ? const Text('No deadline set')
                              : Text('Due ${_formatDate(dueDate)}'),
                          trailing: TextButton(
                            onPressed: () => _scheduleTraining(record),
                            child: const Text('Schedule'),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Upcoming tasks', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Unable to load tasks: $e'),
            data: (tasks) {
              final userId = Supabase.instance.client.auth.currentUser?.id;
              final assigned = tasks
                  .where((task) => task.assignedTo == userId)
                  .toList();
              if (assigned.isEmpty) {
                return const Text('No tasks assigned to you.');
              }
              return Column(
                children: assigned.map((task) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.checklist),
                      title: Text(task.title),
                      subtitle: Text(task.dueDate == null
                          ? 'No due date'
                          : 'Due ${_formatDate(task.dueDate!)}'),
                      trailing: TextButton(
                        onPressed: task.isComplete
                            ? null
                            : () => _rescheduleTask(task),
                        child: const Text('Reschedule'),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}
