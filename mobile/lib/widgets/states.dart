import 'package:flutter/cupertino.dart';

import '../config.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
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
            style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
          ),
          const SizedBox(height: 12),
          const Text(
            'We will open the OIDC login page and return with an access token.',
          ),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: isAuthenticating ? null : onSignIn,
            child: Text(isAuthenticating ? 'Signing in…' : 'Sign in'),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          ],
          const SizedBox(height: 24),
          _InfoTile(
            title: 'API Base URL',
            subtitle: apiBaseUrl,
            icon: CupertinoIcons.cloud,
          ),
          const SizedBox(height: 12),
          _InfoTile(
            title: 'OIDC Issuer',
            subtitle: oidcIssuer,
            icon: CupertinoIcons.check_mark_circled,
          ),
          const SizedBox(height: 12),
          _InfoTile(
            title: 'OIDC Client ID',
            subtitle: oidcClientId,
            icon: CupertinoIcons.person_crop_rectangle,
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No pantry items yet.',
            style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
          ),
          const SizedBox(height: 12),
          const Text('Create your first item to get started.'),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: onCreate,
            child: const Text('Create item'),
          ),
          const SizedBox(height: 20),
          _InfoTile(
            title: 'API Base URL',
            subtitle: apiBaseUrl,
            icon: CupertinoIcons.cloud,
          ),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load pantry items.',
            style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 16),
          CupertinoButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
          const SizedBox(height: 20),
          _InfoTile(
            title: 'API Base URL',
            subtitle: apiBaseUrl,
            icon: CupertinoIcons.cloud,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: CupertinoColors.systemGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
