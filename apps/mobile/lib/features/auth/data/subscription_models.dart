// Subscription and billing models for enterprise onboarding

/// Subscription plan (Starter, Pro, Enterprise)
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    required this.priceMonthly,
    required this.priceYearly,
    required this.maxUsers,
    required this.maxStorageGb,
    required this.maxForms,
    required this.maxSubmissionsPerMonth,
    required this.features,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String displayName;
  final String? description;
  final int priceMonthly; // in cents
  final int priceYearly; // in cents
  final int maxUsers; // -1 for unlimited
  final int maxStorageGb; // -1 for unlimited
  final int maxForms; // -1 for unlimited
  final int maxSubmissionsPerMonth; // -1 for unlimited
  final PlanFeatures features;
  final int sortOrder;

  /// Monthly price formatted as dollars
  String get monthlyPriceDisplay {
    if (priceMonthly == 0) return 'Free';
    return '\$${(priceMonthly / 100).toStringAsFixed(0)}';
  }

  /// Yearly price formatted as dollars
  String get yearlyPriceDisplay {
    if (priceYearly == 0) return 'Free';
    return '\$${(priceYearly / 100).toStringAsFixed(0)}';
  }

  /// Monthly price if paid yearly
  String get yearlyMonthlyPriceDisplay {
    if (priceYearly == 0) return 'Free';
    final monthlyEquivalent = priceYearly / 12 / 100;
    return '\$${monthlyEquivalent.toStringAsFixed(0)}';
  }

  /// User limit display
  String get userLimitDisplay {
    if (maxUsers == -1) return 'Unlimited';
    return '$maxUsers users';
  }

  /// Storage limit display
  String get storageLimitDisplay {
    if (maxStorageGb == -1) return 'Unlimited';
    return '${maxStorageGb}GB';
  }

  /// Forms limit display
  String get formsLimitDisplay {
    if (maxForms == -1) return 'Unlimited';
    return '$maxForms forms';
  }

  /// Submissions limit display
  String get submissionsLimitDisplay {
    if (maxSubmissionsPerMonth == -1) return 'Unlimited';
    return '${maxSubmissionsPerMonth.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}/month';
  }

  bool get isUnlimited =>
      maxUsers == -1 &&
      maxStorageGb == -1 &&
      maxForms == -1 &&
      maxSubmissionsPerMonth == -1;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      description: json['description'] as String?,
      priceMonthly: json['price_monthly'] as int? ?? 0,
      priceYearly: json['price_yearly'] as int? ?? 0,
      maxUsers: json['max_users'] as int? ?? 5,
      maxStorageGb: json['max_storage_gb'] as int? ?? 10,
      maxForms: json['max_forms'] as int? ?? 10,
      maxSubmissionsPerMonth: json['max_submissions_per_month'] as int? ?? 1000,
      features: PlanFeatures.fromJson(
        json['features'] as Map<String, dynamic>? ?? {},
      ),
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

/// Feature flags for a subscription plan
class PlanFeatures {
  const PlanFeatures({
    this.analytics = false,
    this.customBranding = false,
    this.apiAccess = false,
    this.prioritySupport = false,
    this.sso = false,
    this.auditLogs = false,
    this.advancedPermissions = false,
  });

  final bool analytics;
  final bool customBranding;
  final bool apiAccess;
  final bool prioritySupport;
  final bool sso;
  final bool auditLogs;
  final bool advancedPermissions;

  factory PlanFeatures.fromJson(Map<String, dynamic> json) {
    return PlanFeatures(
      analytics: json['analytics'] as bool? ?? false,
      customBranding: json['custom_branding'] as bool? ?? false,
      apiAccess: json['api_access'] as bool? ?? false,
      prioritySupport: json['priority_support'] as bool? ?? false,
      sso: json['sso'] as bool? ?? false,
      auditLogs: json['audit_logs'] as bool? ?? false,
      advancedPermissions: json['advanced_permissions'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'analytics': analytics,
        'custom_branding': customBranding,
        'api_access': apiAccess,
        'priority_support': prioritySupport,
        'sso': sso,
        'audit_logs': auditLogs,
        'advanced_permissions': advancedPermissions,
      };
}

/// Subscription status enum
enum SubscriptionStatus {
  trialing,
  active,
  pastDue,
  canceled,
  unpaid;

  static SubscriptionStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'trialing':
        return SubscriptionStatus.trialing;
      case 'active':
        return SubscriptionStatus.active;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      case 'canceled':
        return SubscriptionStatus.canceled;
      case 'unpaid':
        return SubscriptionStatus.unpaid;
      default:
        return SubscriptionStatus.trialing;
    }
  }

  String get displayName {
    switch (this) {
      case SubscriptionStatus.trialing:
        return 'Trial';
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.pastDue:
        return 'Past Due';
      case SubscriptionStatus.canceled:
        return 'Canceled';
      case SubscriptionStatus.unpaid:
        return 'Unpaid';
    }
  }

  bool get isActive => this == SubscriptionStatus.active || this == SubscriptionStatus.trialing;
}

