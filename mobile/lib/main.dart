import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;

const String apiBaseUrl = String.fromEnvironment(
  'PANTRY_API_BASE_URL',
  defaultValue: 'http://localhost:4000',
);
const String oidcIssuer = String.fromEnvironment(
  'PANTRY_OIDC_ISSUER',
  defaultValue: 'http://localhost:8081/realms/test',
);
const String oidcClientId = String.fromEnvironment(
  'PANTRY_OIDC_CLIENT_ID',
  defaultValue: 'pantry',
);
const String oidcRedirectUri = String.fromEnvironment(
  'PANTRY_OIDC_REDIRECT_URI',
  defaultValue: 'com.pantry.app:/oauthredirect',
);
const List<String> oidcScopes = ['openid', 'profile', 'email'];

void main() {
  runApp(const PantryApp());
}

class PantryApp extends StatelessWidget {
  const PantryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pantry',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D6A4F)),
        useMaterial3: true,
      ),
      home: const PantryHomePage(),
    );
  }
}

class PantryHomePage extends StatelessWidget {
  const PantryHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthenticatedHome();
  }
}

class AuthenticatedHome extends StatefulWidget {
  const AuthenticatedHome({super.key});

  @override
  State<AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<AuthenticatedHome> {
  static const _appAuth = FlutterAppAuth();

  String? _accessToken;
  String? _idToken;
  bool _isAuthenticating = false;
  String? _authError;

  Future<void> _signIn() async {
    setState(() {
      _isAuthenticating = true;
      _authError = null;
    });

    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          oidcClientId,
          oidcRedirectUri,
          discoveryUrl: '$oidcIssuer/.well-known/openid-configuration',
          scopes: oidcScopes,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _accessToken = result?.accessToken;
        _idToken = result?.idToken;
      });
    } catch (error) {
      setState(() {
        _authError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _signOut() {
    setState(() {
      _accessToken = null;
      _idToken = null;
      _authError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantry'),
        actions: [
          if (_accessToken != null)
            TextButton(
              onPressed: _signOut,
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: _accessToken == null
          ? _AuthGate(
              isAuthenticating: _isAuthenticating,
              errorMessage: _authError,
              onSignIn: _signIn,
            )
          : FutureBuilder<List<Item>>(
              future: fetchItems(_accessToken),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(message: snapshot.error.toString());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const _EmptyState();
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(item.name),
                        subtitle: Text(item.subtitle),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({
    required this.isAuthenticating,
    required this.errorMessage,
    required this.onSignIn,
  });

  final bool isAuthenticating;
  final String? errorMessage;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sign in to load pantry items.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'We will open the OIDC login page and return with an access token.',
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: isAuthenticating ? null : onSignIn,
            icon: const Icon(Icons.login),
            label: Text(isAuthenticating ? 'Signing in…' : 'Sign in'),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('API Base URL'),
              subtitle: Text(apiBaseUrl),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('OIDC Issuer'),
              subtitle: Text(oidcIssuer),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('OIDC Client ID'),
              subtitle: Text(oidcClientId),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No pantry items yet.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('Create an item in the web app to see it here.'),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('API Base URL'),
              subtitle: Text(apiBaseUrl),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load pantry items.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: const Text('API Base URL'),
              subtitle: Text(apiBaseUrl),
            ),
          ),
        ],
      ),
    );
  }
}

class Item {
  Item({
    required this.id,
    required this.name,
    required this.bestBefore,
    required this.contentAmount,
    required this.contentUnit,
    required this.packaging,
  });

  final String id;
  final String name;
  final String? bestBefore;
  final num? contentAmount;
  final String? contentUnit;
  final String? packaging;

  String get subtitle {
    final parts = <String>[];
    if (contentAmount != null && contentUnit != null) {
      parts.add('${contentAmount!} $contentUnit');
    }
    if (packaging != null && packaging!.isNotEmpty) {
      parts.add(packaging!);
    }
    if (bestBefore != null && bestBefore!.isNotEmpty) {
      parts.add('Best before $bestBefore');
    }
    return parts.isEmpty ? 'No details yet' : parts.join(' · ');
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? {};
    return Item(
      id: json['id']?.toString() ?? '',
      name: attributes['name']?.toString() ?? 'Unnamed item',
      bestBefore: attributes['best_before']?.toString(),
      contentAmount: attributes['content_amount'] as num?,
      contentUnit: attributes['content_unit']?.toString(),
      packaging: attributes['packaging']?.toString(),
    );
  }
}

Future<List<Item>> fetchItems(String? accessToken) async {
  final uri = Uri.parse('$apiBaseUrl/api/items');
  final headers = <String, String>{
    'accept': 'application/vnd.api+json',
  };
  if (accessToken != null && accessToken.isNotEmpty) {
    headers['authorization'] = 'Bearer $accessToken';
  }
  final response = await http.get(
    uri,
    headers: headers,
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('API error: ${response.statusCode} ${response.reasonPhrase}');
  }

  final payload = jsonDecode(response.body) as Map<String, dynamic>;
  final data = payload['data'];
  if (data is! List) {
    return [];
  }
  return data
      .whereType<Map<String, dynamic>>()
      .map(Item.fromJson)
      .toList();
}
