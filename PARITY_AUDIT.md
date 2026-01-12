# Parity Audit – React (source of truth) vs Flutter/mobile

## Method
- Treated `_design/Formbridgereact/src/app/App.tsx` (plus pages/components it routes to) as the canonical experience.
- Mapped every React route/page and per-role navigation in `Sidebar.tsx` to Flutter screens (`apps/mobile/lib/...`), using role menus in `features/navigation/presentation/widgets/side_menu.dart` and role shells in `features/dashboard/presentation/pages/role_dashboard_page.dart`.
- Checked that key feature blocks called out in React code (filters, builders, dashboards, etc.) exist in the Flutter implementation. Data depth/back-end parity was not validated (Supabase/API fidelity not in scope here).

## High-level findings
- Route coverage is nearly 1:1: every React page has a Flutter counterpart. The only functional gap is the **Role Customization** experience: the screen exists (`apps/mobile/lib/features/navigation/presentation/pages/role_customization_page.dart`) but is not exposed in any menu/route wiring, while React exposes `/role-customization`.
- Role-based navigation matches React across Employee, Supervisor, Manager, Maintenance, Admin, Super Admin, and Tech Support. Flutter also carries extra minimal roles (client/vendor/viewer) that do not exist in the React source.
- Global helpers: React’s `TopBar` role switcher and `AIAssistantChat` are mirrored by Flutter’s top-bar role override and `AiAssistantOverlay` in `DashboardShell`.

## Role access parity
- Employee: Org chart, Tasks, Forms, Documents, Photos, Before/After, Assets, QR, Training, Incidents, AI Tools, Timecards, Settings – **Match**.
- Supervisor: Adds My Team, Approvals, Reports – **Match**.
- Manager: Adds Organization/admin console, Projects, Work Orders, Templates, Payments – **Match**.
- Maintenance: Work Orders, Equipment/Assets, QR, Incidents, Training, AI Tools – **Match**.
- Admin: User Mgmt, Roles & Permissions, Work Orders, Templates, Payments, Payroll, Reports, Audit Logs – **Match**.
- Super Admin: System Overview, Roles & Permissions, Assets, Incidents, Payments, Payroll, Reports, Audit Logs – **Match**.
- Tech Support: Support Tickets, Users, Knowledge Base, System Logs – **Match**.

