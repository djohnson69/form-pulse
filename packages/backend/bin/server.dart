import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

// In-memory demo data so the mobile prototype has something to talk to.
final _forms = <Map<String, dynamic>>[
  {
    'id': 'jobsite-safety',
    'title': 'Job Site Safety Walk',
    'description': '15-point safety walkthrough with photo capture',
    'category': 'Safety',
    'tags': ['safety', 'construction', 'audit'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'system',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String(),
    'updatedAt': DateTime.now()
        .subtract(const Duration(hours: 6))
        .toIso8601String(),
    'fields': [
      {
        'id': 'siteName',
        'label': 'Site name',
        'type': 'text',
        'placeholder': 'South Plant 7',
        'isRequired': true,
        'order': 1,
      },
      {
        'id': 'inspector',
        'label': 'Inspector',
        'type': 'text',
        'placeholder': 'Your name',
        'isRequired': true,
        'order': 2,
      },
      {
        'id': 'ppe',
        'label': 'PPE compliance',
        'type': 'checkbox',
        'options': ['Hard hat', 'Vest', 'Gloves', 'Eye protection'],
        'isRequired': true,
        'order': 3,
      },
      {
        'id': 'hazards',
        'label': 'Hazards observed',
        'type': 'textarea',
        'order': 4,
      },
      {'id': 'photos', 'label': 'Attach photos', 'type': 'photo', 'order': 5},
      {
        'id': 'location',
        'label': 'GPS location',
        'type': 'location',
        'order': 6,
      },
      {
        'id': 'signature',
        'label': 'Supervisor signature',
        'type': 'signature',
        'order': 7,
      },
    ],
    'metadata': {'riskLevel': 'medium'},
  },
  {
    'id': 'equipment-checkout',
    'title': 'Equipment Checkout',
    'description': 'Log equipment issue/return with QR scan',
    'category': 'Operations',
    'tags': ['inventory', 'logistics', 'assets'],
    'isPublished': true,
    'version': '1.1.0',
    'createdBy': 'system',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 5))
        .toIso8601String(),
    'fields': [
      {
        'id': 'assetTag',
        'label': 'Asset tag / QR',
        'type': 'barcode',
        'order': 1,
        'isRequired': true,
      },
      {
        'id': 'condition',
        'label': 'Condition',
        'type': 'radio',
        'options': ['Excellent', 'Good', 'Fair', 'Damaged'],
        'order': 2,
        'isRequired': true,
      },
      {'id': 'notes', 'label': 'Notes', 'type': 'textarea', 'order': 3},
      {
        'id': 'photos',
        'label': 'Proof of condition',
        'type': 'photo',
        'order': 4,
      },
    ],
    'metadata': {'requiresSupervisor': true},
  },
  {
    'id': 'visitor-log',
    'title': 'Visitor Log',
    'description': 'Quick intake with badge printing flag',
    'category': 'Security',
    'tags': ['security', 'front-desk'],
    'isPublished': true,
    'version': '0.9.0',
    'createdBy': 'system',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {
        'id': 'fullName',
        'label': 'Full name',
        'type': 'text',
        'order': 1,
        'isRequired': true,
      },
      {'id': 'company', 'label': 'Company', 'type': 'text', 'order': 2},
      {'id': 'host', 'label': 'Host', 'type': 'text', 'order': 3},
      {
        'id': 'purpose',
        'label': 'Purpose',
        'type': 'dropdown',
        'options': ['Delivery', 'Interview', 'Maintenance', 'Audit', 'Other'],
        'order': 4,
      },
      {
        'id': 'arrivedAt',
        'label': 'Arrival time',
        'type': 'datetime',
        'order': 5,
      },
      {'id': 'badge', 'label': 'Badge required', 'type': 'toggle', 'order': 6},
    ],
  },
  {
    'id': 'bar-inventory',
    'title': 'Bar Inventory Count',
    'description':
        'Fast bar/restaurant inventory with barcode scans and par levels',
    'category': 'Hospitality',
    'tags': ['hospitality', 'inventory', 'bar'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 4))
        .toIso8601String(),
    'fields': [
      {
        'id': 'location',
        'label': 'Bar location',
        'type': 'dropdown',
        'options': ['Main bar', 'Patio bar', 'Banquet bar'],
        'order': 1,
        'isRequired': true,
      },
      {
        'id': 'bottles',
        'label': 'Bottle counts',
        'type': 'repeater',
        'order': 2,
        'children': [
          {
            'id': 'sku',
            'label': 'SKU / Barcode',
            'type': 'barcode',
            'order': 1,
            'isRequired': true,
          },
          {
            'id': 'name',
            'label': 'Item name',
            'type': 'text',
            'order': 2,
            'isRequired': true,
          },
          {
            'id': 'par',
            'label': 'Par level (bottles)',
            'type': 'number',
            'order': 3,
          },
          {
            'id': 'onHand',
            'label': 'On-hand (bottles)',
            'type': 'number',
            'order': 4,
          },
          {
            'id': 'variance',
            'label': 'Variance',
            'type': 'computed',
            'order': 5,
            'calculations': {'expression': 'onHand - par'},
          },
        ],
      },
      {'id': 'photos', 'label': 'Shelf photos', 'type': 'photo', 'order': 3},
      {'id': 'notes', 'label': 'Notes', 'type': 'textarea', 'order': 4},
    ],
    'metadata': {'template': 'hospitality-inventory'},
  },
  {
    'id': 'incident-report',
    'title': 'Security Incident Report',
    'description':
        'Capture security incidents with photos, severity, and signatures',
    'category': 'Security',
    'tags': ['security', 'incident', 'safety'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {
        'id': 'incidentType',
        'label': 'Incident type',
        'type': 'dropdown',
        'options': [
          'Theft',
          'Vandalism',
          'Injury',
          'Suspicious activity',
          'Other',
        ],
        'order': 1,
        'isRequired': true,
      },
      {
        'id': 'severity',
        'label': 'Severity',
        'type': 'radio',
        'options': ['Low', 'Medium', 'High', 'Critical'],
        'order': 2,
        'isRequired': true,
      },
      {
        'id': 'description',
        'label': 'Description',
        'type': 'textarea',
        'order': 3,
        'isRequired': true,
      },
      {
        'id': 'attachments',
        'label': 'Photo/video evidence',
        'type': 'photo',
        'order': 4,
      },
      {
        'id': 'witnesses',
        'label': 'Witnesses',
        'type': 'repeater',
        'order': 5,
        'children': [
          {'id': 'name', 'label': 'Name', 'type': 'text', 'order': 1},
          {'id': 'contact', 'label': 'Contact', 'type': 'phone', 'order': 2},
          {
            'id': 'statement',
            'label': 'Statement',
            'type': 'textarea',
            'order': 3,
          },
        ],
      },
      {
        'id': 'location',
        'label': 'GPS location',
        'type': 'location',
        'order': 6,
      },
      {
        'id': 'signature',
        'label': 'Reporting officer signature',
        'type': 'signature',
        'order': 7,
      },
    ],
    'metadata': {'template': 'security-incident'},
  },
  {
    'id': 'maintenance-check',
    'title': 'Maintenance & Equipment Check',
    'description':
        'Routine maintenance checklist with parts used and approvals',
    'category': 'Operations',
    'tags': ['maintenance', 'operations', 'equipment'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String(),
    'fields': [
      {
        'id': 'asset',
        'label': 'Asset scanned',
        'type': 'barcode',
        'order': 1,
        'isRequired': true,
      },
      {
        'id': 'tasks',
        'label': 'Tasks performed',
        'type': 'checkbox',
        'options': [
          'Inspection',
          'Lubrication',
          'Calibration',
          'Repair',
          'Replacement',
        ],
        'order': 2,
      },
      {
        'id': 'parts',
        'label': 'Parts used',
        'type': 'table',
        'order': 3,
        'children': [
          {'id': 'part', 'label': 'Part #', 'type': 'text', 'order': 1},
          {'id': 'qty', 'label': 'Qty', 'type': 'number', 'order': 2},
        ],
      },
      {
        'id': 'photos',
        'label': 'Before/after photos',
        'type': 'photo',
        'order': 4,
      },
      {'id': 'notes', 'label': 'Notes', 'type': 'textarea', 'order': 5},
      {
        'id': 'approval',
        'label': 'Supervisor signature',
        'type': 'signature',
        'order': 6,
      },
    ],
    'metadata': {'template': 'maintenance'},
  },
  {
    'id': 'audit-checklist',
    'title': 'Internal Audit Checklist',
    'description': 'ISO-style audit checklist with scoring and evidence',
    'category': 'Audit',
    'tags': ['audit', 'compliance', 'iso'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String(),
    'fields': [
      {
        'id': 'area',
        'label': 'Area audited',
        'type': 'dropdown',
        'options': ['Warehouse', 'Production', 'Office', 'IT'],
        'order': 1,
        'isRequired': true,
      },
      {
        'id': 'sections',
        'label': 'Audit items',
        'type': 'repeater',
        'order': 2,
        'children': [
          {'id': 'clause', 'label': 'Clause', 'type': 'text', 'order': 1},
          {'id': 'score', 'label': 'Score (0-5)', 'type': 'number', 'order': 2},
          {'id': 'evidence', 'label': 'Evidence', 'type': 'photo', 'order': 3},
        ],
      },
      {
        'id': 'overall',
        'label': 'Overall score',
        'type': 'computed',
        'order': 3,
        'calculations': {'expression': 'score / 1'},
      },
      {
        'id': 'actions',
        'label': 'Follow-up actions',
        'type': 'textarea',
        'order': 4,
      },
    ],
    'metadata': {'template': 'audit'},
  },
  {
    'id': 'food-safety-log',
    'title': 'Food Safety & Temp Log',
    'description':
        'HACCP-style log for temperatures, sanitizer, and corrective actions',
    'category': 'Food Safety',
    'tags': ['hospitality', 'food', 'safety'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {
        'id': 'station',
        'label': 'Station',
        'type': 'dropdown',
        'options': ['Prep', 'Line', 'Walk-in', 'Dish'],
        'order': 1,
      },
      {
        'id': 'readings',
        'label': 'Temperature readings',
        'type': 'table',
        'order': 2,
        'children': [
          {'id': 'item', 'label': 'Item', 'type': 'text', 'order': 1},
          {'id': 'temp', 'label': 'Temp (°F)', 'type': 'number', 'order': 2},
          {
            'id': 'corrective',
            'label': 'Corrective action',
            'type': 'textarea',
            'order': 3,
          },
        ],
      },
      {
        'id': 'sanitizer',
        'label': 'Sanitizer PPM',
        'type': 'number',
        'order': 3,
      },
      {
        'id': 'signature',
        'label': 'Supervisor signature',
        'type': 'signature',
        'order': 4,
      },
    ],
    'metadata': {'template': 'food-safety'},
  },
  {
    'id': 'hr-onboarding',
    'title': 'HR Onboarding Checklist',
    'description':
        'Collect documents, equipment, and training acknowledgements',
    'category': 'HR',
    'tags': ['hr', 'onboarding', 'people'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 6))
        .toIso8601String(),
    'fields': [
      {
        'id': 'employee',
        'label': 'Employee name',
        'type': 'text',
        'order': 1,
        'isRequired': true,
      },
      {'id': 'role', 'label': 'Role', 'type': 'text', 'order': 2},
      {
        'id': 'equipment',
        'label': 'Equipment issued',
        'type': 'checkbox',
        'order': 3,
        'options': ['Laptop', 'Badge', 'PPE', 'Phone'],
      },
      {
        'id': 'documents',
        'label': 'Documents collected',
        'type': 'files',
        'order': 4,
      },
      {
        'id': 'training',
        'label': 'Training acknowledgements',
        'type': 'repeater',
        'order': 5,
        'children': [
          {'id': 'course', 'label': 'Course', 'type': 'text', 'order': 1},
          {
            'id': 'status',
            'label': 'Status',
            'type': 'dropdown',
            'options': ['Pending', 'Completed'],
            'order': 2,
          },
        ],
      },
      {
        'id': 'signature',
        'label': 'Manager signature',
        'type': 'signature',
        'order': 6,
      },
    ],
    'metadata': {'template': 'hr-onboarding'},
  },
  {
    'id': 'osha-incident',
    'title': 'OSHA Recordable Incident',
    'description':
        'Capture OSHA reportable incidents with severity, treatment, and root cause',
    'category': 'Safety',
    'tags': ['osha', 'safety', 'incident'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String(),
    'fields': [
      {
        'id': 'incidentDate',
        'label': 'Incident date/time',
        'type': 'datetime',
        'order': 1,
        'isRequired': true,
      },
      {
        'id': 'classification',
        'label': 'Classification',
        'type': 'dropdown',
        'options': ['Recordable', 'First aid', 'Near miss'],
        'order': 2,
        'isRequired': true,
      },
      {
        'id': 'injuryType',
        'label': 'Injury type',
        'type': 'checkbox',
        'options': ['Laceration', 'Sprain', 'Fracture', 'Burn', 'Other'],
        'order': 3,
      },
      {'id': 'treatment', 'label': 'Treatment', 'type': 'textarea', 'order': 4},
      {'id': 'attachments', 'label': 'Photos', 'type': 'photo', 'order': 5},
      {
        'id': 'rootCause',
        'label': 'Root cause',
        'type': 'textarea',
        'order': 6,
      },
      {
        'id': 'signature',
        'label': 'Safety officer signature',
        'type': 'signature',
        'order': 7,
      },
    ],
    'metadata': {'template': 'osha'},
  },
  {
    'id': 'vehicle-inspection',
    'title': 'Vehicle / DVIR Inspection',
    'description': 'Daily vehicle inspection with defects and sign-off',
    'category': 'Fleet',
    'tags': ['fleet', 'dvir', 'transport'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String(),
    'fields': [
      {
        'id': 'vehicleId',
        'label': 'Vehicle ID',
        'type': 'text',
        'order': 1,
        'isRequired': true,
      },
      {'id': 'odometer', 'label': 'Odometer', 'type': 'number', 'order': 2},
      {
        'id': 'checks',
        'label': 'Inspection items',
        'type': 'checkbox',
        'options': ['Lights', 'Brakes', 'Tires', 'Fluids', 'Wipers', 'Horn'],
        'order': 3,
      },
      {
        'id': 'defects',
        'label': 'Defects noted',
        'type': 'repeater',
        'order': 4,
        'children': [
          {'id': 'component', 'label': 'Component', 'type': 'text', 'order': 1},
          {
            'id': 'severity',
            'label': 'Severity',
            'type': 'dropdown',
            'options': ['Low', 'Med', 'High'],
            'order': 2,
          },
        ],
      },
      {'id': 'photos', 'label': 'Photos', 'type': 'photo', 'order': 5},
      {
        'id': 'signature',
        'label': 'Driver signature',
        'type': 'signature',
        'order': 6,
      },
    ],
    'metadata': {'template': 'dvir'},
  },
  {
    'id': 'retail-audit',
    'title': 'Retail Store Audit',
    'description': 'Merchandising, pricing, cleanliness, and compliance audit',
    'category': 'Retail',
    'tags': ['retail', 'audit', 'merchandising'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String(),
    'fields': [
      {'id': 'store', 'label': 'Store ID', 'type': 'text', 'order': 1},
      {
        'id': 'pricing',
        'label': 'Pricing accuracy',
        'type': 'radio',
        'options': ['Excellent', 'Good', 'Fair', 'Poor'],
        'order': 2,
      },
      {
        'id': 'displays',
        'label': 'Display compliance',
        'type': 'checkbox',
        'options': ['Endcaps set', 'Promo signage', 'Planogram alignment'],
        'order': 3,
      },
      {'id': 'photos', 'label': 'Shelf photos', 'type': 'photo', 'order': 4},
      {'id': 'issues', 'label': 'Issues', 'type': 'textarea', 'order': 5},
    ],
    'metadata': {'template': 'retail-audit'},
  },
  {
    'id': 'patient-rounding',
    'title': 'Patient Rounding Checklist',
    'description': 'Nurse rounding checklist with vitals and comfort checks',
    'category': 'Healthcare',
    'tags': ['healthcare', 'rounding', 'hospital'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {'id': 'patient', 'label': 'Patient name', 'type': 'text', 'order': 1},
      {'id': 'room', 'label': 'Room', 'type': 'text', 'order': 2},
      {'id': 'vitals', 'label': 'Vitals OK', 'type': 'toggle', 'order': 3},
      {
        'id': 'comfort',
        'label': 'Comfort checks',
        'type': 'checkbox',
        'options': ['Pain', 'Position', 'Potty', 'Periphery', 'Personal items'],
        'order': 4,
      },
      {'id': 'notes', 'label': 'Notes', 'type': 'textarea', 'order': 5},
      {
        'id': 'signature',
        'label': 'Nurse signature',
        'type': 'signature',
        'order': 6,
      },
    ],
    'metadata': {'template': 'patient-rounding'},
  },
  {
    'id': 'insurance-claim',
    'title': 'Insurance Claim Intake',
    'description': 'Capture incident details, parties involved, and evidence',
    'category': 'Insurance',
    'tags': ['insurance', 'claims', 'intake'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 4))
        .toIso8601String(),
    'fields': [
      {
        'id': 'claimant',
        'label': 'Claimant name',
        'type': 'text',
        'order': 1,
        'isRequired': true,
      },
      {'id': 'policy', 'label': 'Policy #', 'type': 'text', 'order': 2},
      {'id': 'lossDate', 'label': 'Loss date', 'type': 'date', 'order': 3},
      {
        'id': 'lossType',
        'label': 'Loss type',
        'type': 'dropdown',
        'options': ['Auto', 'Property', 'Injury'],
        'order': 4,
      },
      {
        'id': 'description',
        'label': 'Description',
        'type': 'textarea',
        'order': 5,
      },
      {'id': 'attachments', 'label': 'Evidence', 'type': 'photo', 'order': 6},
      {
        'id': 'signature',
        'label': 'Adjuster signature',
        'type': 'signature',
        'order': 7,
      },
    ],
    'metadata': {'template': 'insurance-claim'},
  },
  {
    'id': 'facility-work-order',
    'title': 'Facility Work Order',
    'description': 'Log facility issues, priority, and completion proof',
    'category': 'Facilities',
    'tags': ['facilities', 'maintenance', 'work-order'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String(),
    'fields': [
      {
        'id': 'location',
        'label': 'Location',
        'type': 'text',
        'order': 1,
        'isRequired': true,
      },
      {
        'id': 'priority',
        'label': 'Priority',
        'type': 'dropdown',
        'options': ['Low', 'Medium', 'High'],
        'order': 2,
      },
      {
        'id': 'issue',
        'label': 'Issue description',
        'type': 'textarea',
        'order': 3,
      },
      {'id': 'photos', 'label': 'Photos', 'type': 'photo', 'order': 4},
      {'id': 'completed', 'label': 'Completed', 'type': 'toggle', 'order': 5},
      {
        'id': 'signature',
        'label': 'Supervisor sign-off',
        'type': 'signature',
        'order': 6,
      },
    ],
    'metadata': {'template': 'facility-work-order'},
  },
  {
    'id': 'daily-report',
    'title': 'Construction Daily Report',
    'description': 'Weather, manpower, equipment, delays, and photos',
    'category': 'Construction',
    'tags': ['construction', 'daily', 'report'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {
        'id': 'weather',
        'label': 'Weather',
        'type': 'dropdown',
        'options': ['Clear', 'Cloudy', 'Rain', 'Snow'],
        'order': 1,
      },
      {'id': 'crew', 'label': 'Crew on site', 'type': 'number', 'order': 2},
      {
        'id': 'equipment',
        'label': 'Key equipment in use',
        'type': 'checkbox',
        'options': ['Crane', 'Loader', 'Lift', 'Compactor'],
        'order': 3,
      },
      {
        'id': 'delays',
        'label': 'Delays/Issues',
        'type': 'textarea',
        'order': 4,
      },
      {'id': 'photos', 'label': 'Site photos', 'type': 'photo', 'order': 5},
    ],
    'metadata': {'template': 'daily-report'},
  },
  {
    'id': 'quality-inspection',
    'title': 'Quality Inspection',
    'description': 'Punchlist/quality inspection with defects and photos',
    'category': 'Quality',
    'tags': ['quality', 'inspection', 'punchlist'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String(),
    'fields': [
      {'id': 'area', 'label': 'Area/Room', 'type': 'text', 'order': 1},
      {
        'id': 'items',
        'label': 'Items inspected',
        'type': 'table',
        'order': 2,
        'children': [
          {'id': 'item', 'label': 'Item', 'type': 'text', 'order': 1},
          {
            'id': 'status',
            'label': 'Status',
            'type': 'dropdown',
            'options': ['Pass', 'Fail'],
            'order': 2,
          },
        ],
      },
      {'id': 'photos', 'label': 'Photos', 'type': 'photo', 'order': 3},
      {
        'id': 'signature',
        'label': 'Inspector signature',
        'type': 'signature',
        'order': 4,
      },
    ],
    'metadata': {'template': 'quality-inspection'},
  },
  {
    'id': 'environmental-audit',
    'title': 'Environmental Audit',
    'description': 'Spill kits, waste, emissions, and observations',
    'category': 'Environmental',
    'tags': ['environmental', 'audit', 'compliance'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 5))
        .toIso8601String(),
    'fields': [
      {
        'id': 'spillKits',
        'label': 'Spill kits stocked',
        'type': 'toggle',
        'order': 1,
      },
      {
        'id': 'waste',
        'label': 'Waste storage',
        'type': 'dropdown',
        'options': ['Compliant', 'Needs attention'],
        'order': 2,
      },
      {
        'id': 'observations',
        'label': 'Observations',
        'type': 'textarea',
        'order': 3,
      },
      {'id': 'photos', 'label': 'Photos', 'type': 'photo', 'order': 4},
      {
        'id': 'signature',
        'label': 'Auditor signature',
        'type': 'signature',
        'order': 5,
      },
    ],
    'metadata': {'template': 'environmental-audit'},
  },
  {
    'id': 'customer-feedback',
    'title': 'Customer Feedback',
    'description': 'Capture CSAT, comments, and follow-up details',
    'category': 'Customer',
    'tags': ['customer', 'feedback', 'csat'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String(),
    'fields': [
      {'id': 'name', 'label': 'Name', 'type': 'text', 'order': 1},
      {
        'id': 'rating',
        'label': 'Satisfaction (1-5)',
        'type': 'number',
        'order': 2,
      },
      {'id': 'comments', 'label': 'Comments', 'type': 'textarea', 'order': 3},
      {
        'id': 'followup',
        'label': 'Need follow-up',
        'type': 'toggle',
        'order': 4,
      },
    ],
    'metadata': {'template': 'customer-feedback'},
  },
  {
    'id': 'it-ticket',
    'title': 'IT Ticket',
    'description':
        'Issue category, device, severity, attachments, and sign-off',
    'category': 'IT',
    'tags': ['it', 'ticket', 'support'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 4))
        .toIso8601String(),
    'fields': [
      {'id': 'user', 'label': 'User', 'type': 'text', 'order': 1},
      {'id': 'device', 'label': 'Device', 'type': 'text', 'order': 2},
      {
        'id': 'category',
        'label': 'Category',
        'type': 'dropdown',
        'options': ['Access', 'Hardware', 'Software', 'Network'],
        'order': 3,
      },
      {
        'id': 'severity',
        'label': 'Severity',
        'type': 'dropdown',
        'options': ['Low', 'Medium', 'High'],
        'order': 4,
      },
      {
        'id': 'description',
        'label': 'Description',
        'type': 'textarea',
        'order': 5,
      },
      {
        'id': 'attachments',
        'label': 'Attachments',
        'type': 'photo',
        'order': 6,
      },
      {
        'id': 'signature',
        'label': 'Technician signature',
        'type': 'signature',
        'order': 7,
      },
    ],
    'metadata': {'template': 'it-ticket'},
  },
  {
    'id': 'safety-observation',
    'title': 'Safety Observation',
    'description':
        'Positive/negative safety observations with photos and categories',
    'category': 'Safety',
    'tags': ['safety', 'observation', 'behavior'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String(),
    'fields': [
      {
        'id': 'type',
        'label': 'Type',
        'type': 'dropdown',
        'options': ['Safe act', 'At risk'],
        'order': 1,
        'isRequired': true,
      },
      {'id': 'location', 'label': 'Location', 'type': 'text', 'order': 2},
      {'id': 'details', 'label': 'Details', 'type': 'textarea', 'order': 3},
      {'id': 'photos', 'label': 'Photos', 'type': 'photo', 'order': 4},
    ],
    'metadata': {'template': 'safety-observation'},
  },
  {
    'id': 'ppe-compliance',
    'title': 'PPE Compliance Check',
    'description': 'Verify PPE usage by zone and trade',
    'category': 'Safety',
    'tags': ['safety', 'ppe', 'compliance'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String(),
    'fields': [
      {'id': 'zone', 'label': 'Zone', 'type': 'text', 'order': 1},
      {'id': 'trade', 'label': 'Trade', 'type': 'text', 'order': 2},
      {
        'id': 'ppe',
        'label': 'PPE present',
        'type': 'checkbox',
        'options': ['Hard hat', 'Gloves', 'Eye protection', 'Hi-Vis'],
        'order': 3,
      },
      {'id': 'notes', 'label': 'Notes', 'type': 'textarea', 'order': 4},
    ],
    'metadata': {'template': 'ppe-compliance'},
  },
  {
    'id': 'inventory-replenishment',
    'title': 'Inventory Replenishment',
    'description': 'Scan SKUs, record counts, request replenishment',
    'category': 'Operations',
    'tags': ['operations', 'inventory', 'logistics'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {'id': 'location', 'label': 'Location', 'type': 'text', 'order': 1},
      {
        'id': 'items',
        'label': 'Items',
        'type': 'table',
        'order': 2,
        'children': [
          {'id': 'sku', 'label': 'SKU', 'type': 'barcode', 'order': 1},
          {'id': 'onHand', 'label': 'On-hand', 'type': 'number', 'order': 2},
          {'id': 'par', 'label': 'Par', 'type': 'number', 'order': 3},
        ],
      },
      {'id': 'notes', 'label': 'Notes', 'type': 'textarea', 'order': 3},
    ],
    'metadata': {'template': 'inventory-replenishment'},
  },
  {
    'id': 'shift-handover',
    'title': 'Shift Handover',
    'description':
        'Operations shift handover with issues, priorities, and approvals',
    'category': 'Operations',
    'tags': ['operations', 'handover', 'shift'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String(),
    'fields': [
      {
        'id': 'outgoing',
        'label': 'Outgoing supervisor',
        'type': 'text',
        'order': 1,
      },
      {
        'id': 'incoming',
        'label': 'Incoming supervisor',
        'type': 'text',
        'order': 2,
      },
      {'id': 'issues', 'label': 'Issues', 'type': 'textarea', 'order': 3},
      {
        'id': 'priority',
        'label': 'Priority tasks',
        'type': 'textarea',
        'order': 4,
      },
      {'id': 'signature', 'label': 'Sign-off', 'type': 'signature', 'order': 5},
    ],
    'metadata': {'template': 'shift-handover'},
  },
  {
    'id': 'performance-review',
    'title': 'Performance Review',
    'description': 'HR performance review with ratings and comments',
    'category': 'HR',
    'tags': ['hr', 'review', 'performance'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 5))
        .toIso8601String(),
    'fields': [
      {
        'id': 'employee',
        'label': 'Employee',
        'type': 'text',
        'order': 1,
        'isRequired': true,
      },
      {'id': 'role', 'label': 'Role', 'type': 'text', 'order': 2},
      {
        'id': 'rating',
        'label': 'Overall rating (1-5)',
        'type': 'number',
        'order': 3,
      },
      {'id': 'strengths', 'label': 'Strengths', 'type': 'textarea', 'order': 4},
      {
        'id': 'improvements',
        'label': 'Improvements',
        'type': 'textarea',
        'order': 5,
      },
      {
        'id': 'signature',
        'label': 'Manager signature',
        'type': 'signature',
        'order': 6,
      },
    ],
    'metadata': {'template': 'performance-review'},
  },
  {
    'id': 'fuel-log',
    'title': 'Fuel Log',
    'description':
        'Track fuel fills for fleet vehicles with odometer and receipts',
    'category': 'Fleet',
    'tags': ['fleet', 'fuel', 'log'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {'id': 'vehicleId', 'label': 'Vehicle ID', 'type': 'text', 'order': 1},
      {'id': 'odometer', 'label': 'Odometer', 'type': 'number', 'order': 2},
      {
        'id': 'gallons',
        'label': 'Gallons/Liters',
        'type': 'number',
        'order': 3,
      },
      {'id': 'cost', 'label': 'Cost', 'type': 'number', 'order': 4},
      {'id': 'receipt', 'label': 'Receipt photo', 'type': 'photo', 'order': 5},
    ],
    'metadata': {'template': 'fuel-log'},
  },
  {
    'id': 'mystery-shopper',
    'title': 'Mystery Shopper',
    'description': 'Retail mystery shop checklist with scores and notes',
    'category': 'Retail',
    'tags': ['retail', 'mystery', 'shopper'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String(),
    'fields': [
      {'id': 'store', 'label': 'Store', 'type': 'text', 'order': 1},
      {
        'id': 'greeting',
        'label': 'Greeting',
        'type': 'radio',
        'options': ['Yes', 'No'],
        'order': 2,
      },
      {
        'id': 'cleanliness',
        'label': 'Cleanliness score (1-5)',
        'type': 'number',
        'order': 3,
      },
      {
        'id': 'service',
        'label': 'Service score (1-5)',
        'type': 'number',
        'order': 4,
      },
      {'id': 'notes', 'label': 'Notes', 'type': 'textarea', 'order': 5},
    ],
    'metadata': {'template': 'mystery-shopper'},
  },
  {
    'id': 'patient-intake',
    'title': 'Patient Intake',
    'description':
        'Healthcare intake form for patient info, symptoms, and consent',
    'category': 'Healthcare',
    'tags': ['healthcare', 'intake', 'patient'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String(),
    'fields': [
      {'id': 'name', 'label': 'Patient name', 'type': 'text', 'order': 1},
      {'id': 'dob', 'label': 'Date of birth', 'type': 'date', 'order': 2},
      {'id': 'symptoms', 'label': 'Symptoms', 'type': 'textarea', 'order': 3},
      {
        'id': 'consent',
        'label': 'Consent signed',
        'type': 'toggle',
        'order': 4,
      },
      {
        'id': 'signature',
        'label': 'Patient signature',
        'type': 'signature',
        'order': 5,
      },
    ],
    'metadata': {'template': 'patient-intake'},
  },
  {
    'id': 'risk-assessment',
    'title': 'Insurance Risk Assessment',
    'description': 'On-site insurance risk assessment with hazards and scoring',
    'category': 'Insurance',
    'tags': ['insurance', 'risk', 'assessment'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {'id': 'site', 'label': 'Site', 'type': 'text', 'order': 1},
      {'id': 'hazards', 'label': 'Hazards', 'type': 'textarea', 'order': 2},
      {
        'id': 'score',
        'label': 'Risk score (1-5)',
        'type': 'number',
        'order': 3,
      },
      {'id': 'photos', 'label': 'Photos', 'type': 'photo', 'order': 4},
    ],
    'metadata': {'template': 'risk-assessment'},
  },
  {
    'id': 'cleaning-checklist',
    'title': 'Cleaning Checklist',
    'description':
        'Facilities cleaning checklist with rooms and completion status',
    'category': 'Facilities',
    'tags': ['facilities', 'cleaning', 'janitorial'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String(),
    'fields': [
      {'id': 'area', 'label': 'Area', 'type': 'text', 'order': 1},
      {
        'id': 'tasks',
        'label': 'Tasks',
        'type': 'table',
        'order': 2,
        'children': [
          {'id': 'task', 'label': 'Task', 'type': 'text', 'order': 1},
          {
            'id': 'status',
            'label': 'Status',
            'type': 'dropdown',
            'options': ['Pending', 'Done'],
            'order': 2,
          },
        ],
      },
      {
        'id': 'signature',
        'label': 'Supervisor signature',
        'type': 'signature',
        'order': 3,
      },
    ],
    'metadata': {'template': 'cleaning-checklist'},
  },
  {
    'id': 'toolbox-talk',
    'title': 'Toolbox Talk',
    'description': 'Construction safety briefing with attendees and topics',
    'category': 'Construction',
    'tags': ['construction', 'safety', 'talk'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {'id': 'topic', 'label': 'Topic', 'type': 'text', 'order': 1},
      {
        'id': 'attendees',
        'label': 'Attendees',
        'type': 'repeater',
        'order': 2,
        'children': [
          {'id': 'name', 'label': 'Name', 'type': 'text', 'order': 1},
          {'id': 'company', 'label': 'Company', 'type': 'text', 'order': 2},
        ],
      },
      {'id': 'notes', 'label': 'Notes', 'type': 'textarea', 'order': 3},
      {
        'id': 'signature',
        'label': 'Supervisor signature',
        'type': 'signature',
        'order': 4,
      },
    ],
    'metadata': {'template': 'toolbox-talk'},
  },
  {
    'id': 'ncr',
    'title': 'Nonconformance Report',
    'description': 'Quality NCR with defect type, location, and disposition',
    'category': 'Quality',
    'tags': ['quality', 'ncr', 'defect'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String(),
    'fields': [
      {'id': 'defect', 'label': 'Defect', 'type': 'text', 'order': 1},
      {'id': 'location', 'label': 'Location', 'type': 'text', 'order': 2},
      {
        'id': 'disposition',
        'label': 'Disposition',
        'type': 'dropdown',
        'options': ['Rework', 'Scrap', 'Use-as-is'],
        'order': 3,
      },
      {'id': 'photos', 'label': 'Photos', 'type': 'photo', 'order': 4},
      {
        'id': 'signature',
        'label': 'Quality signature',
        'type': 'signature',
        'order': 5,
      },
    ],
    'metadata': {'template': 'ncr'},
  },
  {
    'id': 'waste-manifest',
    'title': 'Waste Manifest',
    'description': 'Track waste type, quantity, container, and pickup details',
    'category': 'Environmental',
    'tags': ['environmental', 'waste', 'manifest'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String(),
    'fields': [
      {'id': 'wasteType', 'label': 'Waste type', 'type': 'text', 'order': 1},
      {'id': 'quantity', 'label': 'Quantity', 'type': 'number', 'order': 2},
      {
        'id': 'container',
        'label': 'Container',
        'type': 'dropdown',
        'options': ['Drum', 'Tote', 'Box'],
        'order': 3,
      },
      {'id': 'pickup', 'label': 'Pickup date', 'type': 'date', 'order': 4},
      {
        'id': 'signature',
        'label': 'Handler signature',
        'type': 'signature',
        'order': 5,
      },
    ],
    'metadata': {'template': 'waste-manifest'},
  },
  {
    'id': 'nps-survey',
    'title': 'NPS Survey',
    'description': 'Customer NPS survey with score and feedback',
    'category': 'Customer',
    'tags': ['customer', 'nps', 'feedback'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {'id': 'name', 'label': 'Name', 'type': 'text', 'order': 1},
      {'id': 'score', 'label': 'Score (0-10)', 'type': 'number', 'order': 2},
      {'id': 'feedback', 'label': 'Feedback', 'type': 'textarea', 'order': 3},
    ],
    'metadata': {'template': 'nps-survey'},
  },
  {
    'id': 'change-request',
    'title': 'IT Change Request',
    'description': 'IT change request with risk, rollout plan, and approvals',
    'category': 'IT',
    'tags': ['it', 'change', 'request'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String(),
    'fields': [
      {'id': 'title', 'label': 'Change title', 'type': 'text', 'order': 1},
      {
        'id': 'risk',
        'label': 'Risk level',
        'type': 'dropdown',
        'options': ['Low', 'Medium', 'High'],
        'order': 2,
      },
      {'id': 'plan', 'label': 'Rollout plan', 'type': 'textarea', 'order': 3},
      {
        'id': 'backout',
        'label': 'Backout plan',
        'type': 'textarea',
        'order': 4,
      },
      {
        'id': 'signature',
        'label': 'Approver signature',
        'type': 'signature',
        'order': 5,
      },
    ],
    'metadata': {'template': 'change-request'},
  },
  {
    'id': 'fai',
    'title': 'First Article Inspection',
    'description':
        'Manufacturing FAI with dimensions, tolerances, and dispositions',
    'category': 'Quality',
    'tags': ['quality', 'manufacturing', 'fai'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {
        'id': 'partNumber',
        'label': 'Part number',
        'type': 'text',
        'order': 1,
        'isRequired': true,
      },
      {'id': 'revision', 'label': 'Revision', 'type': 'text', 'order': 2},
      {
        'id': 'characteristics',
        'label': 'Characteristics',
        'type': 'table',
        'order': 3,
        'children': [
          {'id': 'char', 'label': 'Characteristic', 'type': 'text', 'order': 1},
          {'id': 'nominal', 'label': 'Nominal', 'type': 'text', 'order': 2},
          {'id': 'actual', 'label': 'Actual', 'type': 'text', 'order': 3},
          {
            'id': 'result',
            'label': 'Result',
            'type': 'dropdown',
            'options': ['Pass', 'Fail'],
            'order': 4,
          },
        ],
      },
      {'id': 'photos', 'label': 'Photos', 'type': 'photo', 'order': 4},
      {
        'id': 'signature',
        'label': 'Inspector signature',
        'type': 'signature',
        'order': 5,
      },
    ],
    'metadata': {'template': 'fai'},
  },
  {
    'id': 'pod',
    'title': 'Proof of Delivery',
    'description': 'Logistics POD with recipient, condition, and photos',
    'category': 'Operations',
    'tags': ['logistics', 'delivery', 'pod'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {
        'id': 'shipment',
        'label': 'Shipment ID',
        'type': 'text',
        'order': 1,
        'isRequired': true,
      },
      {
        'id': 'recipient',
        'label': 'Recipient name',
        'type': 'text',
        'order': 2,
      },
      {
        'id': 'condition',
        'label': 'Package condition',
        'type': 'dropdown',
        'options': ['Intact', 'Damaged'],
        'order': 3,
      },
      {'id': 'photos', 'label': 'Delivery photos', 'type': 'photo', 'order': 4},
      {
        'id': 'signature',
        'label': 'Recipient signature',
        'type': 'signature',
        'order': 5,
      },
    ],
    'metadata': {'template': 'pod'},
  },
  {
    'id': 'housekeeping',
    'title': 'Housekeeping Checklist',
    'description':
        'Hospitality housekeeping checks with room readiness and defects',
    'category': 'Operations',
    'tags': ['hospitality', 'housekeeping', 'room'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String(),
    'fields': [
      {'id': 'room', 'label': 'Room #', 'type': 'text', 'order': 1},
      {
        'id': 'status',
        'label': 'Status',
        'type': 'dropdown',
        'options': ['Clean', 'Needs attention'],
        'order': 2,
      },
      {
        'id': 'amenities',
        'label': 'Amenities stocked',
        'type': 'checkbox',
        'options': ['Towels', 'Toiletries', 'Water', 'Coffee'],
        'order': 3,
      },
      {'id': 'issues', 'label': 'Issues', 'type': 'textarea', 'order': 4},
      {'id': 'photos', 'label': 'Photos', 'type': 'photo', 'order': 5},
    ],
    'metadata': {'template': 'housekeeping'},
  },
  {
    'id': 'guard-tour',
    'title': 'Security Guard Tour',
    'description': 'Guard tour checkpoints with scan, notes, and incidents',
    'category': 'Security',
    'tags': ['security', 'tour', 'guard'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'fields': [
      {'id': 'route', 'label': 'Route', 'type': 'text', 'order': 1},
      {
        'id': 'checkpoints',
        'label': 'Checkpoints',
        'type': 'repeater',
        'order': 2,
        'children': [
          {
            'id': 'tag',
            'label': 'Checkpoint tag',
            'type': 'barcode',
            'order': 1,
          },
          {
            'id': 'status',
            'label': 'Status',
            'type': 'dropdown',
            'options': ['Clear', 'Issue'],
            'order': 2,
          },
          {'id': 'notes', 'label': 'Notes', 'type': 'textarea', 'order': 3},
        ],
      },
      {'id': 'photos', 'label': 'Photos', 'type': 'photo', 'order': 3},
      {
        'id': 'signature',
        'label': 'Guard signature',
        'type': 'signature',
        'order': 4,
      },
    ],
    'metadata': {'template': 'guard-tour'},
  },
  {
    'id': 'drill-report',
    'title': 'Safety Drill Report',
    'description':
        'Education/safety drill with participants, timing, and issues',
    'category': 'Safety',
    'tags': ['safety', 'drill', 'education'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 4))
        .toIso8601String(),
    'fields': [
      {
        'id': 'type',
        'label': 'Drill type',
        'type': 'dropdown',
        'options': ['Fire', 'Earthquake', 'Lockdown'],
        'order': 1,
      },
      {
        'id': 'duration',
        'label': 'Duration (min)',
        'type': 'number',
        'order': 2,
      },
      {
        'id': 'participants',
        'label': 'Participants',
        'type': 'number',
        'order': 3,
      },
      {
        'id': 'issues',
        'label': 'Issues observed',
        'type': 'textarea',
        'order': 4,
      },
    ],
    'metadata': {'template': 'drill-report'},
  },
  {
    'id': 'batch-record',
    'title': 'Pharma Batch Record',
    'description': 'Pharmaceutical batch record with lot, steps, and sign-offs',
    'category': 'Quality',
    'tags': ['pharma', 'batch', 'quality'],
    'isPublished': true,
    'version': '1.0.0',
    'createdBy': 'demo',
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String(),
    'fields': [
      {
        'id': 'lot',
        'label': 'Lot #',
        'type': 'text',
        'order': 1,
        'isRequired': true,
      },
      {'id': 'product', 'label': 'Product', 'type': 'text', 'order': 2},
      {
        'id': 'steps',
        'label': 'Steps',
        'type': 'repeater',
        'order': 3,
        'children': [
          {'id': 'step', 'label': 'Step', 'type': 'text', 'order': 1},
          {'id': 'time', 'label': 'Time', 'type': 'time', 'order': 2},
          {'id': 'operator', 'label': 'Operator', 'type': 'text', 'order': 3},
        ],
      },
      {
        'id': 'signature',
        'label': 'QA signature',
        'type': 'signature',
        'order': 4,
      },
    ],
    'metadata': {'template': 'batch-record'},
  },
];

final _submissions = <Map<String, dynamic>>[
  {
    'id': 'sub-1001',
    'formId': 'jobsite-safety',
    'formTitle': 'Job Site Safety Walk',
    'submittedBy': 'sarah.c',
    'submittedByName': 'Sarah Chen',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String(),
    'status': 'underReview',
    'data': {
      'siteName': 'South Plant 7',
      'inspector': 'Sarah Chen',
      'ppe': ['Hard hat', 'Vest', 'Gloves'],
      'hazards': 'Loose cabling near east stairwell, blocked exit near bay 4',
    },
    'attachments': [
      {
        'id': 'att-1',
        'type': 'photo',
        'url': 'https://placehold.co/400x300?text=Exit+Blocked',
        'filename': 'exit-blocked.jpg',
        'capturedAt': DateTime.now()
            .subtract(const Duration(hours: 3, minutes: 15))
            .toIso8601String(),
      },
    ],
    'location': {
      'latitude': 37.7765,
      'longitude': -122.4192,
      'timestamp': DateTime.now()
          .subtract(const Duration(hours: 3))
          .toIso8601String(),
      'accuracy': 8.5,
      'address': 'Bay 4, South Plant 7',
    },
    'metadata': {'priority': 'high'},
  },
  {
    'id': 'sub-1002',
    'formId': 'equipment-checkout',
    'formTitle': 'Equipment Checkout',
    'submittedBy': 'mike.l',
    'submittedByName': 'Mike Lopez',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 18))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'assetTag': 'FORK-2231',
      'condition': 'Good',
      'notes': 'Tires look new. Fuel at 80%.',
    },
    'attachments': [
      {
        'id': 'att-2',
        'type': 'photo',
        'url': 'https://placehold.co/400x300?text=Forklift',
        'filename': 'forklift.jpg',
        'capturedAt': DateTime.now()
            .subtract(const Duration(hours: 18, minutes: 20))
            .toIso8601String(),
      },
    ],
    'metadata': {'handoff': 'Dock A'},
  },
  {
    'id': 'sub-1003',
    'formId': 'visitor-log',
    'formTitle': 'Visitor Log',
    'submittedBy': 'reception',
    'submittedByName': 'Reception Desk',
    'submittedAt': DateTime.now()
        .subtract(const Duration(days: 1, hours: 2))
        .toIso8601String(),
    'status': 'approved',
    'data': {
      'fullName': 'Alex Morgan',
      'company': 'Bright Manufacturing',
      'host': 'Taylor Brooks',
      'purpose': 'Audit',
      'badge': true,
    },
  },
  {
    'id': 'sub-2001',
    'formId': 'bar-inventory',
    'formTitle': 'Bar Inventory Count',
    'submittedBy': 'inventory.bot',
    'submittedByName': 'Night Audit',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 8))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'location': 'Main bar',
      'bottles': [
        {
          'sku': '88004000099',
          'name': 'Hendricks Gin 750ml',
          'par': 6,
          'onHand': 5,
          'variance': -1,
        },
        {
          'sku': '02820000025',
          'name': 'Casamigos Blanco 1L',
          'par': 8,
          'onHand': 9,
          'variance': 1,
        },
      ],
      'notes': 'Main bar done; patio pending.',
    },
  },
  {
    'id': 'sub-2002',
    'formId': 'incident-report',
    'formTitle': 'Security Incident Report',
    'submittedBy': 'security1',
    'submittedByName': 'Jamie Patel',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 5))
        .toIso8601String(),
    'status': 'underReview',
    'data': {
      'incidentType': 'Suspicious activity',
      'severity': 'Medium',
      'description': 'Unattended backpack in lobby. Cleared; owner found.',
    },
    'attachments': [
      {
        'id': 'att-4',
        'type': 'photo',
        'url': 'https://placehold.co/400x300?text=Lobby',
        'filename': 'lobby.jpg',
        'capturedAt': DateTime.now()
            .subtract(const Duration(hours: 5, minutes: 10))
            .toIso8601String(),
      },
    ],
    'location': {
      'latitude': 37.7749,
      'longitude': -122.4194,
      'timestamp': DateTime.now()
          .subtract(const Duration(hours: 5))
          .toIso8601String(),
      'accuracy': 5.2,
    },
  },
  {
    'id': 'sub-3001',
    'formId': 'food-safety-log',
    'formTitle': 'Food Safety & Temp Log',
    'submittedBy': 'kitchen.lead',
    'submittedByName': 'Dana Ruiz',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 4))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'station': 'Line',
      'readings': [
        {'item': 'Chicken', 'temp': 168, 'corrective': ''},
        {
          'item': 'Sauce',
          'temp': 142,
          'corrective': 'Returned to heat; rechecked at 165',
        },
      ],
      'sanitizer': 200,
    },
  },
  {
    'id': 'sub-3002',
    'formId': 'hr-onboarding',
    'formTitle': 'HR Onboarding Checklist',
    'submittedBy': 'hr.admin',
    'submittedByName': 'HR Admin',
    'submittedAt': DateTime.now()
        .subtract(const Duration(days: 1, hours: 2))
        .toIso8601String(),
    'status': 'approved',
    'data': {
      'employee': 'Chris Jones',
      'role': 'Field Technician',
      'equipment': ['Laptop', 'Badge', 'PPE'],
      'training': [
        {'course': 'Safety 101', 'status': 'Completed'},
        {'course': 'Harassment Prevention', 'status': 'Completed'},
      ],
    },
  },
  {
    'id': 'sub-4001',
    'formId': 'vehicle-inspection',
    'formTitle': 'Vehicle / DVIR Inspection',
    'submittedBy': 'driver.101',
    'submittedByName': 'Alex Rivera',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 6))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'vehicleId': 'TRK-4421',
      'odometer': 120345,
      'checks': ['Lights', 'Brakes', 'Tires'],
      'defects': [
        {'component': 'Right rear tire', 'severity': 'Med'},
      ],
    },
    'attachments': [
      {
        'id': 'att-5',
        'type': 'photo',
        'url': 'https://placehold.co/400x300?text=Tire',
        'filename': 'tire.jpg',
        'capturedAt': DateTime.now()
            .subtract(const Duration(hours: 6, minutes: 10))
            .toIso8601String(),
      },
    ],
  },
  {
    'id': 'sub-4002',
    'formId': 'osha-incident',
    'formTitle': 'OSHA Recordable Incident',
    'submittedBy': 'safety.lead',
    'submittedByName': 'Morgan Lee',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 20))
        .toIso8601String(),
    'status': 'underReview',
    'data': {
      'incidentDate': DateTime.now()
          .subtract(const Duration(days: 1, hours: 2))
          .toIso8601String(),
      'classification': 'Recordable',
      'injuryType': ['Laceration'],
      'treatment': 'Stitches administered on-site',
      'rootCause': 'Guard removed for maintenance',
    },
  },
  {
    'id': 'sub-4003',
    'formId': 'retail-audit',
    'formTitle': 'Retail Store Audit',
    'submittedBy': 'merch.team',
    'submittedByName': 'Jamie Cruz',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 12))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'store': 'Store 118',
      'pricing': 'Good',
      'displays': ['Endcaps set', 'Promo signage'],
      'issues': 'Planogram off in aisle 6',
    },
  },
  {
    'id': 'sub-4004',
    'formId': 'insurance-claim',
    'formTitle': 'Insurance Claim Intake',
    'submittedBy': 'adjuster.1',
    'submittedByName': 'Taylor Morgan',
    'submittedAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'claimant': 'Pat Smith',
      'policy': 'PL-555-222',
      'lossDate': DateTime.now()
          .subtract(const Duration(days: 2))
          .toIso8601String(),
      'lossType': 'Auto',
      'description': 'Rear-end collision, minor damage',
    },
  },
  {
    'id': 'sub-4005',
    'formId': 'facility-work-order',
    'formTitle': 'Facility Work Order',
    'submittedBy': 'maint.bot',
    'submittedByName': 'Maintenance Bot',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'location': 'Warehouse Bay 3',
      'priority': 'High',
      'issue': 'Dock door sensor malfunctioning',
      'completed': false,
    },
  },
  {
    'id': 'sub-4006',
    'formId': 'patient-rounding',
    'formTitle': 'Patient Rounding Checklist',
    'submittedBy': 'nurse.22',
    'submittedByName': 'Nurse Jordan',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 4))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'patient': 'A. Johnson',
      'room': '302B',
      'vitals': true,
      'comfort': ['Pain', 'Position', 'Personal items'],
      'notes': 'Pain managed; repositioned',
    },
  },
  {
    'id': 'sub-5001',
    'formId': 'daily-report',
    'formTitle': 'Construction Daily Report',
    'submittedBy': 'sup.8',
    'submittedByName': 'Foreman Blake',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 5))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'weather': 'Cloudy',
      'crew': 24,
      'equipment': ['Crane', 'Loader'],
      'delays': 'Concrete delivery 45m late',
    },
  },
  {
    'id': 'sub-5002',
    'formId': 'quality-inspection',
    'formTitle': 'Quality Inspection',
    'submittedBy': 'qa.lead',
    'submittedByName': 'Leah Kim',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 7))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'area': 'Level 5 Corridor',
      'items': [
        {'item': 'Paint', 'status': 'Pass'},
        {'item': 'Flooring', 'status': 'Fail'},
      ],
    },
  },
  {
    'id': 'sub-5003',
    'formId': 'environmental-audit',
    'formTitle': 'Environmental Audit',
    'submittedBy': 'env.auditor',
    'submittedByName': 'Chris Green',
    'submittedAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'spillKits': true,
      'waste': 'Needs attention',
      'observations': 'Secondary containment missing at drum storage',
    },
  },
  {
    'id': 'sub-5004',
    'formId': 'customer-feedback',
    'formTitle': 'Customer Feedback',
    'submittedBy': 'csr.1',
    'submittedByName': 'CSR Bot',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 2))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'name': 'Jordan P',
      'rating': 4,
      'comments': 'Good service, minor delay.',
      'followup': false,
    },
  },
  {
    'id': 'sub-5005',
    'formId': 'it-ticket',
    'formTitle': 'IT Ticket',
    'submittedBy': 'it.queue',
    'submittedByName': 'IT Queue',
    'submittedAt': DateTime.now()
        .subtract(const Duration(hours: 9))
        .toIso8601String(),
    'status': 'submitted',
    'data': {
      'user': 'Dana',
      'device': 'Laptop-332',
      'category': 'Network',
      'severity': 'High',
      'description': 'Cannot connect to VPN',
    },
  },
];

