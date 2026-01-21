import 'package:flutter/material.dart';

import 'enterprise_onboarding_page.dart';

/// Registration page that redirects to enterprise onboarding wizard
/// The wizard handles both account creation and organization setup
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Navigate directly to the enterprise onboarding wizard with isNewSignup=true
    // This collects all info (account, company, billing) before creating the account
    return EnterpriseOnboardingPage(
      isNewSignup: true,
      onCompleted: () {
        // After signup completes, go back to login page
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }
}
