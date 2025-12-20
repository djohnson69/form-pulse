import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/training_provider.dart';

class EmployeeEditorPage extends ConsumerStatefulWidget {
  const EmployeeEditorPage({this.existing, super.key});

  final Employee? existing;

  @override
  ConsumerState<EmployeeEditorPage> createState() => _EmployeeEditorPageState();
}

class _EmployeeEditorPageState extends ConsumerState<EmployeeEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _employeeNumberController = TextEditingController();
  final _departmentController = TextEditingController();
  final _positionController = TextEditingController();
  final _jobSiteController = TextEditingController();
  final _certificationsController = TextEditingController();
  DateTime? _hireDate;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _firstNameController.text = existing.firstName;
      _lastNameController.text = existing.lastName;
      _emailController.text = existing.email;
      _phoneController.text = existing.phoneNumber ?? '';
      _employeeNumberController.text = existing.employeeNumber ?? '';
      _departmentController.text = existing.department ?? '';
      _positionController.text = existing.position ?? '';
      _jobSiteController.text = existing.jobSiteName ?? '';
      _certificationsController.text =
          (existing.certifications ?? const []).join(', ');
      _hireDate = existing.hireDate;
      _isActive = existing.isActive;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _employeeNumberController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    _jobSiteController.dispose();
    _certificationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Employee' : 'New Employee')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'First name is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Last name is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
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
                controller: _employeeNumberController,
                decoration: const InputDecoration(
                  labelText: 'Employee number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _positionController,
                decoration: const InputDecoration(
                  labelText: 'Job title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jobSiteController,
                decoration: const InputDecoration(
                  labelText: 'Job site',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _certificationsController,
                decoration: const InputDecoration(
                  labelText: 'Certifications (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active employee'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _hireDate == null
                      ? 'Hire date not set'
                      : 'Hired ${_formatDate(_hireDate!)}',
                ),
                trailing: TextButton(
                  onPressed: _pickHireDate,
                  child: const Text('Select'),
                ),
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
                label: Text(_saving ? 'Saving...' : 'Save employee'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickHireDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _hireDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (selected == null) return;
    setState(() => _hireDate = selected);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(trainingRepositoryProvider);
    final certifications = _parseList(_certificationsController.text);
    try {
      final employee = widget.existing == null
          ? await repo.createEmployee(
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              email: _emailController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              employeeNumber: _employeeNumberController.text.trim(),
              department: _departmentController.text.trim(),
              position: _positionController.text.trim(),
              jobSiteName: _jobSiteController.text.trim(),
              hireDate: _hireDate,
              isActive: _isActive,
              certifications: certifications,
            )
          : await repo.updateEmployee(
              employeeId: widget.existing!.id,
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              email: _emailController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              employeeNumber: _employeeNumberController.text.trim(),
              department: _departmentController.text.trim(),
              position: _positionController.text.trim(),
              jobSiteName: _jobSiteController.text.trim(),
              hireDate: _hireDate,
              isActive: _isActive,
              certifications: certifications,
            );
      if (!mounted) return;
      Navigator.pop(context, employee);
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

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}