final _notifications = <Map<String, dynamic>>[
  {
    'id': 'notif-1',
    'title': 'Action required: Blocked exit',
    'body':
        'Resolve the blocked exit near Bay 4 and attach a photo once clear.',
    'type': 'task',
    'targetRole': 'Supervisor',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 1, minutes: 15))
        .toIso8601String(),
    'data': {'submissionId': 'sub-1001'},
  },
  {
    'id': 'notif-2',
    'title': 'New visitor awaiting host',
    'body': 'Alex Morgan (Bright Manufacturing) is waiting in the lobby.',
    'type': 'alert',
    'targetRole': 'Security',
    'isRead': true,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 5))
        .toIso8601String(),
    'readAt': DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String(),
    'data': {'formId': 'visitor-log'},
  },
  {
    'id': 'notif-3',
    'title': 'Equipment checkout approved',
    'body': 'FORK-2231 checked out to Mike Lopez.',
    'type': 'info',
    'isRead': true,
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1, hours: 4))
        .toIso8601String(),
  },
  {
    'id': 'notif-4',
    'title': 'New incident report',
    'body': 'Security incident awaiting review (Medium severity).',
    'type': 'alert',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 5))
        .toIso8601String(),
    'data': {'formId': 'incident-report'},
  },
  {
    'id': 'notif-5',
    'title': 'Inventory variance detected',
    'body': 'Bar inventory variance found: Hendricks Gin -1 vs par.',
    'type': 'task',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 2, minutes: 30))
        .toIso8601String(),
    'data': {'formId': 'bar-inventory'},
  },
  {
    'id': 'notif-6',
    'title': 'Food safety log ready',
    'body': 'Line station temps recorded; review for compliance.',
    'type': 'info',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 4))
        .toIso8601String(),
    'data': {'formId': 'food-safety-log'},
  },
  {
    'id': 'notif-7',
    'title': 'Onboarding completed',
    'body': 'Chris Jones onboarding marked approved.',
    'type': 'info',
    'isRead': true,
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'data': {'formId': 'hr-onboarding'},
  },
  {
    'id': 'notif-8',
    'title': 'DVIR defect reported',
    'body': 'TRK-4421 has a medium tire issue.',
    'type': 'task',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 6))
        .toIso8601String(),
    'data': {'formId': 'vehicle-inspection'},
  },
  {
    'id': 'notif-9',
    'title': 'Recordable incident logged',
    'body': 'OSHA recordable incident pending review.',
    'type': 'alert',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 20))
        .toIso8601String(),
    'data': {'formId': 'osha-incident'},
  },
  {
    'id': 'notif-10',
    'title': 'Retail audit completed',
    'body': 'Store 118 audit submitted with planogram issues.',
    'type': 'info',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 12))
        .toIso8601String(),
    'data': {'formId': 'retail-audit'},
  },
  {
    'id': 'notif-11',
    'title': 'New claim intake',
    'body': 'Auto loss reported for policy PL-555-222.',
    'type': 'info',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'data': {'formId': 'insurance-claim'},
  },
  {
    'id': 'notif-12',
    'title': 'Facility issue created',
    'body': 'High priority work order for Warehouse Bay 3.',
    'type': 'task',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String(),
    'data': {'formId': 'facility-work-order'},
  },
  {
    'id': 'notif-13',
    'title': 'Daily report submitted',
    'body': 'Construction daily report updated.',
    'type': 'info',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 5))
        .toIso8601String(),
    'data': {'formId': 'daily-report'},
  },
  {
    'id': 'notif-14',
    'title': 'Quality inspection failed item',
    'body': 'Flooring failed in Level 5 corridor.',
    'type': 'alert',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 7))
        .toIso8601String(),
    'data': {'formId': 'quality-inspection'},
  },
  {
    'id': 'notif-15',
    'title': 'Environmental action needed',
    'body': 'Waste storage needs attention.',
    'type': 'task',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'data': {'formId': 'environmental-audit'},
  },
  {
    'id': 'notif-16',
    'title': 'Customer feedback received',
    'body': 'New CSAT response logged.',
    'type': 'info',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 2))
        .toIso8601String(),
    'data': {'formId': 'customer-feedback'},
  },
  {
    'id': 'notif-17',
    'title': 'IT ticket escalated',
    'body': 'VPN connectivity issue reported.',
    'type': 'alert',
    'isRead': false,
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 9))
        .toIso8601String(),
    'data': {'formId': 'it-ticket'},
  },
];

