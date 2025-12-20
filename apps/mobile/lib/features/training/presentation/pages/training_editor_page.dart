import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/training_provider.dart';

class TrainingEditorPage extends ConsumerStatefulWidget {
  const TrainingEditorPage({this.existing, this.employee, super.key});

  final Training? existing;
  final Employee? employee;

  @override
  ConsumerState<TrainingEditorPage> createState() => _TrainingEditorPageState();
}

class _TrainingEditorPageState extends ConsumerState<TrainingEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _trainingNameController = TextEditingController();
  final _trainingTypeController = TextEditingController();
  final _instructorController = TextEditingController();
  final _locationController = TextEditingController();
  final _ceuController = TextEditingController();
  final _scoreController = TextEditingController();
  final _certificateUrlController = TextEditingController();
  final _materialsController = TextEditingController();
  final _documentsController = TextEditingController();
  final _assignedRoleController = TextEditingController();
  final _assignedJobController = TextEditingController();
  final _assignedSiteController = TextEditingController();
  final _assignedTenureController = TextEditingController();

  TrainingStatus _status = TrainingStatus.notStarted;
  DateTime? _completedDate;
  DateTime? _expirationDate;
  DateTime? _recertDate;
  String? _employeeId;
  String? _employeeName;
  bool _saving = false;
  bool _bulkAssign = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final employee = widget.employee;
    if (existing != null) {
      _trainingNameController.text = existing.trainingName;
      _trainingTypeController.text = existing.trainingType ?? '';
      _instructorController.text = existing.instructorName ?? '';
      _locationController.text = existing.location ?? '';
      _ceuController.text =
          existing.ceuCredits != null ? existing.ceuCredits!.toString() : '';
      _scoreController.text =
          existing.score != null ? existing.score!.toString() : '';
      _certificateUrlController.text = existing.certificateUrl ?? '';
      _materialsController.text = (existing.materials ?? []).join(', ');
      _documentsController.text = (existing.documents ?? []).join(', ');
      _assignedRoleController.text = existing.assignedRole ?? '';
      _assignedJobController.text = existing.assignedJob ?? '';
      _assignedSiteController.text = existing.assignedSite ?? '';
      _assignedTenureController.text = existing.assignedTenureDays != null
          ? existing.assignedTenureDays!.toString()
          : '';
      _status = existing.status;
      _completedDate = existing.completedDate;
      _expirationDate = existing.expirationDate;
      _recertDate = existing.nextRecertificationDate;
      _employeeId = existing.employeeId;
    }
    if (employee != null) {
      _employeeId = employee.id;
      _employeeName = employee.fullName;
    }
    if (existing != null) {
      _bulkAssign = false;
    }
  }

  @override
  void dispose() {
    _trainingNameController.dispose();
    _trainingTypeController.dispose();
    _instructorController.dispose();
    _locationController.dispose();
    _ceuController.dispose();
    _scoreController.dispose();
    _certificateUrlController.dispose();
    _materialsController.dispose();
    _documentsController.dispose();
    _assignedRoleController.dispose();
    _assignedJobController.dispose();
    _assignedSiteController.dispose();
    _assignedTenureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final employeesAsync = ref.watch(employeesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Training' : 'Assign Training')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (!isEditing)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Assign to multiple employees'),
                  value: _bulkAssign,
                  onChanged: (value) => setState(() {
                    _bulkAssign = value;
                    if (value) _employeeId = null;
                  }),
                ),
              if (_bulkAssign)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: const [
                        Icon(Icons.group),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bulk assignment uses the criteria below to target employees.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              employeesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Employees unavailable: $e'),
                data: (employees) {
                  final items = _buildEmployeeOptions(employees);
                  if (_bulkAssign) {
                    return const SizedBox.shrink();
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _employeeId,
                    decoration: const InputDecoration(
                      labelText: 'Employee',
                      border: OutlineInputBorder(),
                    ),
                    items: items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: widget.employee != null || widget.existing != null
                        ? null
                        : (value) {
                            final selected =
                                items.firstWhere((item) => item.id == value);
                            setState(() {
                              _employeeId = selected.id;
                              _employeeName = selected.label;
                            });
                          },
                    validator: (value) {
                      if (_bulkAssign) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Employee is required';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _trainingNameController,
                decoration: const InputDecoration(
                  labelText: 'Training name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Training name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _trainingTypeController,
                decoration: const InputDecoration(
                  labelText: 'Training type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TrainingStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: TrainingStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(
                  () => _status = value ?? TrainingStatus.notStarted,
                ),
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'Completed date',
                value: _completedDate,
                onPick: () => _pickDate((date) => setState(() => _completedDate = date)),
              ),
              _DateField(
                label: 'Expiration date',
                value: _expirationDate,
                onPick: () => _pickDate((date) => setState(() => _expirationDate = date)),
              ),
              _DateField(
                label: 'Recertification date',
                value: _recertDate,
                onPick: () => _pickDate((date) => setState(() => _recertDate = date)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructorController,
                decoration: const InputDecoration(
                  labelText: 'Instructor',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Training location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ceuController,
                      decoration: const InputDecoration(
                        labelText: 'CEU credits',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _scoreController,
                      decoration: const InputDecoration(
                        labelText: 'Score',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _certificateUrlController,
                decoration: const InputDecoration(
                  labelText: 'Certificate URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _materialsController,
                decoration: const InputDecoration(
                  labelText: 'Materials used (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _documentsController,
                decoration: const InputDecoration(
                  labelText: 'Documents (comma separated URLs)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Assignment criteria'),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  TextFormField(
                    controller: _assignedRoleController,
                    decoration: const InputDecoration(
                      labelText: 'Assigned role',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _assignedJobController,
                    decoration: const InputDecoration(
                      labelText: 'Assigned job',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _assignedSiteController,
                    decoration: const InputDecoration(
                      labelText: 'Assigned site',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _assignedTenureController,
                    decoration: const InputDecoration(
                      labelText: 'Tenure (days with company)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
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
                label: Text(_saving ? 'Saving...' : 'Save training'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_EmployeeOption> _buildEmployeeOptions(List<Employee> employees) {
    final options = employees
        .map(
          (employee) => _EmployeeOption(
            id: employee.id,
            label: employee.fullName,
          ),
        )
        .toList();
    if (_employeeId != null &&
        !options.any((option) => option.id == _employeeId)) {
      options.add(_EmployeeOption(id: _employeeId!, label: _employeeName ?? 'Employee'));
    }
    return options;
  }

  Future<void> _pickDate(ValueChanged<DateTime?> onSelected) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (selected == null) return;
    onSelected(selected);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (!_bulkAssign && _employeeId == null) return;
    setState(() => _saving = true);
    final repo = ref.read(trainingRepositoryProvider);
    try {
      final ceuCredits = double.tryParse(_ceuController.text.trim());
      final score = double.tryParse(_scoreController.text.trim());
      final tenureDays = int.tryParse(_assignedTenureController.text.trim());
      if (widget.existing == null && _bulkAssign) {
        final employees = await ref.read(employeesProvider.future);
        final targets = _filterEmployees(employees, tenureDays);
        if (targets.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No employees match the criteria.')),
          );
          setState(() => _saving = false);
          return;
        }
        for (final employee in targets) {
          await repo.createTrainingRecord(
            employeeId: employee.id,
            trainingName: _trainingNameController.text.trim(),
            trainingType: _trainingTypeController.text.trim(),
            status: _status,
            completedDate: _completedDate,
            expirationDate: _expirationDate,
            instructorName: _instructorController.text.trim(),
            score: score,
            certificateUrl: _certificateUrlController.text.trim(),
            nextRecertificationDate: _recertDate,
            location: _locationController.text.trim(),
            ceuCredits: ceuCredits,
            materials: _parseList(_materialsController.text),
            documents: _parseList(_documentsController.text),
            assignedRole: _assignedRoleController.text.trim(),
            assignedJob: _assignedJobController.text.trim(),
            assignedSite: _assignedSiteController.text.trim(),
            assignedTenureDays: tenureDays,
          );
        }
        if (!mounted) return;
        Navigator.pop(context);
      } else if (widget.existing == null) {
        final training = await repo.createTrainingRecord(
          employeeId: _employeeId!,
          trainingName: _trainingNameController.text.trim(),
          trainingType: _trainingTypeController.text.trim(),
          status: _status,
          completedDate: _completedDate,
          expirationDate: _expirationDate,
          instructorName: _instructorController.text.trim(),
          score: score,
          certificateUrl: _certificateUrlController.text.trim(),
          nextRecertificationDate: _recertDate,
          location: _locationController.text.trim(),
          ceuCredits: ceuCredits,
          materials: _parseList(_materialsController.text),
          documents: _parseList(_documentsController.text),
          assignedRole: _assignedRoleController.text.trim(),
          assignedJob: _assignedJobController.text.trim(),
          assignedSite: _assignedSiteController.text.trim(),
          assignedTenureDays: tenureDays,
        );
        if (!mounted) return;
        Navigator.pop(context, training);
      } else {
        final training = await repo.updateTrainingRecord(
          trainingId: widget.existing!.id,
          trainingName: _trainingNameController.text.trim(),
          trainingType: _trainingTypeController.text.trim(),
          status: _status,
          completedDate: _completedDate,
          expirationDate: _expirationDate,
          instructorName: _instructorController.text.trim(),
          score: score,
          certificateUrl: _certificateUrlController.text.trim(),
          nextRecertificationDate: _recertDate,
          location: _locationController.text.trim(),
          ceuCredits: ceuCredits,
          materials: _parseList(_materialsController.text),
          documents: _parseList(_documentsController.text),
          assignedRole: _assignedRoleController.text.trim(),
          assignedJob: _assignedJobController.text.trim(),
          assignedSite: _assignedSiteController.text.trim(),
          assignedTenureDays: tenureDays,
        );
        if (!mounted) return;
        Navigator.pop(context, training);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _parseList(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<Employee> _filterEmployees(List<Employee> employees, int? tenureDays) {
    final role = _assignedRoleController.text.trim().toLowerCase();
    final job = _assignedJobController.text.trim().toLowerCase();
    final site = _assignedSiteController.text.trim().toLowerCase();
    return employees.where((employee) {
      if (!employee.isActive) return false;
      final matchesRole = role.isEmpty ||
          (employee.department?.toLowerCase().contains(role) ?? false);
      final matchesJob = job.isEmpty ||
          (employee.position?.toLowerCase().contains(job) ?? false);
      final matchesSite = site.isEmpty ||
          (employee.jobSiteName?.toLowerCase().contains(site) ?? false);
      final matchesTenure = tenureDays == null ||
          DateTime.now().difference(employee.hireDate).inDays >= tenureDays;
      return matchesRole && matchesJob && matchesSite && matchesTenure;
    }).toList();
  }
}

class _EmployeeOption {
  const _EmployeeOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Not set'
        : '${value!.month}/${value!.day}/${value!.year}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today),
      title: Text(label),
      subtitle: Text(text),
      trailing: TextButton(
        onPressed: onPick,
        child: const Text('Select'),
      ),
    );
  }
}
