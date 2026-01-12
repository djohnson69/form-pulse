import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/training_provider.dart';
import 'employee_editor_page.dart';
import 'training_editor_page.dart';

class EmployeeDetailPage extends ConsumerStatefulWidget {
  const EmployeeDetailPage({required this.employee, super.key});

  final Employee employee;

  @override
  ConsumerState<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends ConsumerState<EmployeeDetailPage> {
  late Employee _employee;

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
  }

  @override
  Widget build(BuildContext context) {
    final trainingAsync = ref.watch(trainingRecordsProvider(_employee.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(_employee.fullName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editEmployee,
          ),
          IconButton(
            icon: const Icon(Icons.school),
            onPressed: _assignTraining,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EmployeeSummaryCard(employee: _employee),
          const SizedBox(height: 12),
          Text('Training History', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          trainingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Unable to load training: $e'),
            data: (records) {
              if (records.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'No training records',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('Assign training to start tracking certifications.'),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: records
                    .map(
                      (record) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.school),
                          title: Text(record.trainingName),
                          subtitle: Text(record.status.displayName),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _editTraining(record),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editEmployee() async {
    final updated = await Navigator.of(context).push<Employee?>(
      MaterialPageRoute(
        builder: (_) => EmployeeEditorPage(existing: _employee),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _employee = updated);
    ref.invalidate(employeesProvider);
  }

  Future<void> _assignTraining() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainingEditorPage(employee: _employee),
      ),
    );
    if (!mounted) return;
    ref.invalidate(trainingRecordsProvider(_employee.id));
    ref.invalidate(trainingRecordsProvider(null));
  }

  Future<void> _editTraining(Training training) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainingEditorPage(
          existing: training,
          employee: _employee,
        ),
      ),
    );
    if (!mounted) return;
    ref.invalidate(trainingRecordsProvider(_employee.id));
    ref.invalidate(trainingRecordsProvider(null));
  }
}

class _EmployeeSummaryCard extends StatelessWidget {
  const _EmployeeSummaryCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(employee.initials)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee.fullName,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        employee.email,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(employee.isActive ? 'Active' : 'Inactive'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if ((employee.position ?? '').isNotEmpty)
                  _InfoPill(label: 'Job', value: employee.position!),
                if ((employee.department ?? '').isNotEmpty)
                  _InfoPill(label: 'Department', value: employee.department!),
                if ((employee.jobSiteName ?? '').isNotEmpty)
                  _InfoPill(label: 'Site', value: employee.jobSiteName!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 6),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
