# Super Admin Functional Parity Checklist (React → Flutter)

Scope: **Super Admin** role only (this is the reference role for parity).  
React source of truth: `_design/Formbridgereact/src/app/App.tsx` + `_design/Formbridgereact/src/app/components/Sidebar.tsx`.

Non‑negotiable: **Keep the header role switcher** (Flutter `TopBar` dropdown) until the final pre‑launch cut.

## Preflight

- [ ] Test the same org + same user permissions in both apps.
- [ ] Test both breakpoints:
  - [ ] Web/desktop (sidebar always visible)
  - [ ] Mobile (drawer/overlay sidebar)

## Automated Smoke Tests

- Run: `cd apps/mobile && flutter test --no-pub test/superadmin_function_smoke_test.dart`
- Covers: menu labels, web navigation + persistent sidebar, mobile drawer navigation, Messages “Inbox” back behavior.

## Global (Every Screen)

- [ ] Sidebar: web view stays visible and does **not** disappear/flicker during navigation.
- [ ] Sidebar: mobile menu opens/closes; close button is reachable; tapping a menu item closes the drawer.
- [ ] Header: logo centered and readable; respects safe area on iOS (Dynamic Island/notch).
- [ ] Theme toggle works and does not reset on navigation.
- [ ] Role switcher works; switching roles updates menu + dashboard.
- [ ] No overflow warnings / red screens.

## Screen Map (Super Admin Side Menu)

| Menu item | React route | React implementation | Flutter implementation |
| --- | --- | --- | --- |
| Dashboard | `/` | `_design/Formbridgereact/src/app/components/SuperAdminDashboard.tsx` | `apps/mobile/lib/features/admin/presentation/pages/super_admin_dashboard_page.dart` |
| Notifications | `/notifications` | `_design/Formbridgereact/src/app/pages/NotificationsPage.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/notifications_page.dart` |
| Messages | `/messages` | `_design/Formbridgereact/src/app/pages/MessagesPage.tsx` | `apps/mobile/lib/features/partners/presentation/pages/messages_page.dart` |
| Company News | `/news` | `_design/Formbridgereact/src/app/pages/NewsPage.tsx` | `apps/mobile/lib/features/ops/presentation/pages/news_posts_page.dart` |
| Organization Chart | `/organization` | `_design/Formbridgereact/src/app/pages/OrganizationPage.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/organization_chart_page.dart` |
| System Overview | `/system` | `_design/Formbridgereact/src/app/pages/SystemOverviewPage.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/system_overview_page.dart` |
| Users | `/users` | `_design/Formbridgereact/src/app/pages/UsersPage.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/user_directory_page.dart` |
| Roles & Permissions | `/roles-permissions` | `_design/Formbridgereact/src/app/components/RolesPermissionsManager.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/roles_permissions_page.dart` |
| Projects | `/projects` | `_design/Formbridgereact/src/app/pages/ProjectsPage.tsx` | `apps/mobile/lib/features/projects/presentation/pages/projects_page.dart` |
| Tasks | `/tasks` | `_design/Formbridgereact/src/app/pages/TasksPage.tsx` | `apps/mobile/lib/features/tasks/presentation/pages/tasks_page.dart` |
| Work Orders | `/work-orders` | `_design/Formbridgereact/src/app/pages/WorkOrdersPage.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/work_orders_page.dart` |
| Forms | `/forms` | `_design/Formbridgereact/src/app/pages/FormsPage.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/forms_page.dart` |
| Documents | `/documents` | `_design/Formbridgereact/src/app/pages/DocumentsPage.tsx` | `apps/mobile/lib/features/documents/presentation/pages/documents_page.dart` |
| Photos & Videos | `/photos` | `_design/Formbridgereact/src/app/pages/PhotosPage.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/photos_page.dart` |
| Before/After Photos | `/before-after` | `_design/Formbridgereact/src/app/components/BeforeAfterPhotosV2.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/before_after_photos_page.dart` |
| Assets | `/assets` | `_design/Formbridgereact/src/app/pages/AssetsPage.tsx` | `apps/mobile/lib/features/assets/presentation/pages/assets_page.dart` |
| Training | `/training` | `_design/Formbridgereact/src/app/pages/TrainingPage.tsx` | `apps/mobile/lib/features/training/presentation/pages/training_hub_page.dart` |
| Incidents | `/incidents` | `_design/Formbridgereact/src/app/pages/IncidentsPage.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/incidents_page.dart` |
| AI Tools | `/ai-tools` | `_design/Formbridgereact/src/app/components/AITools.tsx` | `apps/mobile/lib/features/ops/presentation/pages/ai_tools_page.dart` |
| Approvals | `/approvals` | `_design/Formbridgereact/src/app/components/ApprovalWorkflow.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/approvals_page.dart` |
| Templates | `/templates` | `_design/Formbridgereact/src/app/components/TemplateBuilder.tsx` | `apps/mobile/lib/features/templates/presentation/pages/templates_page.dart` |
| Payments | `/payments` | `_design/Formbridgereact/src/app/components/PaymentRequest.tsx` | `apps/mobile/lib/features/ops/presentation/pages/payment_requests_page.dart` |
| Payroll | `/payroll` | `_design/Formbridgereact/src/app/pages/PayrollPage.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/payroll_page.dart` |
| Reports | `/analytics` | `_design/Formbridgereact/src/app/pages/AnalyticsPage.tsx` | `apps/mobile/lib/features/dashboard/presentation/pages/reports_page.dart` |
| Audit Logs | `/audit` | `_design/Formbridgereact/src/app/pages/AuditLogsPage.tsx` | `apps/mobile/lib/features/navigation/presentation/pages/audit_logs_page.dart` |
| Settings | `/settings` | `_design/Formbridgereact/src/app/pages/SettingsPage.tsx` | `apps/mobile/lib/features/settings/presentation/pages/settings_page.dart` |

