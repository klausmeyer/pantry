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
      child: Center(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Sign in to continue.',
                style:
                    CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Please sign in to view your pantry.',
                textAlign: TextAlign.center,
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
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
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
            'No items found.',
            style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
          ),
          const SizedBox(height: 12),
          const Text('Create your first item to get started.'),
          const SizedBox(height: 16),
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
