-- Migration: Add employees records for "Your Company" demo organization
-- Maps profiles to employees table with departments, positions, and team assignments

INSERT INTO employees (
  id,
  org_id,
  user_id,
  first_name,
  last_name,
  email,
  department,
  position,
  hire_date,
  is_active,
  metadata,
  created_at,
  updated_at
) VALUES
  -- Owner/Super Admin
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222201',
    'Alex', 'Owner',
    'owner@yourcompany.test',
    'Executive',
    'CEO / Owner',
    NOW() - INTERVAL '5 years',
    true,
    '{"isSupervisor": true, "isManager": true}'::jsonb,
    NOW(), NOW()
  ),
  -- Admin
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee02',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222202',
    'Jordan', 'Admin',
    'admin@yourcompany.test',
    'Administration',
    'System Administrator',
    NOW() - INTERVAL '3 years',
    true,
    '{"isSupervisor": true, "supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01"}'::jsonb,
    NOW(), NOW()
  ),
  -- Manager 1 - Operations
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee03',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222203',
    'Sam', 'Manager',
    'manager1@yourcompany.test',
    'Operations',
    'Operations Manager',
    NOW() - INTERVAL '4 years',
    true,
    '{"isSupervisor": true, "isManager": true, "supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01"}'::jsonb,
    NOW(), NOW()
  ),
  -- Manager 2 - Safety
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee04',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222204',
    'Pat', 'Director',
    'manager2@yourcompany.test',
    'Safety',
    'Safety Director',
    NOW() - INTERVAL '3 years',
    true,
    '{"isSupervisor": true, "isManager": true, "supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01"}'::jsonb,
    NOW(), NOW()
  ),
  -- Supervisor 1 - Reports to Operations Manager
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee05',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222205',
    'Taylor', 'Supervisor',
    'supervisor1@yourcompany.test',
    'Operations',
    'Team Lead - Alpha',
    NOW() - INTERVAL '2 years',
    true,
    '{"isSupervisor": true, "supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee03"}'::jsonb,
    NOW(), NOW()
  ),
  -- Supervisor 2 - Reports to Operations Manager
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee06',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222206',
    'Robin', 'Lead',
    'supervisor2@yourcompany.test',
    'Operations',
    'Team Lead - Beta',
    NOW() - INTERVAL '2 years',
    true,
    '{"isSupervisor": true, "supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee03"}'::jsonb,
    NOW(), NOW()
  ),
  -- Supervisor 3 - Reports to Safety Director
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee07',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222207',
    'Drew', 'Foreman',
    'supervisor3@yourcompany.test',
    'Safety',
    'Safety Foreman',
    NOW() - INTERVAL '2 years',
    true,
    '{"isSupervisor": true, "isForeman": true, "supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee04"}'::jsonb,
    NOW(), NOW()
  ),
  -- Employee 1 - Team Alpha
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee08',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222208',
    'Casey', 'Worker',
    'employee1@yourcompany.test',
    'Operations',
    'Field Technician',
    NOW() - INTERVAL '1 year',
    true,
    '{"supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee05", "performance": 92}'::jsonb,
    NOW(), NOW()
  ),
  -- Employee 2 - Team Alpha
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee09',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222209',
    'Avery', 'Smith',
    'employee2@yourcompany.test',
    'Operations',
    'Field Technician',
    NOW() - INTERVAL '1 year',
    true,
    '{"supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee05", "performance": 88}'::jsonb,
    NOW(), NOW()
  ),
  -- Employee 3 - Team Alpha
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee10',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222210',
    'Blake', 'Johnson',
    'employee3@yourcompany.test',
    'Operations',
    'Senior Technician',
    NOW() - INTERVAL '18 months',
    true,
    '{"supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee05", "performance": 95}'::jsonb,
    NOW(), NOW()
  ),
  -- Employee 4 - Team Beta
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee11',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222211',
    'Charlie', 'Williams',
    'employee4@yourcompany.test',
    'Operations',
    'Equipment Operator',
    NOW() - INTERVAL '1 year',
    true,
    '{"supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee06", "performance": 85}'::jsonb,
    NOW(), NOW()
  ),
  -- Employee 5 - Team Beta
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee12',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222212',
    'Dakota', 'Brown',
    'employee5@yourcompany.test',
    'Operations',
    'Equipment Operator',
    NOW() - INTERVAL '8 months',
    true,
    '{"supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee06", "performance": 78}'::jsonb,
    NOW(), NOW()
  ),
  -- Employee 6 - Team Beta
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee13',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222213',
    'Emery', 'Davis',
    'employee6@yourcompany.test',
    'Operations',
    'Logistics Coordinator',
    NOW() - INTERVAL '14 months',
    true,
    '{"supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee06", "performance": 91}'::jsonb,
    NOW(), NOW()
  ),
  -- Employee 7 - Safety Team
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee14',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222214',
    'Finley', 'Miller',
    'employee7@yourcompany.test',
    'Safety',
    'Safety Inspector',
    NOW() - INTERVAL '1 year',
    true,
    '{"supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee07", "performance": 94}'::jsonb,
    NOW(), NOW()
  ),
  -- Employee 8 - Safety Team
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee15',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222215',
    'Gray', 'Wilson',
    'employee8@yourcompany.test',
    'Safety',
    'Safety Coordinator',
    NOW() - INTERVAL '10 months',
    true,
    '{"supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee07", "performance": 87}'::jsonb,
    NOW(), NOW()
  ),
  -- Maintenance 1
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee16',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222216',
    'Morgan', 'Tech',
    'maintenance1@yourcompany.test',
    'Maintenance',
    'Lead Mechanic',
    NOW() - INTERVAL '3 years',
    true,
    '{"isSupervisor": true, "supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee03", "performance": 96}'::jsonb,
    NOW(), NOW()
  ),
  -- Maintenance 2
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee17',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222217',
    'Reese', 'Mechanic',
    'maintenance2@yourcompany.test',
    'Maintenance',
    'Mechanic',
    NOW() - INTERVAL '1 year',
    true,
    '{"supervisorId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeee16", "performance": 82}'::jsonb,
    NOW(), NOW()
  ),
  -- Client 1
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee18',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222218',
    'Riley', 'Client',
    'client1@yourcompany.test',
    'External',
    'Client Representative',
    NOW() - INTERVAL '6 months',
    true,
    '{}'::jsonb,
    NOW(), NOW()
  ),
  -- Client 2
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee19',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222219',
    'Sage', 'Customer',
    'client2@yourcompany.test',
    'External',
    'Client Representative',
    NOW() - INTERVAL '4 months',
    true,
    '{}'::jsonb,
    NOW(), NOW()
  ),
  -- Vendor 1
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee20',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222220',
    'Quinn', 'Supplier',
    'vendor1@yourcompany.test',
    'External',
    'Vendor Contact',
    NOW() - INTERVAL '8 months',
    true,
    '{}'::jsonb,
    NOW(), NOW()
  ),
  -- Vendor 2
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee21',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222221',
    'Parker', 'Contractor',
    'vendor2@yourcompany.test',
    'External',
    'Contractor',
    NOW() - INTERVAL '5 months',
    true,
    '{}'::jsonb,
    NOW(), NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name,
  last_name = EXCLUDED.last_name,
  email = EXCLUDED.email,
  department = EXCLUDED.department,
  position = EXCLUDED.position,
  hire_date = EXCLUDED.hire_date,
  is_active = EXCLUDED.is_active,
  metadata = EXCLUDED.metadata,
  updated_at = NOW();
