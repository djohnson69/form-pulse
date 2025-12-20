/// Azure AD JWT validation utility for backend
class AzureAdJwtValidator {
  final String tenantId;
  final String clientId;
  final String issuer;
  final String openIdConfigUrl;

  AzureAdJwtValidator({
    required this.tenantId,
    required this.clientId,
  })  : issuer = 'https://login.microsoftonline.com/$tenantId/v2.0',
        openIdConfigUrl = 'https://login.microsoftonline.com/$tenantId/v2.0/.well-known/openid-configuration';

  Future<Map<String, dynamic>?> validateToken(String token) async {
    // Mock validation for demo - just return mock claims
    // In production, properly validate JWT with JWKS
    return {
      'aud': clientId,
      'iss': issuer,
      'email': 'demo@formpulse.com',
      'preferred_username': 'demo@formpulse.com',
      'given_name': 'Demo',
      'family_name': 'User',
    };
  }
}
