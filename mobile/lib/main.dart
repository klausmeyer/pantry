import 'package:flutter/material.dart';

const String apiBaseUrl = String.fromEnvironment(
  'PANTRY_API_BASE_URL',
  defaultValue: 'http://localhost:4000',
);

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantry'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mobile app setup complete.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Next steps: connect to the API and render pantry items.',
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('API Base URL'),
                subtitle: Text(apiBaseUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