/// Billing cycle enum
enum BillingCycle {
  monthly,
  yearly;

  static BillingCycle fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'yearly':
        return BillingCycle.yearly;
      default:
        return BillingCycle.monthly;
    }
  }

  String get displayName {
    switch (this) {
      case BillingCycle.monthly:
        return 'Monthly';
      case BillingCycle.yearly:
        return 'Yearly';
    }
  }
}

/// Organization subscription
class Subscription {
  const Subscription({
    required this.id,
    required this.orgId,
    required this.planId,
    required this.status,
    required this.billingCycle,
    this.trialStart,
    this.trialEnd,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.cancelAtPeriodEnd = false,
    this.canceledAt,
    required this.createdAt,
    required this.updatedAt,
    this.plan,
  });

  final String id;
  final String orgId;
  final String planId;
  final SubscriptionStatus status;
  final BillingCycle billingCycle;
  final DateTime? trialStart;
  final DateTime? trialEnd;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final bool cancelAtPeriodEnd;
  final DateTime? canceledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SubscriptionPlan? plan;

  bool get isTrialing => status == SubscriptionStatus.trialing;

  int get trialDaysRemaining {
    if (trialEnd == null) return 0;
    final now = DateTime.now();
    if (now.isAfter(trialEnd!)) return 0;
    return trialEnd!.difference(now).inDays;
  }

