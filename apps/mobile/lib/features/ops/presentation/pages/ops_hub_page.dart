import 'package:flutter/material.dart';

import 'ai_tools_page.dart';
import 'export_jobs_page.dart';
import 'guest_invites_page.dart';
import 'integrations_page.dart';
import 'news_posts_page.dart';
import 'notebook_pages_page.dart';
import 'notebook_reports_page.dart';
import 'notification_rules_page.dart';
import 'payment_requests_page.dart';
import 'portfolio_items_page.dart';
import 'project_galleries_page.dart';
import 'reviews_page.dart';
import 'signature_requests_page.dart';

class OpsHubPage extends StatelessWidget {
  const OpsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_HubItem>[
      _HubItem(
        icon: Icons.campaign,
        title: 'News & Alerts',
        subtitle: 'Company and site updates',
        page: const NewsPostsPage(),
      ),
      _HubItem(
        icon: Icons.notifications_active,
        title: 'Automation Rules',
        subtitle: 'Reminders and triggers',
        page: const NotificationRulesPage(),
      ),
      _HubItem(
        icon: Icons.menu_book,
        title: 'Notebook',
        subtitle: 'Pages and field notes',
        page: const NotebookPagesPage(),
      ),
      _HubItem(
        icon: Icons.picture_as_pdf,
        title: 'Notebook Reports',
        subtitle: 'Generate PDF reports',
        page: const NotebookReportsPage(),
      ),
      _HubItem(
        icon: Icons.edit_document,
        title: 'Signature Requests',
        subtitle: 'Request and capture approvals',
        page: const SignatureRequestsPage(),
      ),
      _HubItem(
        icon: Icons.photo_library,
        title: 'Project Galleries',
        subtitle: 'Photo timelines and comments',
        page: const ProjectGalleriesPage(),
      ),
      _HubItem(
        icon: Icons.cloud_sync,
        title: 'Integrations',
        subtitle: 'Webhooks and exports',
        page: const IntegrationsPage(),
      ),
      _HubItem(
        icon: Icons.auto_awesome,
        title: 'AI Tools',
        subtitle: 'Summaries, captions, recaps',
        page: const AiToolsPage(),
      ),
      _HubItem(
        icon: Icons.group_add,
        title: 'Guest Access',
        subtitle: 'Invite external collaborators',
        page: const GuestInvitesPage(),
      ),
      _HubItem(
        icon: Icons.payment,
        title: 'Payment Requests',
        subtitle: 'Request on-site payments',
        page: const PaymentRequestsPage(),
      ),
      _HubItem(
        icon: Icons.star_rate,
        title: 'Reviews',
        subtitle: 'Request and track reviews',
        page: const ReviewsPage(),
      ),
      _HubItem(
        icon: Icons.auto_stories,
        title: 'Portfolio',
        subtitle: 'Showcase finished projects',
        page: const PortfolioItemsPage(),
      ),
      _HubItem(
        icon: Icons.file_download,
        title: 'Export Jobs',
        subtitle: 'CSV/Excel exports',
        page: const ExportJobsPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Operations Hub')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            child: ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => item.page),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HubItem {
  const _HubItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
}
