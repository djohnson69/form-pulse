import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../dashboard/data/role_override_provider.dart';
import '../../../training/data/training_provider.dart';

class OrganizationChartPage extends ConsumerStatefulWidget {
  const OrganizationChartPage({super.key, this.role});

  final UserRole? role;

  @override
  ConsumerState<OrganizationChartPage> createState() =>
      _OrganizationChartPageState();
}

class _OrganizationChartPageState
    extends ConsumerState<OrganizationChartPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedSupervisors = {};
  String _searchTerm = '';
  bool _initializedExpansion = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final override = ref.watch(roleOverrideProvider);
    final role = override ?? widget.role ?? UserRole.employee;
    final canEdit = role == UserRole.manager ||
        role == UserRole.admin ||
        role == UserRole.superAdmin;
    final employeesAsync = ref.watch(employeesProvider);
    final employees = employeesAsync.asData?.value ?? const <Employee>[];
    final data = _buildOrganizationData(employees);
    final totalEmployees =
        data.fold<int>(0, (sum, supervisor) => sum + supervisor.teamSize);
    final totalProjects =
        data.fold<int>(0, (sum, supervisor) => sum + supervisor.projects);
    final departments = data.map((supervisor) => supervisor.department).toSet().length;
    final filteredData = _applySearch(data, _searchTerm);

    if (!_initializedExpansion && data.isNotEmpty) {
      _initializedExpansion = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _expandedSupervisors.add(data.first.id));
      });
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth > 1280 ? 1280.0 : constraints.maxWidth;
          final isWide = constraints.maxWidth >= 768;
          final pagePadding = EdgeInsets.all(isWide ? 24 : 16);
          final sectionSpacing = isWide ? 24.0 : 20.0;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: ListView(
                padding: pagePadding,
                children: [
                  _buildHeader(
                    context,
                    data.length,
                    totalEmployees,
                    totalProjects,
                    canEdit,
                  ),
                  if (employeesAsync.isLoading) const LinearProgressIndicator(),
                  if (employeesAsync.hasError) ...[
                    SizedBox(height: sectionSpacing),
                    _ErrorBanner(message: employeesAsync.error.toString()),
                  ],
                  SizedBox(height: sectionSpacing),
                  _buildSearchBar(context),
                  if (!canEdit) ...[
                    SizedBox(height: sectionSpacing),
                    _buildAccessBanner(context),
                  ],
                  SizedBox(height: sectionSpacing),
                  _buildStatsGrid(context, data.length, totalEmployees, departments),
                  SizedBox(height: sectionSpacing),
                  _buildStructureSection(context, filteredData, canEdit),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int supervisorCount,
    int employeeCount,
    int projectCount,
    bool canEdit,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final summaryText =
        '$supervisorCount supervisors • $employeeCount employees • $projectCount active projects';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organization Chart',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              summaryText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        );

        final actions = canEdit
            ? ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  elevation: 6,
                  shadowColor: const Color(0x332563EB),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {},
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                label: const Text('Add Employee'),
              )
            : const SizedBox.shrink();

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              if (canEdit) actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            if (canEdit) ...[
              const SizedBox(height: 12),
              actions,
            ],
          ],
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final inputBorderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    final inputFill = isDark ? const Color(0xFF111827) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          final searchField = TextField(
            controller: _searchController,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.grey[900],
              fontSize: 14,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              hintText: 'Search by name, role, or department...',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
                fontSize: 14,
              ),
              filled: true,
              fillColor: inputFill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: inputBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: inputBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (value) {
              setState(() => _searchTerm = value.trim());
            },
          );
          final filterButton = OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_outlined, size: 16),
            label: const Text('Filter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
              side: BorderSide(color: inputBorderColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                filterButton,
              ],
            );
          }
          return Column(
            children: [
              searchField,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: filterButton),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccessBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E3A8A).withOpacity(0.2)
            : const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF1D4ED8).withOpacity(0.5)
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1D4ED8),
                fontSize: 14,
              ),
          children: const [
            TextSpan(text: '📋 '),
            TextSpan(
              text: 'View-Only Access:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text:
                  ' You can view the organization chart, but editing requires Manager, Admin, or Super Admin permissions.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    int supervisorCount,
    int employeeCount,
    int departmentCount,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final cardShadow = _cardShadow(isDark);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 3 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: columns == 1 ? 3.1 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(
              title: 'Supervisors',
              value: supervisorCount.toString(),
              icon: Icons.groups_outlined,
              iconColor: const Color(0xFF2563EB),
              borderColor: borderColor,
              cardShadow: cardShadow,
            ),
            _StatCard(
              title: 'Total Employees',
              value: employeeCount.toString(),
              icon: Icons.groups_outlined,
              iconColor: const Color(0xFF16A34A),
              borderColor: borderColor,
              cardShadow: cardShadow,
            ),
            _StatCard(
              title: 'Departments',
              value: departmentCount.toString(),
              icon: Icons.groups_outlined,
              iconColor: const Color(0xFF7C3AED),
              borderColor: borderColor,
              cardShadow: cardShadow,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStructureSection(
    BuildContext context,
    List<_Supervisor> supervisors,
    bool canEdit,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final cardShadow = _cardShadow(isDark);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: cardShadow,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Text(
              'Organization Structure',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: supervisors.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Text(
                        _searchTerm.isEmpty
                            ? 'No organization data available yet.'
                            : 'No results found for "$_searchTerm"',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: supervisors
                        .map((supervisor) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SupervisorCard(
                                supervisor: supervisor,
                                isExpanded:
                                    _expandedSupervisors.contains(supervisor.id),
                                onToggle: () {
                                  setState(() {
                                    if (_expandedSupervisors
                                        .contains(supervisor.id)) {
                                      _expandedSupervisors.remove(supervisor.id);
                                    } else {
                                      _expandedSupervisors.add(supervisor.id);
                                    }
                                  });
                                },
                                canEdit: canEdit,
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  List<_Supervisor> _applySearch(
    List<_Supervisor> data,
    String searchTerm,
  ) {
    final query = searchTerm.toLowerCase();
    if (query.isEmpty) return data;
    return data.where((supervisor) {
      final supervisorMatches = supervisor.name.toLowerCase().contains(query) ||
          supervisor.role.toLowerCase().contains(query) ||
          supervisor.department.toLowerCase().contains(query);
      final employeeMatches = supervisor.employees.any(
        (employee) =>
            employee.name.toLowerCase().contains(query) ||
            employee.role.toLowerCase().contains(query),
      );
      return supervisorMatches || employeeMatches;
    }).toList();
  }

  List<_Supervisor> _buildOrganizationData(List<Employee> employees) {
    if (employees.isEmpty) return [];

    final employeesById = <String, Employee>{
      for (final employee in employees) employee.id: employee,
    };
    final employeesByUserId = <String, Employee>{};
    final employeesByEmail = <String, Employee>{};
    final employeesByName = <String, Employee>{};
    final employeesByEmployeeNumber = <String, Employee>{};

    for (final employee in employees) {
      if (employee.userId.isNotEmpty) {
        employeesByUserId[employee.userId] = employee;
      }
      if (employee.email.isNotEmpty) {
        employeesByEmail[employee.email.toLowerCase()] = employee;
      }
      final nameKey = employee.fullName.trim().toLowerCase();
      if (nameKey.isNotEmpty) {
        employeesByName[nameKey] = employee;
      }
      final number = employee.employeeNumber?.trim();
      if (number != null && number.isNotEmpty) {
        employeesByEmployeeNumber[number] = employee;
      }
    }

    Employee? resolveSupervisor(Employee employee) {
      final metadata = employee.metadata ?? const <String, dynamic>{};
      final candidates = [
        metadata['supervisorId'],
        metadata['supervisor_id'],
        metadata['managerId'],
        metadata['manager_id'],
        metadata['leadId'],
        metadata['lead_id'],
        metadata['teamLeadId'],
        metadata['team_lead_id'],
        metadata['reportsTo'],
        metadata['reports_to'],
        metadata['supervisor'],
        metadata['manager'],
        metadata['lead'],
        metadata['teamLead'],
        metadata['supervisorEmail'],
        metadata['managerEmail'],
        metadata['leadEmail'],
        metadata['reportsToEmail'],
        metadata['supervisorName'],
        metadata['managerName'],
        metadata['reportsToName'],
        metadata['leadName'],
      ];

      for (final raw in candidates) {
        final ref = _extractReference(raw);
        if (ref == null || ref.isEmpty) continue;
        final match = _matchEmployee(
          ref,
          byId: employeesById,
          byUserId: employeesByUserId,
          byEmail: employeesByEmail,
          byName: employeesByName,
          byEmployeeNumber: employeesByEmployeeNumber,
        );
        if (match != null && match.id != employee.id) {
          return match;
        }
      }
      return null;
    }

    final reportsBySupervisor = <String, List<Employee>>{};
    final assigned = <String, String>{};

    void assign(Employee employee, Employee supervisor) {
      if (employee.id == supervisor.id) return;
      assigned[employee.id] = supervisor.id;
      reportsBySupervisor.putIfAbsent(supervisor.id, () => []).add(employee);
    }

    for (final employee in employees) {
      final supervisor = resolveSupervisor(employee);
      if (supervisor != null) {
        assign(employee, supervisor);
      }
    }

    final supervisorCandidates = <String, Employee>{};
    for (final supervisorId in reportsBySupervisor.keys) {
      final supervisor = employeesById[supervisorId];
      if (supervisor != null) {
        supervisorCandidates[supervisor.id] = supervisor;
      }
    }
    for (final employee in employees) {
      if (_isSupervisor(employee)) {
        supervisorCandidates[employee.id] = employee;
      }
    }

    if (supervisorCandidates.isEmpty) {
      return _buildDepartmentFallback(employees);
    }

    // Keep a single-level chart by removing supervisors from report lists.
    for (final supervisorId in supervisorCandidates.keys) {
      final managerId = assigned.remove(supervisorId);
      if (managerId != null) {
        reportsBySupervisor[managerId]
            ?.removeWhere((employee) => employee.id == supervisorId);
      }
    }

    final unassigned = <Employee>[];
    for (final employee in employees) {
      if (assigned.containsKey(employee.id)) continue;
      if (supervisorCandidates.containsKey(employee.id)) continue;
      unassigned.add(employee);
    }

    if (unassigned.isNotEmpty) {
      final unassignedByDept = <String, List<Employee>>{};
      for (final employee in unassigned) {
        final dept = _departmentLabel(employee);
        unassignedByDept.putIfAbsent(dept, () => []).add(employee);
      }

      for (final entry in unassignedByDept.entries) {
        final deptSupervisors = supervisorCandidates.values
            .where((candidate) =>
                _departmentLabel(candidate).toLowerCase() ==
                entry.key.toLowerCase())
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));

        if (deptSupervisors.isNotEmpty) {
          final supervisor = deptSupervisors.first;
          for (final employee in entry.value) {
            assign(employee, supervisor);
          }
        } else {
          final leader = _selectDepartmentLeader(entry.value);
          supervisorCandidates[leader.id] = leader;
          for (final employee in entry.value) {
            if (employee.id == leader.id) continue;
            assign(employee, leader);
          }
        }
      }
    }

    final supervisors = supervisorCandidates.values
        .map((supervisor) => _mapSupervisor(
              supervisor,
              reportsBySupervisor[supervisor.id] ?? const [],
            ))
        .toList();

    supervisors.sort((a, b) {
      final dept = a.department.compareTo(b.department);
      if (dept != 0) return dept;
      return a.name.compareTo(b.name);
    });

    return supervisors;
  }

  List<_Supervisor> _buildDepartmentFallback(List<Employee> employees) {
    final groups = <String, List<Employee>>{};
    for (final employee in employees) {
      final dept = _departmentLabel(employee);
      groups.putIfAbsent(dept, () => []).add(employee);
    }

    final supervisors = <_Supervisor>[];
    for (final group in groups.values) {
      final leader = _selectDepartmentLeader(group);
      final reports = group.where((member) => member.id != leader.id).toList();
      supervisors.add(_mapSupervisor(leader, reports));
    }
    supervisors.sort((a, b) {
      final dept = a.department.compareTo(b.department);
      if (dept != 0) return dept;
      return a.name.compareTo(b.name);
    });
    return supervisors;
  }

  Employee _selectDepartmentLeader(List<Employee> employees) {
    if (employees.isEmpty) {
      throw ArgumentError('Department group must have at least one employee.');
    }
    return employees.firstWhere(
      _isSupervisor,
      orElse: () {
        final sorted = [...employees];
        sorted.sort((a, b) {
          final hire = a.hireDate.compareTo(b.hireDate);
          if (hire != 0) return hire;
          return a.fullName.compareTo(b.fullName);
        });
        return sorted.first;
      },
    );
  }

  bool _isSupervisor(Employee employee) {
    final metadata = employee.metadata ?? const <String, dynamic>{};
    if (metadata['isSupervisor'] == true ||
        metadata['isManager'] == true ||
        metadata['isLead'] == true ||
        metadata['isTeamLead'] == true ||
        metadata['isForeman'] == true) {
      return true;
    }
    final title = _roleLabel(employee).toLowerCase();
    return title.contains('supervisor') ||
        title.contains('manager') ||
        title.contains('lead') ||
        title.contains('foreman') ||
        title.contains('director') ||
        title.contains('chief') ||
        title.contains('owner');
  }

  String _departmentLabel(Employee employee) {
    final metadata = employee.metadata ?? const <String, dynamic>{};
    final value = employee.department ??
        _readStringFromMetadata(metadata, [
          'department',
          'dept',
          'team',
          'division',
          'group',
        ]);
    if (value == null || value.trim().isEmpty) return 'General';
    return value.trim();
  }

  String _roleLabel(Employee employee) {
    final metadata = employee.metadata ?? const <String, dynamic>{};
    final value = employee.position ??
        _readStringFromMetadata(metadata, [
          'role',
          'jobTitle',
          'job_title',
          'title',
          'position',
        ]);
    if (value == null || value.trim().isEmpty) return 'Employee';
    return value.trim();
  }

  String _displayName(Employee employee) {
    final name = employee.fullName.trim();
    if (name.isNotEmpty) return name;
    if (employee.email.isNotEmpty) return employee.email;
    return 'Employee ${employee.id}';
  }

  String _initialsFor(Employee employee) {
    final initials = employee.initials.trim();
    if (initials.isNotEmpty) return initials;
    final name = employee.fullName.trim();
    if (name.isNotEmpty) {
      final parts =
          name.split(RegExp(r'\\s+')).where((part) => part.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        return parts.take(2).map((part) => part[0]).join().toUpperCase();
      }
    }
    if (employee.email.isNotEmpty) {
      return employee.email.trim()[0].toUpperCase();
    }
    return '??';
  }

  _Supervisor _mapSupervisor(Employee supervisor, List<Employee> reports) {
    final employees = reports.map(_mapEmployee).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final performance = _supervisorPerformance(supervisor, reports);
    return _Supervisor(
      id: supervisor.id,
      name: _displayName(supervisor),
      role: _roleLabel(supervisor),
      avatar: _initialsFor(supervisor),
      email: supervisor.email.isEmpty ? null : supervisor.email,
      phone: supervisor.phoneNumber,
      teamSize: employees.length,
      projects: _projectsForSupervisor(supervisor, reports),
      performance: performance,
      department: _departmentLabel(supervisor),
      employees: employees,
    );
  }

  _Employee _mapEmployee(Employee employee) {
    return _Employee(
      id: employee.id,
      name: _displayName(employee),
      role: _roleLabel(employee),
      status: _statusFromEmployee(employee),
      performance: _performanceFromMetadata(employee.metadata),
      email: employee.email,
      avatar: _initialsFor(employee),
    );
  }

  _EmployeeStatus _statusFromEmployee(Employee employee) {
    if (!employee.isActive || employee.terminationDate != null) {
      return _EmployeeStatus.onLeave;
    }
    final metadata = employee.metadata ?? const <String, dynamic>{};
    if (metadata['isAway'] == true) return _EmployeeStatus.away;
    if (metadata['isOnLeave'] == true) return _EmployeeStatus.onLeave;
    final statusRaw = _readStringFromMetadata(metadata, [
      'status',
      'availability',
      'state',
    ]);
    final normalized = statusRaw?.toLowerCase() ?? '';
    if (normalized.contains('leave') || normalized.contains('inactive')) {
      return _EmployeeStatus.onLeave;
    }
    if (normalized.contains('away') ||
        normalized.contains('out') ||
        normalized.contains('offline')) {
      return _EmployeeStatus.away;
    }
    return _EmployeeStatus.active;
  }

  int _projectsForSupervisor(Employee supervisor, List<Employee> reports) {
    final metadata = supervisor.metadata ?? const <String, dynamic>{};
    final direct = _readIntFromMetadata(metadata, [
      'projects',
      'projectCount',
      'project_count',
      'activeProjects',
      'active_projects',
    ]);
    if (direct != null) return direct;

    final sites = <String>{};
    void addSite(Employee employee) {
      final meta = employee.metadata ?? const <String, dynamic>{};
      final site = employee.jobSiteName ??
          _readStringFromMetadata(meta, [
            'jobSiteName',
            'job_site_name',
            'site',
            'location',
          ]);
      if (site == null || site.trim().isEmpty) return;
      sites.add(site.trim());
    }

    addSite(supervisor);
    for (final employee in reports) {
      addSite(employee);
    }
    return sites.length;
  }

  int? _supervisorPerformance(Employee supervisor, List<Employee> reports) {
    final direct = _performanceFromMetadata(supervisor.metadata);
    if (direct != null) return direct;
    final scores = reports
        .map((employee) => _performanceFromMetadata(employee.metadata))
        .whereType<int>()
        .toList();
    if (scores.isEmpty) return null;
    final total = scores.reduce((a, b) => a + b);
    return (total / scores.length).round();
  }

  int? _performanceFromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    return _readIntFromMetadata(metadata, [
      'performance',
      'performanceScore',
      'performance_score',
      'performancePercent',
      'performance_percent',
      'score',
      'rating',
      'ratingPercent',
      'rating_percent',
    ]);
  }

  String? _extractReference(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim();
    if (value is int) return value.toString();
    if (value is Map) {
      final id = value['id'] ??
          value['userId'] ??
          value['user_id'] ??
          value['email'] ??
          value['name'] ??
          value['fullName'] ??
          value['full_name'] ??
          value['employeeNumber'] ??
          value['employee_number'];
      if (id != null) {
        final ref = id.toString().trim();
        return ref.isEmpty ? null : ref;
      }
    }
    final ref = value.toString().trim();
    return ref.isEmpty ? null : ref;
  }

  Employee? _matchEmployee(
    String reference, {
    required Map<String, Employee> byId,
    required Map<String, Employee> byUserId,
    required Map<String, Employee> byEmail,
    required Map<String, Employee> byName,
    required Map<String, Employee> byEmployeeNumber,
  }) {
    final trimmed = reference.trim();
    if (trimmed.isEmpty) return null;
    final byDirectId = byId[trimmed];
    if (byDirectId != null) return byDirectId;
    final byUser = byUserId[trimmed];
    if (byUser != null) return byUser;
    final byNumber = byEmployeeNumber[trimmed];
    if (byNumber != null) return byNumber;
    final normalized = trimmed.toLowerCase();
    return byEmail[normalized] ?? byName[normalized];
  }

  String? _readStringFromMetadata(
    Map<String, dynamic> metadata,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = metadata[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  int? _readIntFromMetadata(
    Map<String, dynamic> metadata,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = metadata[key];
      final parsed = _parseInt(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) {
      if (value <= 1) return (value * 100).round();
      return value.round();
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final cleaned = text.replaceAll('%', '');
    final asInt = int.tryParse(cleaned);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(cleaned);
    if (asDouble == null) return null;
    if (asDouble <= 1) return (asDouble * 100).round();
    return asDouble.round();
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.cardShadow,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final List<BoxShadow> cardShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconBackground = iconColor.withOpacity(isDark ? 0.25 : 0.15);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupervisorCard extends StatelessWidget {
  const _SupervisorCard({
    required this.supervisor,
    required this.isExpanded,
    required this.onToggle,
    required this.canEdit,
  });

  final _Supervisor supervisor;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final performanceValue = supervisor.performance;
    final performanceColor = performanceValue == null
        ? (isDark ? Colors.grey[400] : Colors.grey[500])
        : _performanceColor(performanceValue);
    final headerGradient = LinearGradient(
      colors: isDark
          ? [
              const Color(0xFF1E3A8A).withOpacity(0.35),
              const Color(0xFF312E81).withOpacity(0.3),
            ]
          : [
              const Color(0xFFDBEAFE),
              const Color(0xFFE0E7FF),
            ],
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: headerGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: onToggle,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  iconSize: 20,
                  icon: Icon(
                    isExpanded
                        ? Icons.expand_more
                        : Icons.chevron_right,
                    color: isDark ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    supervisor.avatar,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supervisor.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${supervisor.role} • ${supervisor.department}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if ((supervisor.email ?? '').isNotEmpty)
                                      _InlineIconText(
                                        icon: Icons.email_outlined,
                                        label: supervisor.email!,
                                      ),
                                    if ((supervisor.phone ?? '').isNotEmpty)
                                      _InlineIconText(
                                        icon: Icons.phone_outlined,
                                        label: supervisor.phone!,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (canEdit)
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                size: 20,
                                color:
                                    isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              color: isDark
                                  ? const Color(0xFF1F2937)
                                  : Colors.white,
                              onSelected: (value) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$value selected')),
                                );
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'Edit Details',
                                  child: _MenuItem(
                                    icon: Icons.edit_outlined,
                                    label: 'Edit Details',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'Add Team Member',
                                  child: _MenuItem(
                                    icon: Icons.person_add_alt_1_outlined,
                                    label: 'Add Team Member',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'Remove',
                                  child: _MenuItem(
                                    icon: Icons.delete_outline,
                                    label: 'Remove',
                                    isDestructive: true,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatMini(
                            label: 'Team',
                            value: supervisor.teamSize.toString(),
                          ),
                          _StatMini(
                            label: 'Projects',
                            value: supervisor.projects.toString(),
                          ),
                          _StatMini(
                            label: 'Performance',
                            value: performanceValue != null
                                ? '$performanceValue%'
                                : '--',
                            valueColor: performanceColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded && supervisor.employees.isNotEmpty)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFF9FAFB),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(0),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? const Color(0xFF4B5563)
                              : const Color(0xFFE5E7EB),
                        ),
                        bottom: BorderSide(
                          color: isDark
                              ? const Color(0xFF4B5563)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    child: Text(
                      'TEAM MEMBERS (${supervisor.employees.length})',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.4,
                            color: isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  ...supervisor.employees.map(
                    (employee) => _EmployeeRow(
                      employee: employee,
                      canEdit: canEdit,
                      showDivider: employee != supervisor.employees.last,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineIconText extends StatelessWidget {
  const _InlineIconText({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
        : (isDark ? Colors.grey[300] : Colors.grey[700]);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  fontSize: 18,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({
    required this.employee,
    required this.canEdit,
    required this.showDivider,
  });

  final _Employee employee;
  final bool canEdit;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final statusColor = _statusColor(employee.status);

    final hoverColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB);
    final content = Row(
      children: [
        Stack(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF9CA3AF),
                    Color(0xFF4B5563),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                employee.avatar,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                employee.role,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
              ),
              if (employee.email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  employee.email,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (canEdit)
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.more_vert,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            iconSize: 16,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        hoverColor: hoverColor,
        child: Container(
          padding: const EdgeInsets.fromLTRB(64, 16, 16, 16),
          decoration: BoxDecoration(
            border:
                showDivider ? Border(bottom: BorderSide(color: borderColor)) : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF991B1B),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _performanceColor(int performance) {
  if (performance >= 90) {
    return const Color(0xFF22C55E);
  }
  if (performance >= 75) {
    return const Color(0xFF3B82F6);
  }
  return const Color(0xFFF97316);
}

Color _statusColor(_EmployeeStatus status) {
  switch (status) {
    case _EmployeeStatus.active:
      return const Color(0xFF22C55E);
    case _EmployeeStatus.away:
      return const Color(0xFFF59E0B);
    case _EmployeeStatus.onLeave:
      return const Color(0xFF9CA3AF);
  }
}

List<BoxShadow> _cardShadow(bool isDark) {
  return [
    BoxShadow(
      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

class _Supervisor {
  const _Supervisor({
    required this.id,
    required this.name,
    required this.role,
    required this.avatar,
    required this.email,
    required this.phone,
    required this.teamSize,
    required this.projects,
    required this.performance,
    required this.department,
    required this.employees,
  });

  final String id;
  final String name;
  final String role;
  final String avatar;
  final String? email;
  final String? phone;
  final int teamSize;
  final int projects;
  final int? performance;
  final String department;
  final List<_Employee> employees;
}

class _Employee {
  const _Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.performance,
    required this.email,
    required this.avatar,
  });

  final String id;
  final String name;
  final String role;
  final _EmployeeStatus status;
  final int? performance;
  final String email;
  final String avatar;
}

enum _EmployeeStatus { active, away, onLeave }
