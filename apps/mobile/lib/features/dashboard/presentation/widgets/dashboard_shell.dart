import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/active_role_provider.dart';
import '../../../../core/widgets/ai_assistant_overlay.dart';
import '../../../navigation/presentation/widgets/side_menu.dart';
import 'right_sidebar.dart';
import 'top_bar.dart';

class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.role,
    required this.child,
    required this.onNavigate,
    this.activeRoute = SideMenuRoute.dashboard,
    this.maxContentWidth = 1200,
    this.showRightSidebar = true,
  });

  final UserRole role;
  final Widget child;
  final SideMenuRoute activeRoute;
  final ValueChanged<SideMenuRoute> onNavigate;
  final double maxContentWidth;
  final bool showRightSidebar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidebar = kIsWeb || constraints.maxWidth >= 768;
        final showRightPanel =
            showRightSidebar && constraints.maxWidth >= 1400;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          drawer: showSidebar
              ? null
              : Drawer(
                  child: SideMenu(
                    role: role,
                    activeRoute: activeRoute,
                    isMobile: true,
                    onNavigate: onNavigate,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
          body: Stack(
            children: [
              Column(
                children: [
                  Builder(
                    builder: (context) => TopBar(
                      role: role,
                      isMobile: !showSidebar,
                      onMenuPressed: showSidebar
                          ? null
                          : () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        if (showSidebar)
                          SideMenu(
                            role: role,
                            activeRoute: activeRoute,
                            onNavigate: onNavigate,
                          ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxContentWidth,
                              ),
                              child: ProviderScope(
                                overrides: [
                                  dashboardRoleProvider
                                      .overrideWithValue(role),
                                ],
                                child: Navigator(
                                  key: ValueKey(activeRoute),
                                  onGenerateRoute: (_) => MaterialPageRoute(
                                    builder: (_) => child,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (showRightPanel) const RightSidebar(),
                      ],
                    ),
                  ),
                ],
              ),
              const AiAssistantOverlay(),
            ],
          ),
        );
      },
    );
  }
}