final _employees = <Map<String, dynamic>>[
  {
    'id': 'user-1',
    'firstName': 'Sarah',
    'lastName': 'Chen',
    'email': 'sarah.chen@formpulse.com',
    'role': 'Manager',
  },
  {
    'id': 'user-2',
    'firstName': 'Mike',
    'lastName': 'Lopez',
    'email': 'mike.lopez@formpulse.com',
    'role': 'Technician',
  },
  {
    'id': 'user-3',
    'firstName': 'Taylor',
    'lastName': 'Brooks',
    'email': 'taylor.brooks@formpulse.com',
    'role': 'Supervisor',
  },
];

final _jobSites = <Map<String, dynamic>>[
  {
    'id': 'site-1',
    'name': 'South Plant 7',
    'location': {'lat': 37.7765, 'lng': -122.4192},
  },
  {
    'id': 'site-2',
    'name': 'Distribution Center A',
    'location': {'lat': 37.8101, 'lng': -122.2500},
  },
];

final _equipment = <Map<String, dynamic>>[
  {
    'id': 'FORK-2231',
    'name': 'Forklift Model X',
    'status': 'available',
    'lastInspection': DateTime.now()
        .subtract(const Duration(days: 6))
        .toIso8601String(),
  },
  {
    'id': 'GEN-4410',
    'name': 'Generator 45kW',
    'status': 'checkedOut',
    'lastInspection': DateTime.now()
        .subtract(const Duration(days: 10))
        .toIso8601String(),
  },
];

