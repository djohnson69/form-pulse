import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../admin/data/admin_models.dart';
import '../../../admin/data/admin_providers.dart';
import '../../../admin/data/admin_repository.dart';
import '../../data/platform_providers.dart';

/// Page showing all organizations across the platform
class AllOrganizationsPage extends ConsumerStatefulWidget {
  const AllOrganizationsPage({super.key});

  @override
  ConsumerState<AllOrganizationsPage> createState() => _AllOrganizationsPageState();
}

class _AllOrganizationsPageState extends ConsumerState<AllOrganizationsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _sortAsc = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final orgsAsync = ref.watch(platformOrganizationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.apartment,
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Organizations',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    orgsAsync.when(
                      data: (orgs) => Text(
                        '${orgs.length} organizations on the platform',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                      loading: () => Text(
                        'Loading...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showAddOrgDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Organization'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(platformOrganizationsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),

        // Search and filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search organizations...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('Sort by Name')),
                      DropdownMenuItem(value: 'members', child: Text('Sort by Members')),
                      DropdownMenuItem(value: 'created', child: Text('Sort by Created')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _sortBy = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _sortAsc = !_sortAsc),
                icon: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Organizations list
        Expanded(
          child: orgsAsync.when(
            data: (orgs) {
              var filteredOrgs = orgs.where((org) {
                if (_searchQuery.isEmpty) return true;
                return org.name.toLowerCase().contains(_searchQuery);
              }).toList();

              // Sort
              filteredOrgs.sort((a, b) {
                int result;
                switch (_sortBy) {
                  case 'members':
                    result = a.memberCount.compareTo(b.memberCount);
                    break;
                  case 'created':
                    result = a.createdAt.compareTo(b.createdAt);
                    break;
                  default:
                    result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                }
                return _sortAsc ? result : -result;
              });

              if (filteredOrgs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No organizations found'
                            : 'No organizations match "$_searchQuery"',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filteredOrgs.length,
                itemBuilder: (context, index) {
                  final org = filteredOrgs[index];
                  return _OrganizationCard(
                    org: org,
                    onTap: () => _showOrgDetails(context, org),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load organizations',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(platformOrganizationsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddOrgDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddEditOrgDialog(
        onSave: (org) {
          ref.invalidate(platformOrganizationsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Organization "${org.name}" created'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  void _showOrgDetails(BuildContext context, AdminOrgSummary org) {
    showDialog(
      context: context,
      builder: (context) => _OrgDetailDialog(
        orgId: org.id,
        orgName: org.name,
        memberCount: org.memberCount,
        createdAt: org.createdAt,
        onEdit: () {
          Navigator.of(context).pop();
          _showEditOrgDialog(context, org.id);
        },
        onViewData: () {
          Navigator.of(context).pop();
          ref.read(adminSelectedOrgIdProvider.notifier).state = org.id;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Now viewing data for ${org.name}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showEditOrgDialog(BuildContext context, String orgId) {
    showDialog(
      context: context,
      builder: (context) => _AddEditOrgDialog(
        orgId: orgId,
        onSave: (org) {
          ref.invalidate(platformOrganizationsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Organization "${org.name}" updated'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }
}

/// Dialog for viewing organization details
class _OrgDetailDialog extends ConsumerStatefulWidget {
  const _OrgDetailDialog({
    required this.orgId,
    required this.orgName,
    required this.memberCount,
    required this.createdAt,
    required this.onEdit,
    required this.onViewData,
  });

  final String orgId;
  final String orgName;
  final int memberCount;
  final DateTime createdAt;
  final VoidCallback onEdit;
  final VoidCallback onViewData;

  @override
  ConsumerState<_OrgDetailDialog> createState() => _OrgDetailDialogState();
}

class _OrgDetailDialogState extends ConsumerState<_OrgDetailDialog> {
  AdminOrgDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final detail = await repo.fetchOrganizationDetail(widget.orgId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.3 : 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        widget.orgName.isNotEmpty ? widget.orgName[0].toUpperCase() : 'O',
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.orgName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'ID: ${widget.orgId}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6),
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: widget.orgId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ID copied to clipboard')),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 14),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 14,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)))
                        : _buildDetailContent(isDark, dateFormat),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: widget.onViewData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Org Data'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent(bool isDark, DateFormat dateFormat) {
    final detail = _detail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic Info Section
        _SectionHeader(title: 'Basic Information', isDark: isDark),
        const SizedBox(height: 12),
        _DetailRow(icon: Icons.business, label: 'Name', value: detail?.name ?? widget.orgName, isDark: isDark),
        if (detail?.displayName?.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          _DetailRow(icon: Icons.label, label: 'Display Name', value: detail!.displayName!, isDark: isDark),
        ],
        const SizedBox(height: 8),
        _DetailRow(icon: Icons.people, label: 'Members', value: '${detail?.memberCount ?? widget.memberCount}', isDark: isDark),
        const SizedBox(height: 8),
        _DetailRow(icon: Icons.calendar_today, label: 'Created', value: dateFormat.format(detail?.createdAt ?? widget.createdAt), isDark: isDark),
        const SizedBox(height: 8),
        _DetailRow(
          icon: Icons.check_circle,
          label: 'Status',
          value: (detail?.isActive ?? true) ? 'Active' : 'Inactive',
          valueColor: (detail?.isActive ?? true) ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          isDark: isDark,
        ),

        // Industry & Size Section
        if ((detail?.industry?.isNotEmpty ?? false) || (detail?.companySize?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 24),
          _SectionHeader(title: 'Company Details', isDark: isDark),
          const SizedBox(height: 12),
          if (detail?.industry?.isNotEmpty ?? false)
            _DetailRow(icon: Icons.category, label: 'Industry', value: detail!.industry!, isDark: isDark),
          if (detail?.companySize?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            _DetailRow(icon: Icons.groups, label: 'Company Size', value: detail!.companySize!, isDark: isDark),
          ],
        ],

        // Contact Section
        if ((detail?.phone?.isNotEmpty ?? false) || (detail?.website?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 24),
          _SectionHeader(title: 'Contact', isDark: isDark),
          const SizedBox(height: 12),
          if (detail?.phone?.isNotEmpty ?? false)
            _DetailRow(icon: Icons.phone, label: 'Phone', value: detail!.phone!, isDark: isDark),
          if (detail?.website?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            _DetailRow(icon: Icons.language, label: 'Website', value: detail!.website!, isDark: isDark),
          ],
        ],

        // Address Section
        if ((detail?.addressLine1?.isNotEmpty ?? false) || (detail?.city?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 24),
          _SectionHeader(title: 'Address', isDark: isDark),
          const SizedBox(height: 12),
          if (detail?.addressLine1?.isNotEmpty ?? false)
            _DetailRow(icon: Icons.location_on, label: 'Address', value: detail!.addressLine1!, isDark: isDark),
          if (detail?.addressLine2?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            _DetailRow(icon: Icons.location_on_outlined, label: 'Address 2', value: detail!.addressLine2!, isDark: isDark),
          ],
          if (detail?.city?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            _DetailRow(icon: Icons.location_city, label: 'City', value: detail!.city!, isDark: isDark),
          ],
          if (detail?.state?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            _DetailRow(icon: Icons.map, label: 'State', value: detail!.state!, isDark: isDark),
          ],
          if (detail?.postalCode?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            _DetailRow(icon: Icons.markunread_mailbox, label: 'Postal Code', value: detail!.postalCode!, isDark: isDark),
          ],
          if (detail?.country?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            _DetailRow(icon: Icons.flag, label: 'Country', value: detail!.country!, isDark: isDark),
          ],
        ],

        // Tax Info Section
        if (detail?.taxId?.isNotEmpty ?? false) ...[
          const SizedBox(height: 24),
          _SectionHeader(title: 'Tax Information', isDark: isDark),
          const SizedBox(height: 12),
          _DetailRow(icon: Icons.receipt_long, label: 'Tax ID', value: detail!.taxId!, isDark: isDark),
        ],
      ],
    );
  }
}

/// Dialog for adding or editing an organization
class _AddEditOrgDialog extends ConsumerStatefulWidget {
  const _AddEditOrgDialog({
    this.orgId,
    required this.onSave,
  });

  final String? orgId;
  final void Function(AdminOrgDetail org) onSave;

  @override
  ConsumerState<_AddEditOrgDialog> createState() => _AddEditOrgDialogState();
}

class _AddEditOrgDialogState extends ConsumerState<_AddEditOrgDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _industryController = TextEditingController();
  final _companySizeController = TextEditingController();
  final _websiteController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController();
  final _taxIdController = TextEditingController();

  bool _isActive = true;
  bool _loading = false;
  bool _initialLoading = false;
  String? _error;

  bool get isEditing => widget.orgId != null;

  @override
  void initState() {
    super.initState();
    _countryController.text = 'US';
    if (isEditing) {
      _loadExistingOrg();
    }
  }

  Future<void> _loadExistingOrg() async {
    setState(() => _initialLoading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final detail = await repo.fetchOrganizationDetail(widget.orgId!);
      if (detail != null && mounted) {
        _nameController.text = detail.name;
        _displayNameController.text = detail.displayName ?? '';
        _industryController.text = detail.industry ?? '';
        _companySizeController.text = detail.companySize ?? '';
        _websiteController.text = detail.website ?? '';
        _phoneController.text = detail.phone ?? '';
        _addressLine1Controller.text = detail.addressLine1 ?? '';
        _addressLine2Controller.text = detail.addressLine2 ?? '';
        _cityController.text = detail.city ?? '';
        _stateController.text = detail.state ?? '';
        _postalCodeController.text = detail.postalCode ?? '';
        _countryController.text = detail.country ?? 'US';
        _taxIdController.text = detail.taxId ?? '';
        _isActive = detail.isActive;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _initialLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _industryController.dispose();
    _companySizeController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      AdminOrgDetail org;

      if (isEditing) {
        org = await repo.updateOrganization(
          orgId: widget.orgId!,
          name: _nameController.text.trim(),
          displayName: _displayNameController.text.trim().isEmpty ? null : _displayNameController.text.trim(),
          industry: _industryController.text.trim().isEmpty ? null : _industryController.text.trim(),
          companySize: _companySizeController.text.trim().isEmpty ? null : _companySizeController.text.trim(),
          website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          addressLine1: _addressLine1Controller.text.trim().isEmpty ? null : _addressLine1Controller.text.trim(),
          addressLine2: _addressLine2Controller.text.trim().isEmpty ? null : _addressLine2Controller.text.trim(),
          city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
          postalCode: _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
          country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
          taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
          isActive: _isActive,
        );
      } else {
        org = await repo.createOrganization(
          name: _nameController.text.trim(),
          displayName: _displayNameController.text.trim().isEmpty ? null : _displayNameController.text.trim(),
          industry: _industryController.text.trim().isEmpty ? null : _industryController.text.trim(),
          companySize: _companySizeController.text.trim().isEmpty ? null : _companySizeController.text.trim(),
          website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          addressLine1: _addressLine1Controller.text.trim().isEmpty ? null : _addressLine1Controller.text.trim(),
          addressLine2: _addressLine2Controller.text.trim().isEmpty ? null : _addressLine2Controller.text.trim(),
          city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
          postalCode: _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
          country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
          taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSave(org);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.3 : 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit : Icons.add_business,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Organization' : 'Add Organization',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: _initialLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444)))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Basic Info
                            _SectionHeader(title: 'Basic Information', isDark: isDark),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameController,
                              decoration: _inputDecoration('Organization Name *', Icons.business, isDark),
                              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _displayNameController,
                              decoration: _inputDecoration('Display Name', Icons.label, isDark),
                            ),

                            // Company Details
                            const SizedBox(height: 24),
                            _SectionHeader(title: 'Company Details', isDark: isDark),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _industryController,
                                    decoration: _inputDecoration('Industry', Icons.category, isDark),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _companySizeController.text.isEmpty ? null : _companySizeController.text,
                                    decoration: _inputDecoration('Company Size', Icons.groups, isDark),
                                    items: const [
                                      DropdownMenuItem(value: '1-10', child: Text('1-10 employees')),
                                      DropdownMenuItem(value: '11-50', child: Text('11-50 employees')),
                                      DropdownMenuItem(value: '51-200', child: Text('51-200 employees')),
                                      DropdownMenuItem(value: '201-500', child: Text('201-500 employees')),
                                      DropdownMenuItem(value: '501-1000', child: Text('501-1000 employees')),
                                      DropdownMenuItem(value: '1000+', child: Text('1000+ employees')),
                                    ],
                                    onChanged: (v) => _companySizeController.text = v ?? '',
                                  ),
                                ),
                              ],
                            ),

                            // Contact
                            const SizedBox(height: 24),
                            _SectionHeader(title: 'Contact', isDark: isDark),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    decoration: _inputDecoration('Phone', Icons.phone, isDark),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _websiteController,
                                    decoration: _inputDecoration('Website', Icons.language, isDark),
                                  ),
                                ),
                              ],
                            ),

                            // Address
                            const SizedBox(height: 24),
                            _SectionHeader(title: 'Address', isDark: isDark),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressLine1Controller,
                              decoration: _inputDecoration('Address Line 1', Icons.location_on, isDark),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressLine2Controller,
                              decoration: _inputDecoration('Address Line 2', Icons.location_on_outlined, isDark),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _cityController,
                                    decoration: _inputDecoration('City', Icons.location_city, isDark),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _stateController,
                                    decoration: _inputDecoration('State', Icons.map, isDark),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _postalCodeController,
                                    decoration: _inputDecoration('Postal Code', Icons.markunread_mailbox, isDark),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _countryController,
                              decoration: _inputDecoration('Country', Icons.flag, isDark),
                            ),

                            // Tax Info
                            const SizedBox(height: 24),
                            _SectionHeader(title: 'Tax Information', isDark: isDark),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _taxIdController,
                              decoration: _inputDecoration('Tax ID / EIN', Icons.receipt_long, isDark),
                            ),

                            // Status (edit mode only)
                            if (isEditing) ...[
                              const SizedBox(height: 24),
                              _SectionHeader(title: 'Status', isDark: isDark),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                title: const Text('Active'),
                                subtitle: Text(_isActive ? 'Organization is active' : 'Organization is deactivated'),
                                value: _isActive,
                                onChanged: (v) => setState(() => _isActive = v),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: Text(isEditing ? 'Save Changes' : 'Create Organization'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB)),
      ),
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  const _OrganizationCard({
    required this.org,
    required this.onTap,
  });

  final AdminOrgSummary org;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      org.name.isNotEmpty ? org.name[0].toUpperCase() : 'O',
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            size: 14,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${org.memberCount} members',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(org.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Active',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.isDark});

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF111827)),
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
