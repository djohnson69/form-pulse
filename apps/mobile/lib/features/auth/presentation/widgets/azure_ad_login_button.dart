import 'package:flutter/material.dart';
import 'package:msal_flutter/msal_flutter.dart';

/// Azure AD login button for Flutter
class AzureAdLoginButton extends StatefulWidget {
  final void Function(String accessToken) onLogin;
  const AzureAdLoginButton({super.key, required this.onLogin});

  @override
  State<AzureAdLoginButton> createState() => _AzureAdLoginButtonState();
}

class _AzureAdLoginButtonState extends State<AzureAdLoginButton> {
  PublicClientApplication? _pca;
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _pca ??= await PublicClientApplication.createPublicClientApplication(
        'YOUR_AZURE_AD_CLIENT_ID', // TODO: replace with real client ID
        authority: 'https://login.microsoftonline.com/common',
      );
      final token = await _pca!.acquireToken(['User.Read']);
      widget.onLogin(token);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: _loading ? const CircularProgressIndicator() : const Text('Login with Microsoft'),
          onPressed: _loading ? null : _login,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}
