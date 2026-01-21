import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'subscription_models.dart';

/// Repository for onboarding and subscription management
class OnboardingRepository {
  OnboardingRepository(this._client);

  final SupabaseClient _client;

  /// Fetch all active subscription plans
  Future<List<SubscriptionPlan>> fetchPlans() async {
    final response = await _client
        .from('subscription_plans')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    return (response as List)
        .map((json) => SubscriptionPlan.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a specific plan by name
  Future<SubscriptionPlan?> fetchPlanByName(String name) async {
    final response = await _client
        .from('subscription_plans')
        .select()
        .eq('name', name)
        .maybeSingle();

    if (response == null) return null;
    return SubscriptionPlan.fromJson(response);
  }

  /// Fetch organization's subscription
  Future<Subscription?> fetchSubscription(String orgId) async {
    final response = await _client
        .from('subscriptions')
        .select('*, subscription_plans(*)')
        .eq('org_id', orgId)
        .maybeSingle();

    if (response == null) return null;
    return Subscription.fromJson(response);
  }

  /// Fetch organization details
  Future<EnhancedOrganization?> fetchOrganization(String orgId) async {
    final response = await _client
        .from('orgs')
        .select()
        .eq('id', orgId)
        .maybeSingle();

    if (response == null) return null;
    return EnhancedOrganization.fromJson(response);
  }

  /// Update organization details
  Future<void> updateOrganization(
    String orgId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('orgs').update(updates).eq('id', orgId);
  }

  /// Fetch billing info for organization
  Future<BillingInfo?> fetchBillingInfo(String orgId) async {
    final response = await _client
        .from('billing_info')
        .select()
        .eq('org_id', orgId)
        .maybeSingle();

    if (response == null) return null;
    return BillingInfo.fromJson(response);
  }

  /// Create or update billing info
  Future<void> upsertBillingInfo(String orgId, BillingInfo info) async {
    await _client.from('billing_info').upsert({
      'org_id': orgId,
      ...info.toJson(),
    });
  }

  /// Fetch invoices for organization
  Future<List<Invoice>> fetchInvoices(String orgId) async {
    final response = await _client
        .from('invoices')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Sign up a new user and complete onboarding in one operation
  /// This creates the account first, then sets up the organization
  Future<Map<String, dynamic>> signUpAndOnboard({
    // Account info
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? userPhone,
    // Stripe payment info
    String? stripeCustomerId,
    String? stripePaymentMethodId,
    // Organization info (same as completeOnboarding)
    required String orgName,
    String? displayName,
    String? industry,
    String? companySize,
    String? website,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? taxId,
    required String planName,
    required String billingCycle,
    required String billingEmail,
    String? billingName,
    String? billingAddressLine1,
    String? billingAddressLine2,
    String? billingCity,
    String? billingState,
    String? billingPostalCode,
    String? billingCountry,
    String? billingTaxId,
    bool? poRequired,
    List<Map<String, String>>? teamInvites,
  }) async {
    // Step 1: Create the user account
    final authResponse = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'phone': userPhone,
        // Store org info in metadata so org-onboard can read it on first login
        'pending_org': {
          'orgName': orgName,
          'displayName': displayName,
          'industry': industry,
          'companySize': companySize,
          'website': website,
          'phone': phone,
          'addressLine1': addressLine1,
          'addressLine2': addressLine2,
          'city': city,
          'state': state,
          'postalCode': postalCode,
          'country': country ?? 'US',
          'taxId': taxId,
          'planName': planName,
          'billingCycle': billingCycle,
          'billingEmail': billingEmail,
          'billingName': billingName,
          'billingAddressLine1': billingAddressLine1,
          'billingAddressLine2': billingAddressLine2,
          'billingCity': billingCity,
          'billingState': billingState,
          'billingPostalCode': billingPostalCode,
          'billingCountry': billingCountry ?? 'US',
          'billingTaxId': billingTaxId,
          'poRequired': poRequired ?? false,
          'teamInvites': teamInvites,
          'stripeCustomerId': stripeCustomerId,
          'stripePaymentMethodId': stripePaymentMethodId,
        },
      },
    );

    if (authResponse.user == null) {
      throw Exception('Failed to create account');
    }

    // If we got a session (email confirmation disabled), complete onboarding now
    if (authResponse.session != null) {
      return completeOnboarding(
        stripeCustomerId: stripeCustomerId,
        stripePaymentMethodId: stripePaymentMethodId,
        orgName: orgName,
        displayName: displayName,
        industry: industry,
        companySize: companySize,
        website: website,
        phone: phone,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        state: state,
        postalCode: postalCode,
        country: country,
        taxId: taxId,
        planName: planName,
        billingCycle: billingCycle,
        billingEmail: billingEmail,
        billingName: billingName,
        billingAddressLine1: billingAddressLine1,
        billingAddressLine2: billingAddressLine2,
        billingCity: billingCity,
        billingState: billingState,
        billingPostalCode: billingPostalCode,
        billingCountry: billingCountry,
        billingTaxId: billingTaxId,
        poRequired: poRequired,
        teamInvites: teamInvites,
      );
    }

    // Email confirmation required - org will be created after confirmation
    // The pending_org metadata will be used when user confirms and logs in
    return {
      'ok': true,
      'pendingEmailConfirmation': true,
      'email': email,
    };
  }

  /// Complete onboarding with all data
  Future<Map<String, dynamic>> completeOnboarding({
    // Stripe payment info
    String? stripeCustomerId,
    String? stripePaymentMethodId,
    required String orgName,
    String? displayName,
    String? industry,
    String? companySize,
    String? website,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? taxId,
    required String planName,
    required String billingCycle,
    required String billingEmail,
    String? billingName,
    String? billingAddressLine1,
    String? billingAddressLine2,
    String? billingCity,
    String? billingState,
    String? billingPostalCode,
    String? billingCountry,
    String? billingTaxId,
    bool? poRequired,
    List<Map<String, String>>? teamInvites,
  }) async {
    final response = await _client.functions.invoke(
      'org-onboard',
      body: {
        'stripeCustomerId': stripeCustomerId,
        'stripePaymentMethodId': stripePaymentMethodId,
        'orgName': orgName,
        'displayName': displayName,
        'industry': industry,
        'companySize': companySize,
        'website': website,
        'phone': phone,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
        'city': city,
        'state': state,
        'postalCode': postalCode,
        'country': country ?? 'US',
        'taxId': taxId,
        'planName': planName,
        'billingCycle': billingCycle,
        'billingEmail': billingEmail,
        'billingName': billingName,
        'billingAddressLine1': billingAddressLine1,
        'billingAddressLine2': billingAddressLine2,
        'billingCity': billingCity,
        'billingState': billingState,
        'billingPostalCode': billingPostalCode,
        'billingCountry': billingCountry ?? 'US',
        'billingTaxId': billingTaxId,
        'poRequired': poRequired ?? false,
        'teamInvites': teamInvites,
      },
    );

    final data = response.data;
    if (data is Map && data['ok'] == true) {
      return Map<String, dynamic>.from(data);
    }

    final error = data is Map ? data['error']?.toString() : 'Unknown error';
    throw Exception(error);
  }

  /// Create Stripe checkout session for subscription
  Future<String> createCheckoutSession({
    required String orgId,
    required String planId,
    required String billingCycle,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final response = await _client.functions.invoke(
      'subscription-create',
      body: {
        'orgId': orgId,
        'planId': planId,
        'billingCycle': billingCycle,
        'successUrl': successUrl,
        'cancelUrl': cancelUrl,
      },
    );

    final data = response.data;
    if (data is Map && data['url'] != null) {
      return data['url'] as String;
    }

    final error = data is Map ? data['error']?.toString() : 'Unknown error';
    throw Exception(error);
  }

  /// Create Stripe billing portal session
  Future<String> createBillingPortalSession({
    required String orgId,
    String? returnUrl,
  }) async {
    final response = await _client.functions.invoke(
      'subscription-manage',
      body: {
        'orgId': orgId,
        'returnUrl': returnUrl,
      },
    );

    final data = response.data;
    if (data is Map && data['url'] != null) {
      return data['url'] as String;
    }

    final error = data is Map ? data['error']?.toString() : 'Unknown error';
    throw Exception(error);
  }

  /// Cancel subscription at period end
  Future<void> cancelSubscription(String orgId) async {
    final response = await _client.functions.invoke(
      'subscription-manage',
      body: {
        'orgId': orgId,
        'action': 'cancel',
      },
    );

    final data = response.data;
    if (data is! Map || data['ok'] != true) {
      final error = data is Map ? data['error']?.toString() : 'Unknown error';
      throw Exception(error);
    }
  }

  /// Resume canceled subscription
  Future<void> resumeSubscription(String orgId) async {
    final response = await _client.functions.invoke(
      'subscription-manage',
      body: {
        'orgId': orgId,
        'action': 'resume',
      },
    );

    final data = response.data;
    if (data is! Map || data['ok'] != true) {
      final error = data is Map ? data['error']?.toString() : 'Unknown error';
      throw Exception(error);
    }
  }
}

/// Provider for OnboardingRepository
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(Supabase.instance.client);
});

/// Provider for subscription plans
final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) async {
  final repo = ref.read(onboardingRepositoryProvider);
  return repo.fetchPlans();
});

/// Provider for current org's subscription
final currentSubscriptionProvider =
    FutureProvider.autoDispose.family<Subscription?, String>((ref, orgId) async {
  final repo = ref.read(onboardingRepositoryProvider);
  return repo.fetchSubscription(orgId);
});

/// Provider for current org's billing info
final billingInfoProvider =
    FutureProvider.autoDispose.family<BillingInfo?, String>((ref, orgId) async {
  final repo = ref.read(onboardingRepositoryProvider);
  return repo.fetchBillingInfo(orgId);
});

/// Provider for current org's invoices
final invoicesProvider =
    FutureProvider.autoDispose.family<List<Invoice>, String>((ref, orgId) async {
  final repo = ref.read(onboardingRepositoryProvider);
  return repo.fetchInvoices(orgId);
});