## Page-by-page mapping
| React route/page (file) | Key intent | Flutter equivalent (file) | Parity | Notes |
| --- | --- | --- | --- | --- |
| `/` User/Maintenance/SuperAdmin dashboards (`pages/UserDashboard.tsx`, `MaintenanceDashboard.tsx`, `SuperAdminDashboard.tsx`) | Role-specific KPIs, tasks, quick actions | `features/dashboard/presentation/pages/role_dashboard_page.dart` + role-specific dashboard bodies | Match | Same role shells; dashboards wired per role with stats, quick actions, notifications. |
| Notifications (`/notifications`, `pages/NotificationsPage.tsx`) | Alerts feed & actions | `features/navigation/presentation/pages/notifications_page.dart` | Match | Present in all role menus. |
| Messages (`/messages`, `pages/MessagesPage.tsx`) | Threaded messaging | `features/partners/presentation/pages/messages_page.dart` | Match | Also has thread detail page. |
| Company News (`/news`, `pages/NewsPage.tsx`) | News cards/feed | `features/ops/presentation/pages/news_posts_page.dart` | Match | Wired in menus. |
| Organization Chart / Organization (`/organization`, `pages/OrganizationPage.tsx`) | Org chart + admin org management | `features/navigation/presentation/pages/organization_chart_page.dart`; admin/manager routes to `features/admin/presentation/pages/admin_dashboard_page.dart` (org section) | Partial | Chart view present; admin console embeds org section but dedicated multi-tab org utilities from React page should be validated when wired. |
| Team (`/team`, `pages/TeamPage.tsx`) | Team roster/summary | `features/teams/presentation/pages/teams_page.dart` | Match | Supervisor path. |
| Tasks list/detail (`/tasks`, `pages/TasksPage.tsx`; `/tasks/:id`, `TaskDetailPage.tsx`) | Search/filter, list/board/calendar views, milestones, notifications, create/edit | `features/tasks/presentation/pages/tasks_page.dart`, `task_detail_page.dart`, `task_editor_page.dart` | Match | Flutter includes filters, list/board/calendar, milestone banners, export, realtime Supabase subscription. |
| Work Orders (`/work-orders`, `pages/WorkOrdersPage.tsx`) | Work order board/list, assignments | `features/navigation/presentation/pages/work_orders_page.dart` | Match | Role-aware views, creation modals exist; confirm advanced filters if needed. |
| Forms (`/forms`, `pages/FormsPage.tsx`) | Form library & submissions | `features/navigation/presentation/pages/forms_page.dart` | Match | Includes submission list, status chips. |
| Form Builder (`/forms/builder`, `FormBuilderPage.tsx`) | Drag/drop field palette with rich field set | `features/dashboard/presentation/pages/create_form_page.dart` | Match | Palette spans basic/media/advanced/layout fields; preview/edit parity. |
| Form Submit (`/forms/:id/submit`, `FormSubmissionPage.tsx`) | Fill & submit form | `features/dashboard/presentation/pages/form_fill_page.dart` | Match | Includes media capture, validation, offline queue. |
| Documents (`/documents`, `pages/DocumentsPage.tsx`) | Document manager, viewer/editor | `features/documents/presentation/pages/documents_page.dart` + editor/detail pages | Match | CRUD/editor pages implemented. |
| Assets/My Assets (`/assets`, `pages/AssetsPage.tsx`) | Asset list/detail, inspections | `features/assets/presentation/pages/assets_page.dart` + detail/editors | Match | Supports inspections, incidents, QR lookup. |
| Training (`/training`, `pages/TrainingPage.tsx`) | Training catalog/progress | `features/training/presentation/pages/training_hub_page.dart` | Match | Includes employee detail/editor flows. |
| Incidents (`/incidents`, `pages/IncidentsPage.tsx`) | Incident reporting & status | `features/navigation/presentation/pages/incidents_page.dart` | Match | Capture, filter, status chips present. |
| Users (`/users`, `pages/UsersPage.tsx`) | User directory/admin | `features/navigation/presentation/pages/user_directory_page.dart` | Match | Accessible to admin/manager/superadmin/techsupport per nav rules. |
| Projects (`/projects`, `pages/ProjectsPage.tsx`) | Project list, updates | `features/projects/presentation/pages/projects_page.dart` + detail/editor | Match | Includes share/update flows. |
| Analytics/Reports (`/analytics`, `pages/AnalyticsPage.tsx`) | Analytics widgets/charts | `features/analytics/presentation/pages/analytics_page.dart` and reports page used in dashboards | Match | Charts/cards implemented; data source parity not validated. |
| Settings (`/settings`, `pages/SettingsPage.tsx`) | Preferences/theme | `features/settings/presentation/pages/settings_page.dart` | Match | Includes theme, notifications, profile link. |
| Profile (`/profile`, `pages/ProfilePage.tsx`) | User profile & stats | `features/profile/presentation/pages/profile_page.dart` | Match | Routed from dashboard tab. |
| Photos & gallery (`/photos`, `pages/PhotosPage.tsx`) | Media gallery, editing | `features/navigation/presentation/pages/photos_page.dart` + photo detail/editor pages | Match | Gallery, metadata, editing, upload. |
| Before/After (`/before-after`, `components/BeforeAfterPhotosV2.tsx`) | Before/after comparison | `features/navigation/presentation/pages/before_after_photos_page.dart` | Match | Includes comparison slider and annotations. |
| QR Scanner (`/qrscanner`, `pages/QRScannerPage.tsx`) | QR/Barcode scan | `features/navigation/presentation/pages/qr_scanner_page.dart` | Match | Role-limited to field roles. |
| Notifications (route covered above) + TopBar AI | Global notifications & AI | `features/dashboard/presentation/widgets/top_bar.dart` + `core/widgets/ai_assistant_overlay.dart` | Match | Role switcher + AI overlay present. |
| Timecards (`/timecards`, `pages/TimecardsPage.tsx`) | Clock-in/out, history | `features/navigation/presentation/pages/timecards_page.dart` | Match | Includes location capture, status chips. |
| AI Tools (`/ai-tools`, `components/AITools.tsx`) | AI utilities hub | `features/ops/presentation/pages/ai_tools_page.dart` | Match | Multiple AI widgets mirrored. |
| Approvals (`/approvals`, `components/ApprovalWorkflow.tsx`) | Approval inbox/workflows | `features/navigation/presentation/pages/approvals_page.dart` | Match | Approvals list, actions. |
| Templates (`/templates`, `components/TemplateBuilder.tsx`) | Template builder/library | `features/templates/presentation/pages/templates_page.dart` + `template_editor_page.dart` | Match | Workflow/report/template tabs with editor. |
| Payments (`/payments`, `components/PaymentRequest.tsx`) | Payment requests | `features/ops/presentation/pages/payment_requests_page.dart` | Match | Requests list and creation. |
| Role Customization (`/role-customization`, `components/RoleCustomization.tsx`) | Rename roles per org | `features/navigation/presentation/pages/role_customization_page.dart` | **Gap (not routed)** | Screen exists but no side menu entry/route wiring; expose to mirror React. |
| Team Roles (`/roles`, `pages/RolesPage.tsx`) | Role management | `features/navigation/presentation/pages/roles_page.dart` | Match | Admin-only route. |
| Roles & Permissions (`/roles-permissions`, `pages/RolesPermissionsPage.tsx`) | Permission matrix | `features/navigation/presentation/pages/roles_permissions_page.dart` | Match | Superadmin route. |
| Support Tickets (`/tickets`, `pages/TicketsPage.tsx`) | Support queue | `features/navigation/presentation/pages/support_tickets_page.dart` | Match | Tech Support menu. |
| Knowledge Base (`/kb`, `pages/KnowledgeBasePage.tsx`) | KB/library | `features/sop/presentation/pages/sop_library_page.dart` | Match | Tech Support menu. |
| System Logs (`/logs`, `pages/SystemLogsPage.tsx`) | System log viewer | `features/navigation/presentation/pages/system_logs_page.dart` | Match | Tech Support menu. |
| Audit Logs (`/audit`, `pages/AuditLogsPage.tsx`) | Audit trails | `features/navigation/presentation/pages/audit_logs_page.dart` | Match | Admin/Super Admin menus. |
| System Overview (`/system`, `pages/SystemOverviewPage.tsx`) | Infra/health overview | `features/navigation/presentation/pages/system_overview_page.dart` | Match | Super Admin menu. |
| Payroll (`/payroll`, `pages/PayrollPage.tsx`) | Payroll summary | `features/navigation/presentation/pages/payroll_page.dart` | Match | Admin/Super Admin menus. |
| Templates/Builder components (e.g., `components/TemplateBuilder.tsx`, `TemplateManager.tsx`) | Rich builder widgets | `features/templates/presentation/pages/templates_page.dart` | Match | Drag/drop and metadata supported. |
| AI Assistant chat (`components/AIAssistantChat.tsx`) | Global assistant | `core/widgets/ai_assistant_overlay.dart` | Match | Present in dashboard shell. |

## Recommendations
- Wire the **Role Customization** screen into navigation (e.g., add `SideMenuRoute.roleCustomization` and route handler) so it matches the React `/role-customization` entry.
- For Organization management parity, verify that the admin console route (`AdminDashboardPage` with `initialSectionId: 'orgs'`) surfaces the same membership/department/tools found in the React `OrganizationPage`; add any missing tabs/widgets as needed.
- If deeper fidelity is required, spot-check data behaviours (permissions enforcement, Supabase queries, exports) on a per-page basis, since this audit focused on UI/feature presence.
