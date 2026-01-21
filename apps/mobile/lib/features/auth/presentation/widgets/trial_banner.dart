import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/onboarding_repository.dart';
import '../../data/subscription_models.dart';

/// Banner showing trial status and days remaining
class TrialBanner extends ConsumerWidget {
  const TrialBanner({
    super.key,
    required this.orgId,
    this.onUpgrade,
  });

  final String orgId;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(currentSubscriptionProvider(orgId));

    return subscriptionAsync.when(
      data: (subscription) {
        if (subscription == null) return const SizedBox.shrink();
        if (!subscription.isTrialing) return const SizedBox.shrink();

        final daysLeft = subscription.trialDaysRemaining;
        final isUrgent = daysLeft <= 3;

        return _TrialBannerContent(
          daysLeft: daysLeft,
          isUrgent: isUrgent,
          onUpgrade: onUpgrade,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TrialBannerContent extends StatelessWidget {
  const _TrialBannerContent({
    required this.daysLeft,
    required this.isUrgent,
    this.onUpgrade,
  });

  final int daysLeft;
  final bool isUrgent;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final backgroundColor = isUrgent
        ? colors.errorContainer
        : colors.primaryContainer;
    final foregroundColor = isUrgent
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;

    return Material(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                isUrgent ? Icons.warning_amber_rounded : Icons.celebration,
                color: foregroundColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getMessage(),
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onUpgrade != null) ...[
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: onUpgrade,
                  style: FilledButton.styleFrom(
                    backgroundColor: foregroundColor.withOpacity(0.2),
                    foregroundColor: foregroundColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('Upgrade'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getMessage() {
    if (daysLeft <= 0) {
      return 'Your trial has ended. Upgrade to continue using all features.';
    } else if (daysLeft == 1) {
      return 'Your trial ends tomorrow! Upgrade now to keep full access.';
    } else if (daysLeft <= 3) {
      return 'Only $daysLeft days left in your trial. Upgrade to continue.';
    } else {
      return '$daysLeft days left in your free trial.';
    }
  }
}

/// Compact trial indicator for app bars
class TrialIndicator extends ConsumerWidget {
  const TrialIndicator({
    super.key,
    required this.orgId,
    this.onTap,
  });

  final String orgId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(currentSubscriptionProvider(orgId));

    return subscriptionAsync.when(
      data: (subscription) {
        if (subscription == null) return const SizedBox.shrink();
        if (!subscription.isTrialing) return const SizedBox.shrink();

        final daysLeft = subscription.trialDaysRemaining;
        final isUrgent = daysLeft <= 3;

        return _TrialIndicatorContent(
          daysLeft: daysLeft,
          isUrgent: isUrgent,
          onTap: onTap,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TrialIndicatorContent extends StatelessWidget {
  const _TrialIndicatorContent({
    required this.daysLeft,
    required this.isUrgent,
    this.onTap,
  });

  final int daysLeft;
  final bool isUrgent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final backgroundColor = isUrgent
        ? colors.errorContainer
        : colors.primaryContainer;
    final foregroundColor = isUrgent
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              size: 14,
              color: foregroundColor,
            ),
            const SizedBox(width: 4),
            Text(
              daysLeft <= 0 ? 'Trial ended' : '$daysLeft days',
              style: TextStyle(
                color: foregroundColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-page trial expired screen
class TrialExpiredPage extends StatelessWidget {
  const TrialExpiredPage({
    super.key,
    this.planName,
    this.onUpgrade,
    this.onSignOut,
  });

  final String? planName;
  final VoidCallback? onUpgrade;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.hourglass_empty,
                      size: 64,
                      color: colors.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Your trial has ended',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your 14-day free trial of ${planName ?? 'Form Bridge'} has expired. '
                    'Upgrade to a paid plan to continue using all features.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onUpgrade,
                      icon: const Icon(Icons.upgrade),
                      label: const Text('Upgrade Now'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Feature gate widget that shows upgrade prompt for gated features
class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    super.key,
    required this.orgId,
    required this.feature,
    required this.child,
    this.fallback,
    this.onUpgrade,
  });

  final String orgId;
  final String feature;
  final Widget child;
  final Widget? fallback;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(currentSubscriptionProvider(orgId));

    return subscriptionAsync.when(
      data: (subscription) {
        // During trial, all features are available
        if (subscription?.isTrialing == true) {
          return child;
        }

        // Check if feature is available in the plan
        final plan = subscription?.plan;
        if (plan == null) {
          return fallback ?? _buildUpgradePrompt(context);
        }

        final hasFeature = _checkFeature(plan.features, feature);
        if (hasFeature) {
          return child;
        }

        return fallback ?? _buildUpgradePrompt(context);
      },
      loading: () => child, // Show content while loading
      error: (_, __) => child, // Show content on error
    );
  }

  bool _checkFeature(PlanFeatures features, String featureName) {
    switch (featureName) {
      case 'analytics':
        return features.analytics;
      case 'custom_branding':
        return features.customBranding;
      case 'api_access':
        return features.apiAccess;
      case 'priority_support':
        return features.prioritySupport;
      case 'sso':
        return features.sso;
      case 'audit_logs':
        return features.auditLogs;
      case 'advanced_permissions':
        return features.advancedPermissions;
      default:
        return true;
    }
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 48,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Feature not available',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade your plan to access this feature.',
            style: TextStyle(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (onUpgrade != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onUpgrade,
              child: const Text('View Plans'),
            ),
          ],
        ],
      ),
    );
  }
}