  bool get isTrialExpired {
    if (!isTrialing) return false;
    return trialDaysRemaining <= 0;
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      planId: json['plan_id'] as String,
      status: SubscriptionStatus.fromString(json['status'] as String?),
      billingCycle: BillingCycle.fromString(json['billing_cycle'] as String?),
      trialStart: json['trial_start'] != null
          ? DateTime.parse(json['trial_start'] as String)
          : null,
      trialEnd: json['trial_end'] != null
          ? DateTime.parse(json['trial_end'] as String)
          : null,
      currentPeriodStart: json['current_period_start'] != null
          ? DateTime.parse(json['current_period_start'] as String)
          : null,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.parse(json['current_period_end'] as String)
          : null,
      stripeCustomerId: json['stripe_customer_id'] as String?,
      stripeSubscriptionId: json['stripe_subscription_id'] as String?,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      canceledAt: json['canceled_at'] != null
          ? DateTime.parse(json['canceled_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      plan: json['subscription_plans'] != null
          ? SubscriptionPlan.fromJson(
              json['subscription_plans'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// Billing information
class BillingInfo {
  const BillingInfo({
    required this.id,
    required this.orgId,
    required this.billingEmail,
    this.billingName,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country = 'US',
    this.taxId,
    this.taxExempt = false,
    this.poNumber,
    this.poRequired = false,
    this.stripePaymentMethodId,
    this.paymentMethodType,
    this.paymentMethodLast4,
    this.paymentMethodBrand,
    this.paymentMethodExpMonth,
    this.paymentMethodExpYear,
  });

  final String id;
  final String orgId;
  final String billingEmail;
  final String? billingName;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String country;
  final String? taxId;
  final bool taxExempt;
  final String? poNumber;
  final bool poRequired;
  final String? stripePaymentMethodId;
  final String? paymentMethodType;
  final String? paymentMethodLast4;
  final String? paymentMethodBrand;
  final int? paymentMethodExpMonth;
  final int? paymentMethodExpYear;

  bool get hasPaymentMethod => stripePaymentMethodId != null;

  String get paymentMethodDisplay {
    if (!hasPaymentMethod) return 'No payment method';
    final brand = paymentMethodBrand?.toUpperCase() ?? 'Card';
    return '$brand ••••$paymentMethodLast4';
  }

  factory BillingInfo.fromJson(Map<String, dynamic> json) {
    return BillingInfo(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      billingEmail: json['billing_email'] as String,
      billingName: json['billing_name'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String? ?? 'US',
      taxId: json['tax_id'] as String?,
      taxExempt: json['tax_exempt'] as bool? ?? false,
      poNumber: json['po_number'] as String?,
      poRequired: json['po_required'] as bool? ?? false,
      stripePaymentMethodId: json['stripe_payment_method_id'] as String?,
      paymentMethodType: json['payment_method_type'] as String?,
      paymentMethodLast4: json['payment_method_last4'] as String?,
      paymentMethodBrand: json['payment_method_brand'] as String?,
      paymentMethodExpMonth: json['payment_method_exp_month'] as int?,
      paymentMethodExpYear: json['payment_method_exp_year'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'billing_email': billingEmail,
        'billing_name': billingName,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'country': country,
        'tax_id': taxId,
        'tax_exempt': taxExempt,
        'po_number': poNumber,
        'po_required': poRequired,
      };
}

/// Invoice record
class Invoice {
  const Invoice({
    required this.id,
    required this.orgId,
    this.stripeInvoiceId,
    this.stripeInvoiceNumber,
    this.stripeInvoiceUrl,
    this.stripeInvoicePdf,
    required this.amountDue,
    required this.amountPaid,
    required this.currency,
    required this.status,
    this.periodStart,
    this.periodEnd,
    this.dueDate,
    this.paidAt,
    required this.createdAt,
  });

  final String id;
  final String orgId;
  final String? stripeInvoiceId;
  final String? stripeInvoiceNumber;
  final String? stripeInvoiceUrl;
  final String? stripeInvoicePdf;
  final int amountDue;
  final int amountPaid;
  final String currency;
  final String status;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final DateTime createdAt;

  String get amountDueDisplay {
    final symbol = currency.toUpperCase() == 'USD' ? '\$' : currency;
    return '$symbol${(amountDue / 100).toStringAsFixed(2)}';
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      stripeInvoiceId: json['stripe_invoice_id'] as String?,
      stripeInvoiceNumber: json['stripe_invoice_number'] as String?,
      stripeInvoiceUrl: json['stripe_invoice_url'] as String?,
      stripeInvoicePdf: json['stripe_invoice_pdf'] as String?,
      amountDue: json['amount_due'] as int,
      amountPaid: json['amount_paid'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'usd',
      status: json['status'] as String,
      periodStart: json['period_start'] != null
          ? DateTime.parse(json['period_start'] as String)
          : null,
      periodEnd: json['period_end'] != null
          ? DateTime.parse(json['period_end'] as String)
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Enhanced organization model with enterprise fields
class EnhancedOrganization {
  const EnhancedOrganization({
    required this.id,
    required this.name,
    this.displayName,
    this.industry,
    this.companySize,
    this.website,
    this.phone,
    this.logoUrl,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country = 'US',
    this.taxId,
    this.onboardingCompleted = false,
    this.onboardingStep = 0,
    this.settings = const {},
    this.metadata = const {},
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? displayName;
  final String? industry;
  final String? companySize;
  final String? website;
  final String? phone;
  final String? logoUrl;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String country;
  final String? taxId;
  final bool onboardingCompleted;
  final int onboardingStep;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;

  String get effectiveDisplayName => displayName ?? name;

  bool get hasAddress =>
      addressLine1 != null && city != null && state != null && postalCode != null;

  String get fullAddress {
    final parts = <String>[];
    if (addressLine1 != null) parts.add(addressLine1!);
    if (addressLine2 != null) parts.add(addressLine2!);
    if (city != null && state != null && postalCode != null) {
      parts.add('$city, $state $postalCode');
    }
    if (country != 'US') parts.add(country);
    return parts.join('\n');
  }

  factory EnhancedOrganization.fromJson(Map<String, dynamic> json) {
    return EnhancedOrganization(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String?,
      industry: json['industry'] as String?,
      companySize: json['company_size'] as String?,
      website: json['website'] as String?,
      phone: json['phone'] as String?,
      logoUrl: json['logo_url'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String? ?? 'US',
      taxId: json['tax_id'] as String?,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      onboardingStep: json['onboarding_step'] as int? ?? 0,
      settings: json['settings'] as Map<String, dynamic>? ?? {},
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'display_name': displayName,
        'industry': industry,
        'company_size': companySize,
        'website': website,
        'phone': phone,
        'logo_url': logoUrl,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'country': country,
        'tax_id': taxId,
        'onboarding_completed': onboardingCompleted,
        'onboarding_step': onboardingStep,
        'settings': settings,
        'metadata': metadata,
      };
}

/// Industry options for company profile
class IndustryOptions {
  static const List<String> all = [
    'technology',
    'healthcare',
    'manufacturing',
    'construction',
    'retail',
    'finance',
    'education',
    'government',
    'nonprofit',
    'hospitality',
    'transportation',
    'agriculture',
    'energy',
    'media',
    'legal',
    'real_estate',
    'professional_services',
    'other',
  ];

  static String displayName(String industry) {
    switch (industry) {
      case 'technology':
        return 'Technology';
      case 'healthcare':
        return 'Healthcare';
      case 'manufacturing':
        return 'Manufacturing';
      case 'construction':
        return 'Construction';
      case 'retail':
        return 'Retail';
      case 'finance':
        return 'Finance & Banking';
      case 'education':
        return 'Education';
      case 'government':
        return 'Government';
      case 'nonprofit':
        return 'Non-Profit';
      case 'hospitality':
        return 'Hospitality';
      case 'transportation':
        return 'Transportation & Logistics';
      case 'agriculture':
        return 'Agriculture';
      case 'energy':
        return 'Energy & Utilities';
      case 'media':
        return 'Media & Entertainment';
      case 'legal':
        return 'Legal Services';
      case 'real_estate':
        return 'Real Estate';
      case 'professional_services':
        return 'Professional Services';
      case 'other':
        return 'Other';
      default:
        return industry;
    }
  }
}

/// Company size options
class CompanySizeOptions {
  static const List<String> all = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '501-1000',
    '1000+',
  ];

  static String displayName(String size) {
    switch (size) {
      case '1-10':
        return '1-10 employees';
      case '11-50':
        return '11-50 employees';
      case '51-200':
        return '51-200 employees';
      case '201-500':
        return '201-500 employees';
      case '501-1000':
        return '501-1000 employees';
      case '1000+':
        return '1000+ employees';
      default:
        return size;
    }
  }
}