final _trainingRecords = <Map<String, dynamic>>[
  {
    'id': 'train-1',
    'title': 'Lockout/Tagout',
    'status': 'completed',
    'completedAt': DateTime.now()
        .subtract(const Duration(days: 12))
        .toIso8601String(),
  },
  {
    'id': 'train-2',
    'title': 'Powered Industrial Trucks',
    'status': 'inProgress',
    'completedAt': null,
  },
];

const _jsonHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};

// Configure routes
final _router = Router()
  ..get('/', _rootHandler)
  ..get('/health', _healthHandler)
  ..post('/api/auth/login', _loginHandler)
  ..post('/api/auth/register', _registerHandler)
  ..post('/api/auth/refresh', _refreshTokenHandler)
  ..post('/api/auth/logout', _logoutHandler)
  ..get('/api/users', _getUsersHandler)
  ..get('/api/users/<id>', _getUserHandler)
  ..put('/api/users/<id>', _updateUserHandler)
  ..get('/api/forms', _getFormsHandler)
  ..get('/api/forms/<id>', _getFormHandler)
  ..post('/api/forms', _createFormHandler)
  ..put('/api/forms/<id>', _updateFormHandler)
  ..delete('/api/forms/<id>', _deleteFormHandler)
  ..get('/api/submissions', _getSubmissionsHandler)
  ..get('/api/submissions/<id>', _getSubmissionHandler)
  ..get('/api/submissions/export.csv', _exportCsvHandler)
  ..get('/api/submissions/export.pdf', _exportPdfHandler)
  ..post('/api/submissions', _createSubmissionHandler)
  ..put('/api/submissions/<id>', _updateSubmissionHandler)
  ..get('/api/employees', _getEmployeesHandler)
  ..get('/api/employees/<id>', _getEmployeeHandler)
  ..post('/api/employees', _createEmployeeHandler)
  ..put('/api/employees/<id>', _updateEmployeeHandler)
  ..get('/api/documents', _getDocumentsHandler)
  ..post('/api/documents', _uploadDocumentHandler)
  ..get('/api/notifications', _getNotificationsHandler)
  ..patch('/api/notifications/<id>', _markNotificationReadHandler)
  ..post('/api/notifications/<id>/read', _markNotificationReadHandler)
  ..post('/api/notifications', _sendNotificationHandler)
  ..get('/api/job-sites', _getJobSitesHandler)
  ..get('/api/job-sites/<id>', _getJobSiteHandler)
  ..get('/api/equipment', _getEquipmentHandler)
  ..get('/api/equipment/<id>', _getEquipmentItemHandler)
  ..get('/api/training', _getTrainingHandler)
  ..get('/api/training/<id>', _getTrainingRecordHandler)
  ..post('/api/webhooks/test', _webhookTestHandler);

