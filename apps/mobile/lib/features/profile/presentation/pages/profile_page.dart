import 'dart:developer' as developer;

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
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String email;
  final UserRole role;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final bool isActive;
  final DateTime? createdAt;

  String get displayName {
    final parts = [firstName, lastName].whereType<String>().toList();
    final name = parts.join(' ').trim();
    return name.isEmpty ? email : name;
  }

  String get initials {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isNotEmpty || last.isNotEmpty) {
      final firstLetter = first.isNotEmpty ? first[0] : '';
      final secondLetter =
          last.isNotEmpty ? last[0] : (first.length > 1 ? first[1] : '');
      return '${firstLetter.toUpperCase()}${secondLetter.toUpperCase()}'
          .trim();
    }
    final sanitized = email.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (sanitized.isEmpty) return '?';
    if (sanitized.length == 1) return sanitized.toUpperCase();
    return sanitized.substring(0, 2).toUpperCase();
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
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _scrollController = ScrollController();
  final _personalInfoKey = GlobalKey();

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
    _emailController.dispose();
    _addressController.dispose();
    _scrollController.dispose();
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
          .select('id, email, first_name, last_name, phone, role, is_active, created_at')
          .eq('id', user.id)
          .maybeSingle();
      if (res == null) {
        setState(() => _loading = false);
        return;
      }
      final rawRole = res['role']?.toString() ?? UserRole.viewer.name;
      final role = UserRole.fromRaw(rawRole);
      final profile = ProfileSummary(
        id: res['id'] as String,
        email: res['email']?.toString() ?? user.email ?? '',
        role: role,
        firstName: res['first_name']?.toString(),
        lastName: res['last_name']?.toString(),
        phone: res['phone']?.toString(),
        isActive: res['is_active'] as bool? ?? true,
        createdAt: _parseDate(res['created_at']),
      );
      _firstNameController.text = profile.firstName ?? '';
      _lastNameController.text = profile.lastName ?? '';
      _phoneController.text = profile.phone ?? '';
      _emailController.text = profile.email;
      _addressController.text = _addressController.text;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('is_active') || e.code == '42703') {
        try {
          final res = await client
              .from('profiles')
              .select('id, email, first_name, last_name, phone, role, created_at')
              .eq('id', user.id)
              .maybeSingle();
          if (res == null) {
            setState(() => _loading = false);
            return;
          }
          final rawRole = res['role']?.toString() ?? UserRole.viewer.name;
          final role = UserRole.fromRaw(rawRole);
          final profile = ProfileSummary(
            id: res['id'] as String,
            email: res['email']?.toString() ?? user.email ?? '',
            role: role,
            firstName: res['first_name']?.toString(),
            lastName: res['last_name']?.toString(),
            phone: res['phone']?.toString(),
            isActive: true,
            createdAt: _parseDate(res['created_at']),
          );
          _firstNameController.text = profile.firstName ?? '';
          _lastNameController.text = profile.lastName ?? '';
          _phoneController.text = profile.phone ?? '';
          _emailController.text = profile.email;
          _addressController.text = _addressController.text;
          setState(() {
            _profile = profile;
            _loading = false;
          });
          return;
        } catch (e, st) {
          developer.log('ProfilePage load profile inner failed',
              error: e, stackTrace: st, name: 'ProfilePage._loadProfile');
        }
      }
      setState(() => _loading = false);
    } catch (e, st) {
      developer.log('ProfilePage load profile failed',
          error: e, stackTrace: st, name: 'ProfilePage._loadProfile');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final profile = _profile;
    if (profile == null) return;
    setState(() => _saving = true);
    try {
      final email = _emailController.text.trim();
      await Supabase.instance.client.from('profiles').update({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': email.isEmpty ? null : email,
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

    final theme = Theme.of(context);
    final colors = _ProfileColors.fromTheme(theme);
    final tasksAsync = ref.watch(tasksProvider);
    final employeeIdAsync = ref.watch(_employeeIdProvider);
    final trainingAsync = employeeIdAsync.when(
      data: (employeeId) {
        if (employeeId == null) {
          return const AsyncValue<List<Training>>.data([]);
        }
        return ref.watch(trainingRecordsProvider(employeeId));
      },
      loading: () => const AsyncValue<List<Training>>.loading(),
      error: (error, stack) => AsyncValue<List<Training>>.error(error, stack),
    );

    final tasks = tasksAsync.asData?.value ?? const <Task>[];
    final trainingRecords = trainingAsync.asData?.value ?? const <Training>[];
    final hasTasks = tasks.isNotEmpty;
    final hasTraining = trainingRecords.isNotEmpty;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final completedTasks = hasTasks
        ? tasks
            .where((task) => task.assignedTo == userId && task.isComplete)
            .length
        : 0;
    final certifications =
        hasTraining ? _buildCertifications(trainingRecords) : const <_Certification>[];
    final certificationsCount = certifications.length;
    final daysActive = profile.createdAt == null
        ? 0
        : DateTime.now().difference(profile.createdAt!).inDays;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          if (tasksAsync.isLoading || trainingAsync.isLoading)
            const LinearProgressIndicator(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Profile',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.title,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage your personal information',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.subtitle,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 980;
                      final profileCard = _ProfileCard(
                        colors: colors,
                        profile: profile,
                        address: _addressController.text,
                        onEdit: _scrollToPersonalInfo,
                      );
                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatsGrid(
                            colors: colors,
                            completedTasks: completedTasks,
                            certifications: certificationsCount,
                            daysActive: daysActive,
                          ),
                          const SizedBox(height: 16),
                          _PersonalInfoCard(
                            key: _personalInfoKey,
                            colors: colors,
                            firstNameController: _firstNameController,
                            lastNameController: _lastNameController,
                            emailController: _emailController,
                            phoneController: _phoneController,
                            addressController: _addressController,
                            saving: _saving,
                            onSave: _saveProfile,
                          ),
                          const SizedBox(height: 16),
                          _CertificationsCard(
                            colors: colors,
                            certifications: certifications,
                          ),
                        ],
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(flex: 1, child: profileCard),
                            const SizedBox(width: 16),
                            Flexible(flex: 2, child: details),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          profileCard,
                          const SizedBox(height: 16),
                          details,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToPersonalInfo() {
    final context = _personalInfoKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  List<_Certification> _buildCertifications(List<Training> records) {
    return records.map((record) {
      final date = record.completedDate ??
          record.expirationDate ??
          record.nextRecertificationDate ??
          DateTime.now();
      final isValid = !record.isExpired;
      return _Certification(
        name: record.trainingName,
        issuedOn: date,
        status: isValid ? 'Valid' : 'Expired',
        isValid: isValid,
      );
    }).toList();
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.colors,
    required this.profile,
    required this.address,
    required this.onEdit,
  });

  final _ProfileColors colors;
  final ProfileSummary profile;
  final String address;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
            ),
            child: Center(
              child: Text(
                profile.initials,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.displayName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.title,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _roleLabel(profile.role),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.subtitle,
            ),
          ),
          const SizedBox(height: 8),
          _StatusChip(
            colors: colors,
            isActive: profile.isActive,
          ),
          const SizedBox(height: 20),
          _ContactRow(
            icon: Icons.mail_outline,
            label: profile.email,
            colors: colors,
          ),
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.phone,
            label: profile.phone?.isNotEmpty == true
                ? profile.phone!
                : 'Not provided',
            colors: colors,
          ),
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.location_on_outlined,
            label: address.isEmpty ? 'Address not set' : address,
            colors: colors,
          ),
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.calendar_today_outlined,
            label: _formatJoinedDate(profile.createdAt),
            colors: colors,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onEdit,
              child: const Text('Edit Profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.colors,
    required this.completedTasks,
    required this.certifications,
    required this.daysActive,
  });

  final _ProfileColors colors;
  final int completedTasks;
  final int certifications;
  final int daysActive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 2.8 : 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(
              colors: colors,
              title: 'Tasks Completed',
              value: completedTasks.toString(),
              icon: Icons.work_outline,
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
            ),
            _StatCard(
              colors: colors,
              title: 'Certifications',
              value: certifications.toString(),
              icon: Icons.workspace_premium_outlined,
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              ),
            ),
            _StatCard(
              colors: colors,
              title: 'Days Active',
              value: daysActive.toString(),
              icon: Icons.calendar_today_outlined,
              gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.colors,
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  final _ProfileColors colors;
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.title,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({
    super.key,
    required this.colors,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.phoneController,
    required this.addressController,
    required this.saving,
    required this.onSave,
  });

  final _ProfileColors colors;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.title,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final halfWidth = isWide
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: halfWidth,
                    child: _LabeledInput(
                      label: 'First Name',
                      controller: firstNameController,
                      colors: colors,
                    ),
                  ),
                  SizedBox(
                    width: halfWidth,
                    child: _LabeledInput(
                      label: 'Last Name',
                      controller: lastNameController,
                      colors: colors,
                    ),
                  ),
                  SizedBox(
                    width: halfWidth,
                    child: _LabeledInput(
                      label: 'Email',
                      controller: emailController,
                      colors: colors,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  SizedBox(
                    width: halfWidth,
                    child: _LabeledInput(
                      label: 'Phone',
                      controller: phoneController,
                      colors: colors,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _LabeledInput(
                      label: 'Address',
                      controller: addressController,
                      colors: colors,
                      keyboardType: TextInputType.streetAddress,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: saving ? null : onSave,
            child: Text(saving ? 'Saving...' : 'Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _LabeledInput extends StatelessWidget {
  const _LabeledInput({
    required this.label,
    required this.controller,
    required this.colors,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final _ProfileColors colors;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.subtitle,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.title,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _CertificationsCard extends StatelessWidget {
  const _CertificationsCard({
    required this.colors,
    required this.certifications,
  });

  final _ProfileColors colors;
  final List<_Certification> certifications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Certifications',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.title,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < certifications.length; i++)
            _CertificationRow(
              colors: colors,
              certification: certifications[i],
              isLast: i == certifications.length - 1,
            ),
        ],
      ),
    );
  }
}

class _CertificationRow extends StatelessWidget {
  const _CertificationRow({
    required this.colors,
    required this.certification,
    required this.isLast,
  });

  final _ProfileColors colors;
  final _Certification certification;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusBackground =
        certification.isValid ? colors.successBackground : colors.warningBackground;
    final statusText =
        certification.isValid ? colors.successText : colors.warningText;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: colors.border),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  certification.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Issued: ${_formatDate(certification.issuedOn)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              certification.status,
              style: theme.textTheme.bodySmall?.copyWith(
                color: statusText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final _ProfileColors colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.iconMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.subtitle,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.colors,
    required this.isActive,
  });

  final _ProfileColors colors;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? colors.successBackground : colors.warningBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: theme.textTheme.bodySmall?.copyWith(
          color: isActive ? colors.successText : colors.warningText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Certification {
  const _Certification({
    required this.name,
    required this.issuedOn,
    required this.status,
    required this.isValid,
  });

  final String name;
  final DateTime issuedOn;
  final String status;
  final bool isValid;
}

class _ProfileColors {
  const _ProfileColors({
    required this.background,
    required this.surface,
    required this.border,
    required this.title,
    required this.subtitle,
    required this.muted,
    required this.primary,
    required this.inputFill,
    required this.inputBorder,
    required this.iconMuted,
    required this.successBackground,
    required this.successText,
    required this.warningBackground,
    required this.warningText,
  });

  final Color background;
  final Color surface;
  final Color border;
  final Color title;
  final Color subtitle;
  final Color muted;
  final Color primary;
  final Color inputFill;
  final Color inputBorder;
  final Color iconMuted;
  final Color successBackground;
  final Color successText;
  final Color warningBackground;
  final Color warningText;

  factory _ProfileColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return _ProfileColors(
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      title: isDark ? Colors.white : const Color(0xFF111827),
      subtitle: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      primary: const Color(0xFF2563EB),
      inputFill: isDark ? const Color(0xFF111827) : Colors.white,
      inputBorder: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
      iconMuted: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
      successBackground: isDark
          ? const Color(0xFF064E3B).withOpacity(0.3)
          : const Color(0xFFD1FAE5),
      successText: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
      warningBackground: isDark
          ? const Color(0xFF7F1D1D).withOpacity(0.3)
          : const Color(0xFFFEE2E2),
      warningText: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
    );
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}

String _formatJoinedDate(DateTime? date) {
  if (date == null) return 'Joined';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[date.month - 1];
  return 'Joined $month ${date.year}';
}

String _roleLabel(UserRole role) {
  if (role == UserRole.employee) {
    return 'Field Technician';
  }
  return role.displayName;
}
