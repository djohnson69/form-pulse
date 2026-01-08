import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrgOnboardingPage extends StatefulWidget {
  const OrgOnboardingPage({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<OrgOnboardingPage> createState() => _OrgOnboardingPageState();
}

class _OrgOnboardingPageState extends State<OrgOnboardingPage> {
  final TextEditingController _orgNameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _orgNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final orgName = _orgNameController.text.trim();
    if (orgName.isEmpty) {
      setState(() => _error = 'Company name is required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final res = await client.functions.invoke(
        'org-onboard',
        body: {'orgName': orgName},
      );

      if (!mounted) return;

      final data = res.data;
      final ok = data is Map && data['ok'] == true;
      if (!ok) {
        final serverMessage = data is Map ? data['error']?.toString() : null;
        setState(
          () => _error =
              serverMessage ?? 'Organization setup failed. Please try again.',
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization ready!'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to set up organization: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final inputFill =
        theme.inputDecorationTheme.fillColor ?? colors.surfaceVariant;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/branding/form_bridge_logo.png',
                          height: 96,
                          fit: BoxFit.contain,
                          semanticLabel: 'Form Bridge',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Set up your company',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create an organization to manage members, roles, and data.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _orgNameController,
                        decoration: const InputDecoration(
                          labelText: 'Company name',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _isLoading ? null : _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: colors.error),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Continue'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: inputFill,
                          foregroundColor: colors.onSurface,
                        ),
                        onPressed: _isLoading ? null : _signOut,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