// Handlers
Response _rootHandler(Request req) {
  return Response.ok(
    'Form Bridge API Server\nVersion: 2.0.0\nPrototype mode: in-memory data\n',
    headers: _jsonHeaders,
  );
}

Response _healthHandler(Request req) {
  return Response.ok(jsonEncode({'status': 'ok'}), headers: _jsonHeaders);
}

// Auth Handlers
Future<Response> _loginHandler(Request req) async {
  final body = await _readJson(req);
  final email = body['email'] as String? ?? 'demo@formpulse.com';
  final user = _employees.firstWhere(
    (u) => u['email'] == email,
    orElse: () => _employees.first,
  );
  return _json({'token': 'demo-token', 'user': user});
}

Future<Response> _registerHandler(Request req) async {
  final body = await _readJson(req);
  final email = body['email'] as String? ?? 'new.user@formpulse.com';
  final id = 'user-${DateTime.now().millisecondsSinceEpoch}';
  final user = {
    'id': id,
    'firstName': body['firstName'] ?? 'New',
    'lastName': body['lastName'] ?? 'User',
    'email': email,
    'role': 'User',
  };
  _employees.add(user);
  return _json({
    'message': 'User registered successfully',
    'user': user,
  }, status: 201);
}

Future<Response> _refreshTokenHandler(Request req) async {
  return _json({'token': 'demo-token-refreshed'});
}