## Screen‑by‑Screen Functional Checks

### Dashboard
- [ ] “Start Day” behaves correctly (confirm → state changes; cannot repeat; no crashes).
- [ ] “Add User” navigates to Users page (and back).
- [ ] Notifications panel: tabs/filtering/dismiss works; colors match Notifications page severity mapping.

### Notifications
- [ ] Severity colors match Dashboard + React (critical/urgent/high/medium/low).
- [ ] Filter tabs work and counts match the visible list.
- [ ] Opening a notification (if supported) navigates correctly and back returns to list.

### Messages
- [ ] Inbox list loads; selecting a thread opens the thread.
- [ ] “Return to inbox” (or equivalent back action) returns to inbox reliably.
- [ ] Compose/send flow is not dead (or clearly disabled).

### Company News
- [ ] List renders; opening an item shows details; back returns to list.
- [ ] Create post flow is functional (or clearly disabled with no dead buttons).

### Organization Chart
- [ ] Chart renders without overflow at common breakpoints.
- [ ] Search/filter (if present) works; expanding/collapsing nodes works.

### System Overview
- [ ] System status cards/sections render without overflow.
- [ ] Any drill-down links/buttons navigate and return properly.

### Users
- [ ] Export produces a CSV (web download / mobile share sheet) and includes filtered results.
- [ ] Add User opens modal/dialog; submit validates required fields.
- [ ] New user appears in the list; role selection persists; list refreshes cleanly.

### Roles & Permissions
- [ ] Roles grid renders without overflow/console errors at common widths.
- [ ] Permission matrix expands/collapses categories and toggles permission cells without type errors.
- [ ] Create/Duplicate/Edit/Delete role flows match React behavior (including guardrails on default roles).

### Projects
- [ ] Create project flow exists and new project appears (or clear “not implemented” state, but no dead buttons).
- [ ] Search/filter changes results immediately.
- [ ] Project detail opens and back navigation returns to the list.

### Tasks
- [ ] Create task flow exists; assignment fields behave per role.
- [ ] Task detail opens; “back” returns to list (no stuck state).
- [ ] Status/progress updates persist in UI.

### Work Orders
- [ ] Create Work Order flow exists; role-based visibility matches React (super admin sees all).
- [ ] Filters/search update results; stats cards update consistently.
- [ ] Expand/details view works; edit/status actions do not throw.

### Forms
- [ ] Create form → builder flow exists; saving returns to Forms list.
- [ ] Form submit flow works end-to-end (at least via demo template).
- [ ] Form list search/filter behaves like React.

### Documents
- [ ] Upload/add document flow works (or is clearly disabled with no dead buttons).
- [ ] Search/filter and document open/download work.

### Photos & Videos
- [ ] Capture/upload flows work; gallery renders; filtering works if present.

### Before/After Photos
- [ ] Create comparison entry works; before/after pairing stays aligned on mobile.

### Assets
- [ ] Asset list loads; create/edit flows are not dead; scanning/lookup matches React expectations.

### Training
- [ ] Training hub loads; assign/complete flows behave per role.

### Incidents
- [ ] Report incident flow opens and submits; attachments/location controls behave on mobile.

### AI Tools
- [ ] Entry points work; no hidden/untappable buttons; outputs render without overflow.

### Approvals
- [ ] Approval list loads and filters; approving/rejecting updates status.

### Templates
- [ ] Template list and builder flow load; create/edit actions are functional.

### Payments
- [ ] Payment request create flow works; list updates and export works if present.

### Payroll
- [ ] Payroll view loads; role-based access is enforced; actions are not dead.

### Reports
- [ ] Filters do not crash; export works; results render on mobile without overflow.

### Audit Logs
- [ ] Filters/search render; list scrolls smoothly; no missing permission issues.

### Settings
- [ ] Toggles persist; theme changes reflect immediately; navigation to/from Settings works.
