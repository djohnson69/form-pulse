import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/onboarding_repository.dart';
import '../../data/subscription_models.dart';

/// Stripe publishable key - injected via dart-define or defaults to test key
const String _stripePublishableKey = String.fromEnvironment(
  'STRIPE_PUBLISHABLE_KEY',
  defaultValue: 'pk_test_51SrrEaQoE0EiYQ1e6wv3hqXbGEEVlPW5uwizHLXIpx7qAdmlTsEHEjtx3jtja7ukxYi1xXIPuQGd2CZSXVuLQbyt006xtZQpwR',
);

/// Enterprise onboarding wizard with multi-step flow
/// Can be used either:
/// 1. For new signups (isNewSignup=true): Collects account info first, then org info
/// 2. For existing users (isNewSignup=false): Skips account info, just collects org info
class EnterpriseOnboardingPage extends ConsumerStatefulWidget {
  const EnterpriseOnboardingPage({
    super.key,
    required this.onCompleted,
    this.isNewSignup = false,
  });

  final VoidCallback onCompleted;
  /// If true, this is a new signup flow that collects account info first
  final bool isNewSignup;

  @override
  ConsumerState<EnterpriseOnboardingPage> createState() =>
      _EnterpriseOnboardingPageState();
}

class _EnterpriseOnboardingPageState
    extends ConsumerState<EnterpriseOnboardingPage> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;
  String? _error;

  // Step 0 (new signup only): Account Info
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _userPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;

  // Step 1: Company Info
  final _companyNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  String? _selectedIndustry;
  String? _selectedCompanySize;

  // Step 2: Company Details
  final _websiteController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  String _selectedCountry = 'US';
  final _taxIdController = TextEditingController();

  // Step 3: Plan Selection
  String _selectedPlanName = 'pro';
  BillingCycle _selectedBillingCycle = BillingCycle.yearly;

  // Step 4: Billing Info
  final _billingEmailController = TextEditingController();
  final _billingNameController = TextEditingController();
  bool _sameAsCompanyAddress = true;
  final _billingAddressLine1Controller = TextEditingController();
  final _billingAddressLine2Controller = TextEditingController();
  final _billingCityController = TextEditingController();
  final _billingStateController = TextEditingController();
  final _billingPostalCodeController = TextEditingController();
  String _billingCountry = 'US';
  final _billingTaxIdController = TextEditingController();
  bool _poRequired = false;

  // Stripe payment collection
  bool _cardComplete = false;
  String? _stripeCustomerId;
  String? _setupIntentClientSecret;
  String? _stripePaymentMethodId; // Saved after card confirmation
  bool _stripeInitialized = false;

  // Step 5: Team Invites
  final List<_TeamInvite> _teamInvites = [];

  // Step titles depend on whether this is a new signup
  List<String> get _stepTitles => widget.isNewSignup
      ? const [
          'Create Account',
          'Company Info',
          'Company Details',
          'Select Plan',
          'Billing Info',
          'Invite Team',
          'Review',
        ]
      : const [
          'Company Info',
          'Company Details',
          'Select Plan',
          'Billing Info',
          'Invite Team',
          'Review',
        ];

  int get _totalSteps => _stepTitles.length;

  // Map current step to the actual step type (accounting for new signup offset)
  int get _effectiveStep => widget.isNewSignup ? _currentStep : _currentStep + 1;

  @override
  void initState() {
    super.initState();
    _initStripe();
    // Pre-fill billing email with user's email (for existing users)
    if (!widget.isNewSignup) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.email != null) {
        _billingEmailController.text = user!.email!;
      }
    }
  }

  Future<void> _initStripe() async {
    if (_stripeInitialized) return;
    try {
      Stripe.publishableKey = _stripePublishableKey;
      if (kIsWeb) {
        // Web requires calling initialise() to load Stripe.js and create the Stripe instance
        await Stripe.instance.initialise(publishableKey: _stripePublishableKey);
      } else {
        await Stripe.instance.applySettings();
      }
      setState(() => _stripeInitialized = true);
    } catch (e) {
      debugPrint('Failed to initialize Stripe: $e');
    }
  }

  /// Creates a Stripe SetupIntent for collecting payment method
  Future<void> _createSetupIntent() async {
    if (_setupIntentClientSecret != null) return; // Already created

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'stripe-setup-intent',
        body: {
          'email': widget.isNewSignup
              ? _emailController.text.trim()
              : _billingEmailController.text.trim(),
          'companyName': _companyNameController.text.trim(),
          'billingName': _billingNameController.text.trim().isNotEmpty
              ? _billingNameController.text.trim()
              : null,
          'billingAddress': {
            'line1': _sameAsCompanyAddress
                ? _addressLine1Controller.text.trim()
                : _billingAddressLine1Controller.text.trim(),
            'line2': _sameAsCompanyAddress
                ? _addressLine2Controller.text.trim()
                : _billingAddressLine2Controller.text.trim(),
            'city': _sameAsCompanyAddress
                ? _cityController.text.trim()
                : _billingCityController.text.trim(),
            'state': _sameAsCompanyAddress
                ? _stateController.text.trim()
                : _billingStateController.text.trim(),
            'postalCode': _sameAsCompanyAddress
                ? _postalCodeController.text.trim()
                : _billingPostalCodeController.text.trim(),
            'country': _sameAsCompanyAddress ? _selectedCountry : _billingCountry,
          },
        },
      );

      final data = response.data;
      if (data is Map && data['ok'] == true) {
        setState(() {
          _setupIntentClientSecret = data['clientSecret'] as String?;
          _stripeCustomerId = data['customerId'] as String?;
        });
      } else {
        final error = data is Map ? data['error']?.toString() : 'Unknown error';
        throw Exception(error);
      }
    } catch (e) {
      debugPrint('Failed to create setup intent: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Account info controllers
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _userPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    // Company info controllers
    _companyNameController.dispose();
    _displayNameController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _taxIdController.dispose();
    _billingEmailController.dispose();
    _billingNameController.dispose();
    _billingAddressLine1Controller.dispose();
    _billingAddressLine2Controller.dispose();
    _billingCityController.dispose();
    _billingStateController.dispose();
    _billingPostalCodeController.dispose();
    _billingTaxIdController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (!_validateCurrentStep()) return;

    // For billing step, confirm the card with Stripe before proceeding
    if (_effectiveStep == 4 && _stripePaymentMethodId == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        // Create SetupIntent if not already created
        await _createSetupIntent();

        if (_setupIntentClientSecret == null) {
          throw Exception('Failed to initialize payment. Please try again.');
        }

        // Confirm the SetupIntent with Stripe to save the card
        final setupIntentResult = await Stripe.instance.confirmSetupIntent(
          paymentIntentClientSecret: _setupIntentClientSecret!,
          params: const PaymentMethodParams.card(
            paymentMethodData: PaymentMethodData(),
          ),
        );

        final paymentMethodId = setupIntentResult.paymentMethodId;
        if (paymentMethodId.isEmpty) {
          throw Exception('Failed to save payment method. Please try again.');
        }

        setState(() {
          _stripePaymentMethodId = paymentMethodId;
          _isLoading = false;
        });
      } on StripeException catch (e) {
        setState(() {
          _error = e.error.localizedMessage ?? 'Card verification failed';
          _isLoading = false;
        });
        return;
      } catch (e) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
        return;
      }
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
        _error = null;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _error = null;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    // Use _effectiveStep to map to actual step content
    switch (_effectiveStep) {
      case 0: // Account Info (new signup only)
        if (_firstNameController.text.trim().isEmpty) {
          setState(() => _error = 'First name is required');
          return false;
        }
        if (_lastNameController.text.trim().isEmpty) {
          setState(() => _error = 'Last name is required');
          return false;
        }
        if (_emailController.text.trim().isEmpty) {
          setState(() => _error = 'Email is required');
          return false;
        }
        if (!_emailController.text.contains('@')) {
          setState(() => _error = 'Please enter a valid email');
          return false;
        }
        if (_passwordController.text.isEmpty) {
          setState(() => _error = 'Password is required');
          return false;
        }
        if (_passwordController.text.length < 8) {
          setState(() => _error = 'Password must be at least 8 characters');
          return false;
        }
        if (!RegExp(r'[A-Z]').hasMatch(_passwordController.text)) {
          setState(() => _error = 'Password must contain at least one uppercase letter');
          return false;
        }
        if (!RegExp(r'[0-9]').hasMatch(_passwordController.text)) {
          setState(() => _error = 'Password must contain at least one number');
          return false;
        }
        if (_confirmPasswordController.text != _passwordController.text) {
          setState(() => _error = 'Passwords do not match');
          return false;
        }
        if (!_agreedToTerms) {
          setState(() => _error = 'Please agree to the Terms and Conditions');
          return false;
        }
        // Pre-fill billing email with account email
        if (_billingEmailController.text.isEmpty) {
          _billingEmailController.text = _emailController.text.trim();
        }
        return true;

      case 1: // Company Info
        if (_companyNameController.text.trim().isEmpty) {
          setState(() => _error = 'Company name is required');
          return false;
        }
        if (_selectedIndustry == null) {
          setState(() => _error = 'Please select an industry');
          return false;
        }
        if (_selectedCompanySize == null) {
          setState(() => _error = 'Please select company size');
          return false;
        }
        return true;

      case 2: // Company Details (optional)
        return true;

      case 3: // Plan Selection
        return true;

      case 4: // Billing Info
        if (_billingEmailController.text.trim().isEmpty) {
          setState(() => _error = 'Billing email is required');
          return false;
        }
        if (!_billingEmailController.text.contains('@')) {
          setState(() => _error = 'Please enter a valid email');
          return false;
        }
        if (!_cardComplete) {
          setState(() => _error = 'Please enter valid credit card information');
          return false;
        }
        return true;

      case 5: // Team Invites (optional)
        return true;

      default:
        return true;
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Payment method should already be saved when leaving billing step
      if (_stripePaymentMethodId == null || _stripeCustomerId == null) {
        throw Exception('Payment method not configured. Please go back to billing step.');
      }

      final repo = ref.read(onboardingRepositoryProvider);

      // Prepare team invites
      final teamInvites = _teamInvites
          .where((i) => i.email.isNotEmpty)
          .map((i) => {'email': i.email, 'role': i.role})
          .toList();

      // For new signups, create the account first
      if (widget.isNewSignup) {
        await repo.signUpAndOnboard(
          // Stripe payment info
          stripeCustomerId: _stripeCustomerId,
          stripePaymentMethodId: _stripePaymentMethodId,
          // Account info
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          userPhone: _userPhoneController.text.trim().isNotEmpty
              ? _userPhoneController.text.trim()
              : null,
          // Organization info
          orgName: _companyNameController.text.trim(),
          displayName: _displayNameController.text.trim().isNotEmpty
              ? _displayNameController.text.trim()
              : null,
          industry: _selectedIndustry,
          companySize: _selectedCompanySize,
          website: _websiteController.text.trim().isNotEmpty
              ? _websiteController.text.trim()
              : null,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          addressLine1: _addressLine1Controller.text.trim().isNotEmpty
              ? _addressLine1Controller.text.trim()
              : null,
          addressLine2: _addressLine2Controller.text.trim().isNotEmpty
              ? _addressLine2Controller.text.trim()
              : null,
          city: _cityController.text.trim().isNotEmpty
              ? _cityController.text.trim()
              : null,
          state: _stateController.text.trim().isNotEmpty
              ? _stateController.text.trim()
              : null,
          postalCode: _postalCodeController.text.trim().isNotEmpty
              ? _postalCodeController.text.trim()
              : null,
          country: _selectedCountry,
          taxId: _taxIdController.text.trim().isNotEmpty
              ? _taxIdController.text.trim()
              : null,
          planName: _selectedPlanName,
          billingCycle: _selectedBillingCycle.name,
          billingEmail: _billingEmailController.text.trim(),
          billingName: _billingNameController.text.trim().isNotEmpty
              ? _billingNameController.text.trim()
              : null,
          billingAddressLine1: _sameAsCompanyAddress
              ? _addressLine1Controller.text.trim()
              : _billingAddressLine1Controller.text.trim(),
          billingAddressLine2: _sameAsCompanyAddress
              ? _addressLine2Controller.text.trim()
              : _billingAddressLine2Controller.text.trim(),
          billingCity: _sameAsCompanyAddress
              ? _cityController.text.trim()
              : _billingCityController.text.trim(),
          billingState: _sameAsCompanyAddress
              ? _stateController.text.trim()
              : _billingStateController.text.trim(),
          billingPostalCode: _sameAsCompanyAddress
              ? _postalCodeController.text.trim()
              : _billingPostalCodeController.text.trim(),
          billingCountry: _sameAsCompanyAddress ? _selectedCountry : _billingCountry,
          billingTaxId: _billingTaxIdController.text.trim().isNotEmpty
              ? _billingTaxIdController.text.trim()
              : null,
          poRequired: _poRequired,
          teamInvites: teamInvites.isEmpty ? null : teamInvites,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Please check your email to verify, then sign in.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Existing user onboarding
        await repo.completeOnboarding(
          // Stripe payment info
          stripeCustomerId: _stripeCustomerId,
          stripePaymentMethodId: _stripePaymentMethodId,
          orgName: _companyNameController.text.trim(),
          displayName: _displayNameController.text.trim().isNotEmpty
              ? _displayNameController.text.trim()
              : null,
          industry: _selectedIndustry,
          companySize: _selectedCompanySize,
          website: _websiteController.text.trim().isNotEmpty
              ? _websiteController.text.trim()
              : null,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          addressLine1: _addressLine1Controller.text.trim().isNotEmpty
              ? _addressLine1Controller.text.trim()
              : null,
          addressLine2: _addressLine2Controller.text.trim().isNotEmpty
              ? _addressLine2Controller.text.trim()
              : null,
          city: _cityController.text.trim().isNotEmpty
              ? _cityController.text.trim()
              : null,
          state: _stateController.text.trim().isNotEmpty
              ? _stateController.text.trim()
              : null,
          postalCode: _postalCodeController.text.trim().isNotEmpty
              ? _postalCodeController.text.trim()
              : null,
          country: _selectedCountry,
          taxId: _taxIdController.text.trim().isNotEmpty
              ? _taxIdController.text.trim()
              : null,
          planName: _selectedPlanName,
          billingCycle: _selectedBillingCycle.name,
          billingEmail: _billingEmailController.text.trim(),
          billingName: _billingNameController.text.trim().isNotEmpty
              ? _billingNameController.text.trim()
              : null,
          billingAddressLine1: _sameAsCompanyAddress
              ? _addressLine1Controller.text.trim()
              : _billingAddressLine1Controller.text.trim(),
          billingAddressLine2: _sameAsCompanyAddress
              ? _addressLine2Controller.text.trim()
              : _billingAddressLine2Controller.text.trim(),
          billingCity: _sameAsCompanyAddress
              ? _cityController.text.trim()
              : _billingCityController.text.trim(),
          billingState: _sameAsCompanyAddress
              ? _stateController.text.trim()
              : _billingStateController.text.trim(),
          billingPostalCode: _sameAsCompanyAddress
              ? _postalCodeController.text.trim()
              : _billingPostalCodeController.text.trim(),
          billingCountry: _sameAsCompanyAddress ? _selectedCountry : _billingCountry,
          billingTaxId: _billingTaxIdController.text.trim().isNotEmpty
              ? _billingTaxIdController.text.trim()
              : null,
          poRequired: _poRequired,
          teamInvites: teamInvites.isEmpty ? null : teamInvites,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Organization setup complete! Starting your 14-day trial.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  void _goBackToLogin() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with progress
            _buildHeader(theme, colors),

            // Main content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  if (widget.isNewSignup) _buildAccountInfoStep(theme, colors),
                  _buildCompanyInfoStep(theme, colors),
                  _buildCompanyDetailsStep(theme, colors),
                  _buildPlanSelectionStep(theme, colors),
                  _buildBillingInfoStep(theme, colors),
                  _buildTeamInvitesStep(theme, colors),
                  _buildReviewStep(theme, colors),
                ],
              ),
            ),

            // Error message
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                color: colors.errorContainer,
                child: Text(
                  _error!,
                  style: TextStyle(color: colors.onErrorContainer),
                  textAlign: TextAlign.center,
                ),
              ),

            // Navigation buttons
            _buildNavigationButtons(theme, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        children: [
          // Logo and back/sign out
          Row(
            children: [
              Image.asset(
                'assets/branding/form_bridge_logo.png',
                height: 40,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              if (widget.isNewSignup)
                TextButton.icon(
                  onPressed: _isLoading ? null : _goBackToLogin,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to login'),
                )
              else
                TextButton.icon(
                  onPressed: _isLoading ? null : _signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign out'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Step indicator
          Row(
            children: List.generate(_totalSteps, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;
              return Expanded(
                child: Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted || isCurrent
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                      ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? colors.primary
                            : isCurrent
                                ? colors.primaryContainer
                                : colors.surfaceContainerHighest,
                        border: isCurrent
                            ? Border.all(color: colors.primary, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? Icon(Icons.check, size: 16, color: colors.onPrimary)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isCurrent
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                  fontWeight:
                                      isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                      ),
                    ),
                    if (index < _totalSteps - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Step title
          Text(
            _stepTitles[_currentStep],
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoStep(ThemeData theme, ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create your account',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your details to get started with Form Bridge.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 32),

              // Name row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'you@company.com',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              // Phone (optional)
              TextField(
                controller: _userPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (optional)',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 24),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  helperText: 'At least 8 characters with uppercase and number',
                ),
              ),
              const SizedBox(height: 16),

              // Confirm password
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Terms checkbox
              CheckboxListTile(
                value: _agreedToTerms,
                onChanged: (value) =>
                    setState(() => _agreedToTerms = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text.rich(
                  TextSpan(
                    text: 'I agree to the ',
                    children: [
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyInfoStep(ThemeData theme, ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell us about your company',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This information helps us customize your experience.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 32),

              // Company name
              TextField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: 'Company Name *',
                  hintText: 'Acme Corporation',
                  prefixIcon: Icon(Icons.business),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Display name (optional)
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name (optional)',
                  hintText: 'Acme',
                  helperText: 'Short name shown in the app',
                  prefixIcon: Icon(Icons.short_text),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),

              // Industry
              DropdownButtonFormField<String>(
                value: _selectedIndustry,
                decoration: const InputDecoration(
                  labelText: 'Industry *',
                  prefixIcon: Icon(Icons.category),
                ),
                items: IndustryOptions.all.map((industry) {
                  return DropdownMenuItem(
                    value: industry,
                    child: Text(IndustryOptions.displayName(industry)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedIndustry = value),
              ),
              const SizedBox(height: 16),

              // Company size
              DropdownButtonFormField<String>(
                value: _selectedCompanySize,
                decoration: const InputDecoration(
                  labelText: 'Company Size *',
                  prefixIcon: Icon(Icons.people),
                ),
                items: CompanySizeOptions.all.map((size) {
                  return DropdownMenuItem(
                    value: size,
                    child: Text(CompanySizeOptions.displayName(size)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedCompanySize = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyDetailsStep(ThemeData theme, ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Company Details',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Optional details for your company profile.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 32),

              // Website
              TextField(
                controller: _websiteController,
                decoration: const InputDecoration(
                  labelText: 'Website',
                  hintText: 'https://example.com',
                  prefixIcon: Icon(Icons.language),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),

              // Phone
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '+1 (555) 123-4567',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              Text(
                'Business Address',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // Address Line 1
              TextField(
                controller: _addressLine1Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 1',
                  hintText: '123 Main Street',
                  prefixIcon: Icon(Icons.location_on),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Address Line 2
              TextField(
                controller: _addressLine2Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 2',
                  hintText: 'Suite 100',
                  prefixIcon: Icon(Icons.apartment),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // City, State, Postal Code
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        hintText: 'San Francisco',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        hintText: 'CA',
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _postalCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Postal Code',
                        hintText: '94102',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Country
              DropdownButtonFormField<String>(
                value: _selectedCountry,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  prefixIcon: Icon(Icons.flag),
                ),
                items: const [
                  DropdownMenuItem(value: 'US', child: Text('United States')),
                  DropdownMenuItem(value: 'CA', child: Text('Canada')),
                  DropdownMenuItem(value: 'UK', child: Text('United Kingdom')),
                  DropdownMenuItem(value: 'AU', child: Text('Australia')),
                  DropdownMenuItem(value: 'DE', child: Text('Germany')),
                  DropdownMenuItem(value: 'FR', child: Text('France')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (value) =>
                    setState(() => _selectedCountry = value ?? 'US'),
              ),
              const SizedBox(height: 24),

              // Tax ID
              TextField(
                controller: _taxIdController,
                decoration: const InputDecoration(
                  labelText: 'Tax ID / EIN (optional)',
                  hintText: 'XX-XXXXXXX',
                  prefixIcon: Icon(Icons.receipt_long),
                  helperText: 'For invoicing purposes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanSelectionStep(ThemeData theme, ColorScheme colors) {
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  Text(
                    'Choose your plan',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start with a 14-day free trial. You will not be charged until the trial ends.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),

                  // Billing cycle toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCycleToggle(
                          'Monthly',
                          BillingCycle.monthly,
                          colors,
                        ),
                        _buildCycleToggle(
                          'Yearly (Save 20%)',
                          BillingCycle.yearly,
                          colors,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Plans
                  plansAsync.when(
                    data: (plans) => _buildPlanCards(plans, theme, colors),
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Center(
                      child: Text('Error loading plans: $error'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleToggle(
    String label,
    BillingCycle cycle,
    ColorScheme colors,
  ) {
    final isSelected = _selectedBillingCycle == cycle;
    return GestureDetector(
      onTap: () => setState(() => _selectedBillingCycle = cycle),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colors.onPrimary : colors.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCards(
    List<SubscriptionPlan> plans,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final isWide = MediaQuery.of(context).size.width > 700;

    // Reorder plans: Professional (recommended) first, then Starter, then Enterprise
    final orderedPlans = <SubscriptionPlan>[];
    final proPlan = plans.where((p) => p.name == 'pro').firstOrNull;
    final starterPlan = plans.where((p) => p.name == 'starter').firstOrNull;
    final enterprisePlan = plans.where((p) => p.name == 'enterprise').firstOrNull;

    if (proPlan != null) orderedPlans.add(proPlan);
    if (starterPlan != null) orderedPlans.add(starterPlan);
    if (enterprisePlan != null) orderedPlans.add(enterprisePlan);

    // Add any other plans not in our predefined order
    for (final plan in plans) {
      if (!orderedPlans.contains(plan)) {
        orderedPlans.add(plan);
      }
    }

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: orderedPlans
            .map((plan) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildPlanCard(plan, theme, colors),
                  ),
                ))
            .toList(),
      );
    }

    return Column(
      children: orderedPlans
          .map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPlanCard(plan, theme, colors),
              ))
          .toList(),
    );
  }

  Widget _buildPlanCard(
    SubscriptionPlan plan,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final isSelected = _selectedPlanName == plan.name;
    final isRecommended = plan.name == 'pro';
    final price = _selectedBillingCycle == BillingCycle.yearly
        ? plan.yearlyMonthlyPriceDisplay
        : plan.monthlyPriceDisplay;

    // Green color for recommended plan
    const recommendedColor = Color(0xFF4CAF50);

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanName = plan.name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : isRecommended
                    ? recommendedColor
                    : colors.outlineVariant,
            width: isSelected || isRecommended ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : isRecommended
                  ? [
                      BoxShadow(
                        color: recommendedColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
        ),
        child: Column(
          children: [
            // Recommended badge
            if (isRecommended)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  color: recommendedColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
                child: const Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan name
                  Text(
                    plan.displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (plan.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      plan.description!,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/month',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedBillingCycle == BillingCycle.yearly) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Billed annually (${plan.yearlyPriceDisplay}/year)',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Features
                  _buildFeatureRow(Icons.people, plan.userLimitDisplay, colors),
                  _buildFeatureRow(Icons.storage, plan.storageLimitDisplay, colors),
                  _buildFeatureRow(Icons.article, plan.formsLimitDisplay, colors),
                  _buildFeatureRow(
                    Icons.send,
                    plan.submissionsLimitDisplay,
                    colors,
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),

                  if (plan.features.analytics)
                    _buildFeatureRow(Icons.check, 'Analytics', colors),
                  if (plan.features.customBranding)
                    _buildFeatureRow(Icons.check, 'Custom Branding', colors),
                  if (plan.features.apiAccess)
                    _buildFeatureRow(Icons.check, 'API Access', colors),
                  if (plan.features.auditLogs)
                    _buildFeatureRow(Icons.check, 'Audit Logs', colors),
                  if (plan.features.sso)
                    _buildFeatureRow(Icons.check, 'SSO/SAML', colors),
                  if (plan.features.prioritySupport)
                    _buildFeatureRow(Icons.check, 'Priority Support', colors),

                  const SizedBox(height: 16),

                  // Select button
                  SizedBox(
                    width: double.infinity,
                    child: isSelected
                        ? FilledButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.check),
                            label: const Text('Selected'),
                          )
                        : OutlinedButton(
                            onPressed: () =>
                                setState(() => _selectedPlanName = plan.name),
                            child: const Text('Select Plan'),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingInfoStep(ThemeData theme, ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Billing Information',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'For your subscription invoices and receipts.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user, color: colors.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Credit card required. You will not be charged until your 14-day trial ends.',
                        style: TextStyle(color: colors.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Payment Method Section
              Text(
                'Payment Method *',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your card will be saved for automatic billing after the trial period.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),

              // Stripe Card Field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _cardComplete
                        ? colors.primary
                        : colors.outline,
                    width: _cardComplete ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CardField(
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  onCardChanged: (card) {
                    setState(() {
                      _cardComplete = card?.complete ?? false;
                    });
                  },
                ),
              ),
              if (_cardComplete)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: colors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Card information is valid',
                        style: TextStyle(color: colors.primary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 14, color: colors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Secured by Stripe',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Billing email
              TextField(
                controller: _billingEmailController,
                decoration: const InputDecoration(
                  labelText: 'Billing Email *',
                  hintText: 'billing@company.com',
                  prefixIcon: Icon(Icons.email),
                  helperText: 'Invoices will be sent to this email',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Billing name
              TextField(
                controller: _billingNameController,
                decoration: const InputDecoration(
                  labelText: 'Billing Name',
                  hintText: 'Acme Corporation',
                  prefixIcon: Icon(Icons.badge),
                  helperText: 'Name to appear on invoices',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),

              // Same as company address checkbox
              CheckboxListTile(
                value: _sameAsCompanyAddress,
                onChanged: (value) =>
                    setState(() => _sameAsCompanyAddress = value ?? true),
                title: const Text('Billing address same as company address'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              if (!_sameAsCompanyAddress) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _billingAddressLine1Controller,
                  decoration: const InputDecoration(
                    labelText: 'Billing Address Line 1',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _billingAddressLine2Controller,
                  decoration: const InputDecoration(
                    labelText: 'Billing Address Line 2',
                    prefixIcon: Icon(Icons.apartment),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _billingCityController,
                        decoration: const InputDecoration(labelText: 'City'),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _billingStateController,
                        decoration: const InputDecoration(labelText: 'State'),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _billingPostalCodeController,
                        decoration: const InputDecoration(labelText: 'Postal Code'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _billingCountry,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    prefixIcon: Icon(Icons.flag),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'US', child: Text('United States')),
                    DropdownMenuItem(value: 'CA', child: Text('Canada')),
                    DropdownMenuItem(value: 'UK', child: Text('United Kingdom')),
                    DropdownMenuItem(value: 'AU', child: Text('Australia')),
                    DropdownMenuItem(value: 'DE', child: Text('Germany')),
                    DropdownMenuItem(value: 'FR', child: Text('France')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (value) =>
                      setState(() => _billingCountry = value ?? 'US'),
                ),
              ],

              const SizedBox(height: 24),

              // Tax ID
              TextField(
                controller: _billingTaxIdController,
                decoration: const InputDecoration(
                  labelText: 'Tax ID / VAT Number (optional)',
                  hintText: 'XX-XXXXXXX',
                  prefixIcon: Icon(Icons.receipt_long),
                ),
              ),
              const SizedBox(height: 16),

              // PO required
              CheckboxListTile(
                value: _poRequired,
                onChanged: (value) => setState(() => _poRequired = value ?? false),
                title: const Text('Require Purchase Order (PO) for invoices'),
                subtitle: const Text('Enable if your company requires PO numbers'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamInvitesStep(ThemeData theme, ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite your team',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Invite colleagues to join your organization. You can always invite more later.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 32),

              // Invite list
              ..._teamInvites.asMap().entries.map((entry) {
                final index = entry.key;
                final invite = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'colleague@company.com',
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) =>
                              setState(() => _teamInvites[index].email = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: invite.role,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: const [
                            DropdownMenuItem(
                                value: 'admin', child: Text('Admin')),
                            DropdownMenuItem(
                                value: 'manager', child: Text('Manager')),
                            DropdownMenuItem(
                                value: 'supervisor', child: Text('Supervisor')),
                            DropdownMenuItem(
                                value: 'employee', child: Text('Employee')),
                          ],
                          onChanged: (value) => setState(
                              () => _teamInvites[index].role = value ?? 'employee'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: colors.error),
                        onPressed: () =>
                            setState(() => _teamInvites.removeAt(index)),
                      ),
                    ],
                  ),
                );
              }),

              // Add invite button
              OutlinedButton.icon(
                onPressed: () => setState(
                    () => _teamInvites.add(_TeamInvite(email: '', role: 'employee'))),
                icon: const Icon(Icons.add),
                label: const Text('Add team member'),
              ),

              if (_teamInvites.isEmpty) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.group_add,
                        size: 48,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No invites yet',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can skip this step and invite team members later from the admin dashboard.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewStep(ThemeData theme, ColorScheme colors) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final selectedPlan = plansAsync.asData?.value.firstWhere(
      (p) => p.name == _selectedPlanName,
      orElse: () => plansAsync.asData!.value.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review & Confirm',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please review your information before completing setup.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 32),

              // Account Info Card (new signup only)
              if (widget.isNewSignup) ...[
                _buildReviewCard(
                  theme,
                  colors,
                  'Account Information',
                  Icons.person,
                  [
                    _ReviewItem('Name', '${_firstNameController.text} ${_lastNameController.text}'),
                    _ReviewItem('Email', _emailController.text),
                    if (_userPhoneController.text.isNotEmpty)
                      _ReviewItem('Phone', _userPhoneController.text),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Company Info Card
              _buildReviewCard(
                theme,
                colors,
                'Company Information',
                Icons.business,
                [
                  _ReviewItem('Company Name', _companyNameController.text),
                  if (_displayNameController.text.isNotEmpty)
                    _ReviewItem('Display Name', _displayNameController.text),
                  if (_selectedIndustry != null)
                    _ReviewItem(
                        'Industry', IndustryOptions.displayName(_selectedIndustry!)),
                  if (_selectedCompanySize != null)
                    _ReviewItem('Company Size',
                        CompanySizeOptions.displayName(_selectedCompanySize!)),
                  if (_websiteController.text.isNotEmpty)
                    _ReviewItem('Website', _websiteController.text),
                  if (_phoneController.text.isNotEmpty)
                    _ReviewItem('Phone', _phoneController.text),
                ],
              ),

              if (_addressLine1Controller.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildReviewCard(
                  theme,
                  colors,
                  'Business Address',
                  Icons.location_on,
                  [
                    _ReviewItem('Address', _addressLine1Controller.text),
                    if (_addressLine2Controller.text.isNotEmpty)
                      _ReviewItem('', _addressLine2Controller.text),
                    _ReviewItem(
                      '',
                      '${_cityController.text}, ${_stateController.text} ${_postalCodeController.text}',
                    ),
                    _ReviewItem('Country', _selectedCountry),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Plan Card
              if (selectedPlan != null)
                _buildReviewCard(
                  theme,
                  colors,
                  'Subscription Plan',
                  Icons.workspace_premium,
                  [
                    _ReviewItem('Plan', selectedPlan.displayName),
                    _ReviewItem(
                        'Billing', _selectedBillingCycle.displayName),
                    _ReviewItem(
                      'Price',
                      _selectedBillingCycle == BillingCycle.yearly
                          ? '${selectedPlan.yearlyPriceDisplay}/year'
                          : '${selectedPlan.monthlyPriceDisplay}/month',
                    ),
                    _ReviewItem('Users', selectedPlan.userLimitDisplay),
                    _ReviewItem('Storage', selectedPlan.storageLimitDisplay),
                  ],
                ),

              const SizedBox(height: 16),

              // Billing Info Card
              _buildReviewCard(
                theme,
                colors,
                'Billing Information',
                Icons.receipt_long,
                [
                  _ReviewItem('Email', _billingEmailController.text),
                  if (_billingNameController.text.isNotEmpty)
                    _ReviewItem('Name', _billingNameController.text),
                  if (_poRequired) _ReviewItem('PO Required', 'Yes'),
                ],
              ),

              if (_teamInvites.where((i) => i.email.isNotEmpty).isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildReviewCard(
                  theme,
                  colors,
                  'Team Invitations',
                  Icons.group_add,
                  _teamInvites
                      .where((i) => i.email.isNotEmpty)
                      .map((i) => _ReviewItem(i.email, i.role.toUpperCase()))
                      .toList(),
                ),
              ],

              const SizedBox(height: 24),

              // Trial notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.celebration, color: colors.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '14-Day Free Trial',
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Full access to all features. Cancel anytime.',
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(
    ThemeData theme,
    ColorScheme colors,
    String title,
    IconData icon,
    List<_ReviewItem> items,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((item) {
                if (item.label.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 120),
                        Expanded(
                          child: Text(
                            item.value,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(item.value),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _previousStep,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          const Spacer(),
          if (_currentStep < _totalSteps - 1)
            FilledButton.icon(
              onPressed: _isLoading ? null : _nextStep,
              icon: const Icon(Icons.arrow_forward),
              label: Text(_currentStep == 0 ? 'Get Started' : 'Continue'),
            )
          else
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Complete Setup'),
            ),
        ],
      ),
    );
  }
}

class _TeamInvite {
  _TeamInvite({required this.email, required this.role});
  String email;
  String role;
}

class _ReviewItem {
  _ReviewItem(this.label, this.value);
  final String label;
  final String value;
}