Future<Response> _logoutHandler(Request req) async {
  return _json({'message': 'Logged out successfully'});
}

// User Handlers
Future<Response> _getUsersHandler(Request req) async {
  return _json({'users': _employees});
}

Future<Response> _getUserHandler(Request req) async {
  final id = req.params['id'];
  final user = _employees.where((u) => u['id'] == id).toList();
  if (user.isEmpty) return _jsonError('User not found', status: 404);
  return _json(user.first);
}

Future<Response> _updateUserHandler(Request req) async {
  final id = req.params['id'];
  final body = await _readJson(req);
  for (var i = 0; i < _employees.length; i++) {
    if (_employees[i]['id'] == id) {
      _employees[i] = {..._employees[i], ...body};
      return _json({'message': 'User updated', 'user': _employees[i]});
    }
  }
  return _jsonError('User not found', status: 404);
}

// Form Handlers
Future<Response> _getFormsHandler(Request req) async {
  return _json({'forms': _forms});
}

Future<Response> _getFormHandler(Request req) async {
  final id = req.params['id'];
  final form = _forms.where((f) => f['id'] == id).toList();
  if (form.isEmpty) return _jsonError('Form not found', status: 404);
  return _json(form.first);
}

Future<Response> _createFormHandler(Request req) async {
  final body = await _readJson(req);
  final id =
      body['id'] as String? ?? 'form-${DateTime.now().millisecondsSinceEpoch}';
  final now = DateTime.now().toIso8601String();
  final form = {
    ...body,
    'id': id,
    'createdAt': body['createdAt'] ?? now,
    'isPublished': body['isPublished'] ?? true,
    'fields': body['fields'] ?? <Map<String, dynamic>>[],
  };
  _forms.insert(0, form);
  return _json(form, status: 201);
}

