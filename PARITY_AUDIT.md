# React -> Flutter Parity Audit

Source of truth: `_design/Formbridgereact/src/app/App.tsx` routes and global layout components.

Status key:
- VERIFIED: UI/UX and interactions confirmed 1:1.
- NEEDS_REVIEW: Screen exists but not yet audited.
- PARTIAL: Screen exists but missing major sections or behaviors.
- MISSING: No Flutter screen found.

## Routes and Screens

| React route | React component | Flutter screen | Status | Notes |
| --- | --- | --- | --- | --- |
| `/` | `UserDashboard` / `SuperAdminDashboard` / `MaintenanceDashboard` | `apps/mobile/lib/features/dashboard/presentation/pages/role_dashboard_page.dart`, `apps/mobile/lib/features/admin/presentation/pages/super_admin_dashboard_page.dart` | NEEDS_REVIEW | Role-based dashboards exist; parity not verified. |
| `/tasks` | `TasksPage` | `apps/mobile/lib/features/tasks/presentation/pages/tasks_page.dart` | PARTIAL | Create task modal aligned to React layout; tech support visibility updated; remaining UI/UX parity still needs verification. |
| `/tasks/:id` | `TaskDetailPage` | `apps/mobile/lib/features/tasks/presentation/pages/task_detail_page.dart` | NEEDS_REVIEW |  |
| `/work-orders` | `WorkOrdersPage` | `apps/mobile/lib/features/navigation/presentation/pages/work_orders_page.dart` | PARTIAL | Create/edit modal fields aligned to React; runtime parity still needs verification. |
| `/forms` | `FormsPage` | `apps/mobile/lib/features/navigation/presentation/pages/forms_page.dart` | PARTIAL | Header/filter breakpoints aligned to React; remaining UI/UX parity still needs verification. |
| `/forms/builder` | `FormBuilderPage` | `apps/mobile/lib/features/dashboard/presentation/pages/create_form_page.dart` | NEEDS_REVIEW | Builder flow likely maps here; confirm UI parity. |
| `/forms/:id/submit` | `FormSubmissionPage` | `apps/mobile/lib/features/dashboard/presentation/pages/form_fill_page.dart` | NEEDS_REVIEW |  |
| `/documents` | `DocumentsPage` | `apps/mobile/lib/features/documents/presentation/pages/documents_page.dart` | NEEDS_REVIEW |  |
| `/assets` | `AssetsPage` | `apps/mobile/lib/features/assets/presentation/pages/assets_page.dart` | NEEDS_REVIEW |  |
| `/training` | `TrainingPage` | `apps/mobile/lib/features/training/presentation/pages/training_hub_page.dart` | NEEDS_REVIEW |  |
| `/incidents` | `IncidentsPage` | `apps/mobile/lib/features/navigation/presentation/pages/incidents_page.dart` | NEEDS_REVIEW |  |
| `/users` | `UsersPage` | `apps/mobile/lib/features/navigation/presentation/pages/user_directory_page.dart` | NEEDS_REVIEW |  |
| `/projects` | `ProjectsPage` | `apps/mobile/lib/features/projects/presentation/pages/projects_page.dart` | PARTIAL | New Project button responsive label aligned; remaining UI/UX parity still needs verification. |
| `/analytics` | `AnalyticsPage` | `apps/mobile/lib/features/analytics/presentation/pages/analytics_page.dart` | NEEDS_REVIEW |  |
| `/settings` | `SettingsPage` | `apps/mobile/lib/features/settings/presentation/pages/settings_page.dart` | NEEDS_REVIEW |  |
| `/profile` | `ProfilePage` | `apps/mobile/lib/features/profile/presentation/pages/profile_page.dart` | NEEDS_REVIEW |  |
| `/messages` | `MessagesPage` | `apps/mobile/lib/features/partners/presentation/pages/messages_page.dart` | PARTIAL | Back button and composer visibility aligned; remaining UI/UX parity still needs verification. |
| `/news` | `NewsPage` | `apps/mobile/lib/features/ops/presentation/pages/news_posts_page.dart` | PARTIAL | Layout/spacing, demo data, and sidebar stats/categories aligned to React; needs runtime parity verification. |
| `/photos` | `PhotosPage` | `apps/mobile/lib/features/navigation/presentation/pages/photos_page.dart` | NEEDS_REVIEW |  |
| `/qrscanner` | `QRScannerPage` | `apps/mobile/lib/features/navigation/presentation/pages/qr_scanner_page.dart` | NEEDS_REVIEW |  |
| `/notifications` | `NotificationsPage` | `apps/mobile/lib/features/navigation/presentation/pages/notifications_page.dart` | PARTIAL | Centered layout aligned to React; remaining UI/UX parity still needs verification. |
| `/timecards` | `TimecardsPage` | `apps/mobile/lib/features/navigation/presentation/pages/timecards_page.dart` | NEEDS_REVIEW |  |
| `/ai-tools` | `AITools` | `apps/mobile/lib/features/ops/presentation/pages/ai_tools_page.dart` | NEEDS_REVIEW |  |
| `/approvals` | `ApprovalWorkflow` | `apps/mobile/lib/features/navigation/presentation/pages/approvals_page.dart` | NEEDS_REVIEW |  |
| `/templates` | `TemplateBuilder` | `apps/mobile/lib/features/templates/presentation/pages/templates_page.dart` | PARTIAL | Layout aligned to TemplateBuilder; interactions still need verification. |
| `/payments` | `PaymentRequest` | `apps/mobile/lib/features/ops/presentation/pages/payment_requests_page.dart` | NEEDS_REVIEW |  |
| `/before-after` | `BeforeAfterPhotos` | `apps/mobile/lib/features/navigation/presentation/pages/before_after_photos_page.dart` | NEEDS_REVIEW |  |
| `/role-customization` | `RoleCustomization` | `apps/mobile/lib/features/navigation/presentation/pages/role_customization_page.dart` | NEEDS_REVIEW |  |
| `/team` | `TeamPage` | `apps/mobile/lib/features/teams/presentation/pages/teams_page.dart` | NEEDS_REVIEW |  |
| `/roles` | `RolesPage` | `apps/mobile/lib/features/navigation/presentation/pages/roles_page.dart` | NEEDS_REVIEW |  |
| `/tickets` | `TicketsPage` | `apps/mobile/lib/features/navigation/presentation/pages/support_tickets_page.dart` | NEEDS_REVIEW |  |
| `/kb` | `KnowledgeBasePage` | `apps/mobile/lib/features/sop/presentation/pages/sop_library_page.dart` | PARTIAL | SOP library exists; needs KB parity check. |
| `/logs` | `SystemLogsPage` | `apps/mobile/lib/features/navigation/presentation/pages/system_logs_page.dart` | NEEDS_REVIEW |  |
| `/audit` | `AuditLogsPage` | `apps/mobile/lib/features/navigation/presentation/pages/audit_logs_page.dart` | NEEDS_REVIEW |  |
| `/system` | `SystemOverviewPage` | `apps/mobile/lib/features/navigation/presentation/pages/system_overview_page.dart` | PARTIAL | Layout, spacing, and key metric/service/alert cards aligned to React; runtime parity still needs verification. |
| `/payroll` | `PayrollPage` | `apps/mobile/lib/features/navigation/presentation/pages/payroll_page.dart` | NEEDS_REVIEW |  |
| `/roles-permissions` | `RolesPermissionsPage` | `apps/mobile/lib/features/navigation/presentation/pages/roles_permissions_page.dart` | NEEDS_REVIEW |  |
| `/organization` | `OrganizationPage` | `apps/mobile/lib/features/navigation/presentation/pages/organization_chart_page.dart` | PARTIAL | Layout/spacing, stats cards, and org structure styling aligned; runtime parity still needs verification. |

## Global Layout and Shared Components

| React component | Flutter equivalent | Status | Notes |
| --- | --- | --- | --- |
| `Sidebar` | `apps/mobile/lib/features/navigation/presentation/widgets/side_menu.dart` | PARTIAL | Web view now keeps the side menu visible; mobile still needs parity check. |
| `TopBar` | `apps/mobile/lib/features/dashboard/presentation/widgets/top_bar.dart` | NEEDS_REVIEW | Role switcher + theme toggle present; visual parity to confirm. |
| `AIAssistantChat` | `apps/mobile/lib/core/widgets/ai_assistant_overlay.dart` | NEEDS_REVIEW | Overlay exists; confirm layout/behavior parity. |
| `RightSidebar` | `apps/mobile/lib/features/dashboard/presentation/widgets/right_sidebar.dart` | NEEDS_REVIEW | Verify content and behavior. |

## Notes

- This audit only captures route-level parity. Each page still needs a section-by-section UI/UX and interaction review against the React implementation.