Future<Response> _updateFormHandler(Request req) async {
  final id = req.params['id'];
  final body = await _readJson(req);
  for (var i = 0; i < _forms.length; i++) {
    if (_forms[i]['id'] == id) {
      _forms[i] = {
        ..._forms[i],
        ...body,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      return _json(_forms[i]);
    }
  }
  return _jsonError('Form not found', status: 404);
}

Future<Response> _deleteFormHandler(Request req) async {
  final id = req.params['id'];
  _forms.removeWhere((f) => f['id'] == id);
  return _json({'message': 'Form deleted'});
}

// Submission Handlers
Future<Response> _getSubmissionsHandler(Request req) async {
  final q = req.url.queryParameters['q']?.toLowerCase();
  var results = _submissions;
  if (q != null && q.isNotEmpty) {
    results = _submissions.where((s) {
      final title = (s['formTitle'] as String?)?.toLowerCase() ?? '';
      final submittedBy =
          (s['submittedByName'] as String?)?.toLowerCase() ??
          (s['submittedBy'] as String?)?.toLowerCase() ??
          '';
      return title.contains(q) || submittedBy.contains(q);
    }).toList();
  }
  return _json({'submissions': results});
}

Future<Response> _getSubmissionHandler(Request req) async {
  final id = req.params['id'];
  final submission = _submissions.where((s) => s['id'] == id).toList();
  if (submission.isEmpty) {
    return _jsonError('Submission not found', status: 404);
  }
  return _json(submission.first);
}

Future<Response> _exportCsvHandler(Request req) async {
  final buffer = StringBuffer();
  buffer.writeln('id,formTitle,submittedBy,status');
  for (final s in _submissions) {
    buffer.writeln(
      '${s['id']},${s['formTitle']},${s['submittedBy']},${s['status']}',
    );
  }
  return Response.ok(
    buffer.toString(),
    headers: {
      ..._jsonHeaders,
      'Content-Type': 'text/csv',
      'Content-Disposition': 'attachment; filename="submissions.csv"',
    },
  );
}

Future<Response> _exportPdfHandler(Request req) async {
  // Minimal PDF generation for demo exports.
  final text =
      'Form Bridge Export - ${DateTime.now().toIso8601String()} (Total: ${_submissions.length})';
  final pdf = _buildSimplePdf(text);
  return Response.ok(
    pdf,
    headers: {
      ..._jsonHeaders,
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'attachment; filename="submissions.pdf"',
    },
  );
}

Future<Response> _createSubmissionHandler(Request req) async {
  final body = await _readJson(req);
  final formId = body['formId'] as String?;
  final submittedBy = body['submittedBy'] as String? ?? 'anonymous';

  if (formId == null) {
    return _jsonError('formId is required');
  }

  final form = _forms.where((f) => f['id'] == formId).toList();
  final formTitle = form.isNotEmpty
      ? form.first['title'] as String
      : 'Form $formId';
  final id =
      body['id'] as String? ?? 'sub-${DateTime.now().millisecondsSinceEpoch}';
  final submission = {
    'id': id,
    'formId': formId,
    'formTitle': formTitle,
    'submittedBy': submittedBy,
    'submittedByName': body['submittedByName'],
    'submittedAt': body['submittedAt'] ?? DateTime.now().toIso8601String(),
    'status': body['status'] ?? 'submitted',
    'data': body['data'] ?? <String, dynamic>{},
    'attachments': body['attachments'],
    'location': body['location'],
    'metadata': body['metadata'],
  };

  _submissions.insert(0, submission);
  return _json(submission, status: 201);
}

Future<Response> _updateSubmissionHandler(Request req) async {
  final id = req.params['id'];
  final body = await _readJson(req);
  for (var i = 0; i < _submissions.length; i++) {
    if (_submissions[i]['id'] == id) {
      _submissions[i] = {..._submissions[i], ...body};
      return _json(_submissions[i]);
    }
  }
  return _jsonError('Submission not found', status: 404);
}

// Employee Handlers
Future<Response> _getEmployeesHandler(Request req) async {
  return _json({'employees': _employees});
}

Future<Response> _getEmployeeHandler(Request req) async {
  final id = req.params['id'];
  final employee = _employees.where((e) => e['id'] == id).toList();
  if (employee.isEmpty) return _jsonError('Employee not found', status: 404);
  return _json(employee.first);
}

Future<Response> _createEmployeeHandler(Request req) async {
  final body = await _readJson(req);
  final id = 'user-${DateTime.now().millisecondsSinceEpoch}';
  final employee = {...body, 'id': id};
  _employees.add(employee);
  return _json(employee, status: 201);
}

Future<Response> _updateEmployeeHandler(Request req) async {
  final id = req.params['id'];
  final body = await _readJson(req);
  for (var i = 0; i < _employees.length; i++) {
    if (_employees[i]['id'] == id) {
      _employees[i] = {..._employees[i], ...body};
      return _json(_employees[i]);
    }
  }
  return _jsonError('Employee not found', status: 404);
}

// Document Handlers
Future<Response> _getDocumentsHandler(Request req) async {
  return _json({'documents': []});
}

Future<Response> _uploadDocumentHandler(Request req) async {
  return _json({
    'message': 'Document uploaded',
    'id': 'doc-${DateTime.now().millisecondsSinceEpoch}',
  });
}

// Notification Handlers
Future<Response> _getNotificationsHandler(Request req) async {
  return _json({'notifications': _notifications});
}

Future<Response> _markNotificationReadHandler(Request req) async {
  final id = req.params['id'];
  for (var i = 0; i < _notifications.length; i++) {
    if (_notifications[i]['id'] == id) {
      _notifications[i] = {
        ..._notifications[i],
        'isRead': true,
        'readAt': DateTime.now().toIso8601String(),
      };
      return _json(_notifications[i]);
    }
  }
  return _jsonError('Notification not found', status: 404);
}

Future<Response> _sendNotificationHandler(Request req) async {
  final body = await _readJson(req);
  final id = 'notif-${DateTime.now().millisecondsSinceEpoch}';
  final notification = {
    'id': id,
    'title': body['title'] ?? 'New notification',
    'body': body['body'] ?? 'No body provided',
    'type': body['type'] ?? 'info',
    'targetRole': body['targetRole'],
    'isRead': false,
    'createdAt': DateTime.now().toIso8601String(),
    'data': body['data'],
  };
  _notifications.insert(0, notification);
  return _json(notification, status: 201);
}

// Job Site Handlers
Future<Response> _getJobSitesHandler(Request req) async {
  return _json({'jobSites': _jobSites});
}

Future<Response> _getJobSiteHandler(Request req) async {
  final id = req.params['id'];
  final jobSite = _jobSites.where((s) => s['id'] == id).toList();
  if (jobSite.isEmpty) return _jsonError('Job site not found', status: 404);
  return _json(jobSite.first);
}

// Equipment Handlers
Future<Response> _getEquipmentHandler(Request req) async {
  return _json({'equipment': _equipment});
}

Future<Response> _getEquipmentItemHandler(Request req) async {
  final id = req.params['id'];
  final item = _equipment.where((e) => e['id'] == id).toList();
  if (item.isEmpty) return _jsonError('Equipment not found', status: 404);
  return _json(item.first);
}

// Training Handlers
Future<Response> _getTrainingHandler(Request req) async {
  return _json({'training': _trainingRecords});
}

Future<Response> _getTrainingRecordHandler(Request req) async {
  final id = req.params['id'];
  final record = _trainingRecords.where((t) => t['id'] == id).toList();
  if (record.isEmpty) {
    return _jsonError('Training record not found', status: 404);
  }
  return _json(record.first);
}

Future<Response> _webhookTestHandler(Request req) async {
  final payload = await _readJson(req);
  return _json({
    'received': payload,
    'message': 'Webhook received (demo)',
    'timestamp': DateTime.now().toIso8601String(),
  });
}

List<int> _buildSimplePdf(String text) {
  // Small valid PDF with one page showing the provided text.
  final objects = <String>[];
  objects.add('1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n');
  objects.add('2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n');
  objects.add(
    '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj\n',
  );
  final content = 'BT /F1 18 Tf 72 720 Td (${_escapePdfText(text)}) Tj ET';
  objects.add(
    '4 0 obj << /Length ${content.length} >> stream\n$content\nendstream endobj\n',
  );
  objects.add(
    '5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj\n',
  );

  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (final obj in objects) {
    offsets.add(buffer.length);
    buffer.write(obj);
  }
  final xrefOffset = buffer.length;
  buffer.writeln('xref');
  buffer.writeln('0 ${objects.length + 1}');
  buffer.writeln('0000000000 65535 f ');
  for (final offset in offsets) {
    final padded = offset.toString().padLeft(10, '0');
    buffer.writeln('$padded 00000 n ');
  }
  buffer.writeln('trailer << /Root 1 0 R /Size ${objects.length + 1} >>');
  buffer.writeln('startxref');
  buffer.writeln(xrefOffset);
  buffer.writeln('%%EOF');
  return utf8.encode(buffer.toString());
}

String _escapePdfText(String input) {
  return input.replaceAll('(', '\\(').replaceAll(')', '\\)');
}

void main(List<String> args) async {
  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsHeaders())
      .addHandler(_router.call);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  print('🚀 Form Bridge API Server listening on port ${server.port}');
  print('📍 http://localhost:${server.port}');
}

// CORS middleware
Middleware _corsHeaders() {
  return (handler) {
    return (request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _jsonHeaders);
      }
      final response = await handler(request);
      return response.change(headers: _jsonHeaders);
    };
  };
}

Future<Map<String, dynamic>> _readJson(Request request) async {
  final content = await request.readAsString();
  if (content.isEmpty) return <String, dynamic>{};
  return jsonDecode(content) as Map<String, dynamic>;
}

Response _json(Map<String, dynamic> body, {int status = 200}) {
  return Response(status, body: jsonEncode(body), headers: _jsonHeaders);
}

Response _jsonError(String message, {int status = 400}) {
  return Response(
    status,
    body: jsonEncode({'error': message}),
    headers: _jsonHeaders,
  );
}
