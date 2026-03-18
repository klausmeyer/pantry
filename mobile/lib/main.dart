import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

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
  final _authService = AuthService();

  AuthState? _authState;
  bool _isBootstrapping = true;
  bool _isAuthenticating = false;
  String? _authError;
  Timer? _refreshTimer;
  Future<List<Item>>? _itemsFuture;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final state = await _authService.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _authState = state;
      _isBootstrapping = false;
      _itemsFuture = state == null ? null : _loadItems();
    });
    _scheduleRefresh();
  }

  Future<void> _signIn() async {
    setState(() {
      _isAuthenticating = true;
      _authError = null;
    });

    try {
      setState(() {
        _authState = null;
      });
      final state = await _authService.signIn();
      if (!mounted) {
        return;
      }
      setState(() {
        _authState = state;
        _itemsFuture = _loadItems();
      });
      _scheduleRefresh();
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
    _refreshTimer?.cancel();
    _authService.clear();
    setState(() {
      _authState = null;
      _authError = null;
      _itemsFuture = null;
    });
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    final state = _authState;
    if (state == null) {
      return;
    }
    final expiresAt = state.expiresAt;
    if (expiresAt == null) {
      return;
    }
    final now = DateTime.now();
    final refreshAt = expiresAt.subtract(const Duration(minutes: 1));
    final delay = refreshAt.isAfter(now) ? refreshAt.difference(now) : Duration.zero;
    _refreshTimer = Timer(delay, _refreshToken);
  }

  Future<void> _refreshToken() async {
    final state = _authState;
    if (state == null || state.refreshToken == null) {
      return;
    }

    try {
      final refreshed = await _authService.refresh(state.refreshToken!);
      if (!mounted) {
        return;
      }
      setState(() {
        _authState = refreshed;
        _authError = null;
      });
      _scheduleRefresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _authState = null;
        _authError = 'Session expired. Please sign in again.';
        _itemsFuture = null;
      });
    }
  }

  Future<List<Item>> _loadItems() async {
    final state = await _authService.load();
    if (mounted) {
      setState(() {
        _authState = state;
      });
    }
    final accessToken = state?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Missing access token. Please sign in again.');
    }
    return fetchItems(accessToken);
  }

  Future<T> _withAccessToken<T>(Future<T> Function(String token) action) async {
    final state = await _authService.load();
    if (mounted) {
      setState(() {
        _authState = state;
      });
    }
    final accessToken = state?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Missing access token. Please sign in again.');
    }
    return action(accessToken);
  }

  Future<void> _reloadItems() async {
    setState(() {
      _itemsFuture = _loadItems();
    });
  }

  Future<void> _openCreate() async {
    final result = await Navigator.of(context).push<Item>(
      MaterialPageRoute(
        builder: (context) => ItemFormPage(
          title: 'Create item',
          initial: null,
          onSave: (draft) => _withAccessToken(
            (token) => createItem(token, draft),
          ),
          onUploadImage: (file) => _withAccessToken(
            (token) => uploadImage(token, file),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      await _reloadItems();
    }
  }

  Future<void> _openEdit(Item item) async {
    final result = await Navigator.of(context).push<Item>(
      MaterialPageRoute(
        builder: (context) => ItemFormPage(
          title: 'Edit item',
          initial: item,
          onSave: (draft) => _withAccessToken(
            (token) => updateItem(token, item.id, draft),
          ),
          onUploadImage: (file) => _withAccessToken(
            (token) => uploadImage(token, file),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      await _reloadItems();
    }
  }

  Future<void> _confirmDelete(Item item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('This will remove "${item.name}" from your pantry.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _withAccessToken((token) => deleteItem(token, item.id));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${item.name}.')),
      );
      await _reloadItems();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  Future<void> _viewImage(Item item) async {
    if (item.pictureKey == null || item.pictureKey!.isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.name),
          content: FutureBuilder<String>(
            future: _withAccessToken(
              (token) => fetchPreviewUrl(token, item.pictureKey!),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text('Unable to load image: ${snapshot.error}');
              }
              final url = snapshot.data;
              if (url == null || url.isEmpty) {
                return const Text('No preview available.');
              }
              return Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Text('Image failed to load: $error');
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantry'),
        actions: [
          if (_authState != null)
            IconButton(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              tooltip: 'Create item',
            ),
          if (_authState != null)
            TextButton(
              onPressed: _signOut,
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: _isBootstrapping
          ? const Center(child: CircularProgressIndicator())
          : _authState == null
          ? _AuthGate(
              isAuthenticating: _isAuthenticating,
              errorMessage: _authError,
              onSignIn: _signIn,
            )
          : FutureBuilder<List<Item>>(
              future: _itemsFuture ?? _loadItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: snapshot.error.toString(),
                    onRetry: _reloadItems,
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return _EmptyState(onCreate: _openCreate);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final profile = _authState?.profile;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.account_circle_outlined),
                          title: Text(profile?.displayName ?? 'Signed in'),
                          subtitle: Text(profile?.email ?? 'Token active'),
                        ),
                      );
                    }
                    final item = items[index - 1];
                    return Stack(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 96, 44),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Icon(Icons.inventory_2_outlined),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(item.subtitle),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (item.bestBefore != null &&
                            item.bestBefore!.isNotEmpty)
                          Positioned(
                            right: 12,
                            top: 8,
                            child: BestBeforeBadge(
                              bestBefore: item.bestBefore!,
                            ),
                          ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.pictureKey != null &&
                                  item.pictureKey!.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.image_outlined),
                                  tooltip: 'View image',
                                  onPressed: () => _viewImage(item),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Edit',
                                onPressed: () => _openEdit(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(item),
                              ),
                            ],
                          ),
                        ),
                      ],
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
  const _EmptyState({required this.onCreate});

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
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('Create your first item to get started.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create item'),
          ),
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
  const _ErrorState({required this.message, required this.onRetry});

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
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
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
    required this.comment,
    required this.pictureKey,
  });

  final String id;
  final String name;
  final String? bestBefore;
  final num? contentAmount;
  final String? contentUnit;
  final String? packaging;
  final String? comment;
  final String? pictureKey;

  String get subtitle {
    final parts = <String>[];
    if (contentAmount != null && contentUnit != null) {
      parts.add('${contentAmount!} $contentUnit');
    }
    if (packaging != null && packaging!.isNotEmpty) {
      parts.add(packaging!);
    }
    if (comment != null && comment!.isNotEmpty) {
      parts.add(comment!);
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
      comment: attributes['comment']?.toString(),
      pictureKey: attributes['picture_key']?.toString(),
    );
  }
}

class ItemDraft {
  ItemDraft({
    required this.name,
    required this.bestBefore,
    required this.contentAmount,
    required this.contentUnit,
    required this.packaging,
    required this.comment,
    required this.pictureKey,
    required this.clearPicture,
  });

  final String name;
  final String? bestBefore;
  final num? contentAmount;
  final String? contentUnit;
  final String? packaging;
  final String? comment;
  final String? pictureKey;
  final bool clearPicture;

  Map<String, dynamic> toAttributes() {
    final attributes = <String, dynamic>{
      'name': name,
    };
    if (bestBefore != null && bestBefore!.isNotEmpty) {
      attributes['best_before'] = bestBefore;
    }
    if (contentAmount != null) {
      attributes['content_amount'] = contentAmount;
    }
    if (contentUnit != null && contentUnit!.isNotEmpty) {
      attributes['content_unit'] = contentUnit;
    }
    if (packaging != null && packaging!.isNotEmpty) {
      attributes['packaging'] = packaging;
    }
    if (comment != null && comment!.isNotEmpty) {
      attributes['comment'] = comment;
    }
    if (pictureKey != null && pictureKey!.isNotEmpty) {
      attributes['picture_key'] = pictureKey;
    } else if (clearPicture) {
      attributes['picture_key'] = null;
    }
    return attributes;
  }
}

typedef ItemSaveHandler = Future<Item> Function(ItemDraft draft);
typedef ImageUploadHandler = Future<String> Function(XFile file);

class ItemFormPage extends StatefulWidget {
  const ItemFormPage({
    super.key,
    required this.title,
    required this.initial,
    required this.onSave,
    required this.onUploadImage,
  });

  final String title;
  final Item? initial;
  final ItemSaveHandler onSave;
  final ImageUploadHandler onUploadImage;

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bestBeforeController = TextEditingController();
  final _contentAmountController = TextEditingController();
  final _commentController = TextEditingController();
  String? _packaging;
  String? _contentUnit;
  String? _pictureKey;
  bool _clearPicture = false;
  XFile? _selectedImage;
  bool _isSaving = false;
  String? _errorMessage;

  static const _packagingOptions = [
    'bottle',
    'can',
    'box',
    'bag',
    'jar',
    'package',
    'other',
  ];
  static const _contentUnitOptions = [
    'grams',
    'ml',
    'l',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    if (item != null) {
      _nameController.text = item.name;
      _bestBeforeController.text = item.bestBefore ?? '';
      _contentAmountController.text =
          item.contentAmount != null ? item.contentAmount.toString() : '';
      _commentController.text = item.comment ?? '';
      _packaging = item.packaging;
      _contentUnit = item.contentUnit;
      _pictureKey = item.pictureKey;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bestBeforeController.dispose();
    _contentAmountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required.';
    }
    return null;
  }

  String? _validateBestBefore(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Use YYYY-MM-DD.';
    }
    return null;
  }

  Future<void> _pickBestBeforeDate() async {
    final now = DateTime.now();
    final initialDate = _parseBestBeforeDate() ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _bestBeforeController.text = _formatDate(picked);
    });
  }

  DateTime? _parseBestBeforeDate() {
    final text = _bestBeforeController.text.trim();
    if (text.isEmpty) {
      return null;
    }
    final parts = text.split('-');
    if (parts.length != 3) {
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final contentAmount = _contentAmountController.text.trim().isEmpty
          ? null
          : num.tryParse(_contentAmountController.text.trim());
      var pictureKey = _pictureKey;
      var clearPicture = _clearPicture;
      if (_selectedImage != null) {
        pictureKey = await widget.onUploadImage(_selectedImage!);
        clearPicture = false;
      }
      final draft = ItemDraft(
        name: _nameController.text.trim(),
        bestBefore: _bestBeforeController.text.trim().isEmpty
            ? null
            : _bestBeforeController.text.trim(),
        contentAmount: contentAmount,
        contentUnit: _contentUnit?.trim().isEmpty ?? true ? null : _contentUnit,
        packaging: _packaging?.trim().isEmpty ?? true ? null : _packaging,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        pictureKey: pictureKey,
        clearPicture: clearPicture,
      );
      final saved = await widget.onSave(draft);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }
    setState(() {
      _selectedImage = image;
      _clearPicture = false;
    });
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _pictureKey = null;
      _clearPicture = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bestBeforeController,
                decoration: const InputDecoration(
                  labelText: 'Best before (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: _pickBestBeforeDate,
                validator: _validateBestBefore,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentAmountController,
                decoration: const InputDecoration(
                  labelText: 'Content amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _contentUnit,
                decoration: const InputDecoration(
                  labelText: 'Content unit',
                  border: OutlineInputBorder(),
                ),
                items: _contentUnitOptions
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _contentUnit = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _packaging,
                decoration: const InputDecoration(
                  labelText: 'Packaging',
                  border: OutlineInputBorder(),
                ),
                items: _packagingOptions
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _packaging = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Picture',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Select image'),
                  ),
                  const SizedBox(width: 12),
                  if (_selectedImage != null || _pictureKey != null)
                    TextButton(
                      onPressed: _isSaving ? null : _removeImage,
                      child: const Text('Remove'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_selectedImage != null)
                Text('Selected: ${_selectedImage!.name}'),
              if (_selectedImage == null && _pictureKey != null)
                Text('Existing: ${_pictureKey!}'),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: Text(_isSaving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BestBeforeBadge extends StatelessWidget {
  const BestBeforeBadge({super.key, required this.bestBefore});

  final String bestBefore;

  @override
  Widget build(BuildContext context) {
    final delta = bestBeforeDeltaDays(bestBefore);
    final label = bestBeforeLabel(bestBefore);
    final colors = bestBeforeColors(context, delta);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

int bestBeforeDeltaDays(String bestBefore) {
  final today = _startOfUtcDate(DateTime.now());
  final target = _startOfUtcDate(DateTime.parse('${bestBefore}T00:00:00Z'));
  const msPerDay = 24 * 60 * 60 * 1000;
  return ((target.millisecondsSinceEpoch - today.millisecondsSinceEpoch) / msPerDay)
      .round();
}

String bestBeforeLabel(String bestBefore) {
  final delta = bestBeforeDeltaDays(bestBefore);
  final dayWord = _dayWord(delta.abs());
  if (delta < 0) {
    final days = delta.abs();
    return '$days $dayWord overdue';
  }
  if (delta == 0) {
    return 'Expires today';
  }
  return '$delta ${_dayWord(delta)} left';
}

_BestBeforeColors bestBeforeColors(BuildContext context, int delta) {
  if (delta < 0) {
    return _BestBeforeColors(
      background: Colors.red.shade100,
      foreground: Colors.red.shade900,
    );
  }
  if (delta <= 14) {
    return _BestBeforeColors(
      background: Colors.orange.shade100,
      foreground: Colors.orange.shade900,
    );
  }
  return _BestBeforeColors(
    background: Colors.green.shade100,
    foreground: Colors.green.shade900,
  );
}

String _dayWord(int count) => count == 1 ? 'day' : 'days';

DateTime _startOfUtcDate(DateTime date) {
  return DateTime.utc(date.year, date.month, date.day);
}

class _BestBeforeColors {
  const _BestBeforeColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

class AuthState {
  AuthState({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.profile,
  });

  final String? accessToken;
  final String? idToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final UserProfile? profile;

  bool get isExpired {
    if (expiresAt == null) {
      return false;
    }
    return DateTime.now().isAfter(expiresAt!);
  }
}

class UserProfile {
  UserProfile({required this.displayName, required this.email});

  final String? displayName;
  final String? email;

  factory UserProfile.fromIdToken(String idToken) {
    final parts = idToken.split('.');
    if (parts.length < 2) {
      return UserProfile(displayName: null, email: null);
    }
    final payload = _decodeBase64Url(parts[1]);
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final name =
        data['name']?.toString() ?? data['preferred_username']?.toString();
    final email = data['email']?.toString();
    return UserProfile(displayName: name, email: email);
  }
}

String _decodeBase64Url(String input) {
  var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
  while (normalized.length % 4 != 0) {
    normalized += '=';
  }
  return utf8.decode(base64Decode(normalized));
}

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _appAuth = FlutterAppAuth();

  static const _accessTokenKey = 'pantry.access_token';
  static const _idTokenKey = 'pantry.id_token';
  static const _refreshTokenKey = 'pantry.refresh_token';
  static const _expiresAtKey = 'pantry.expires_at';

  Future<AuthState?> load() async {
    final values = await Future.wait<String?>([
      _storage.read(key: _accessTokenKey),
      _storage.read(key: _idTokenKey),
      _storage.read(key: _refreshTokenKey),
      _storage.read(key: _expiresAtKey),
    ]);

    final accessToken = values[0];
    final idToken = values[1];
    final refreshToken = values[2];
    final expiresAtRaw = values[3];
    final expiresAt = expiresAtRaw != null ? DateTime.tryParse(expiresAtRaw) : null;

    if (accessToken == null && refreshToken == null) {
      return null;
    }

    var state = AuthState(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      profile: idToken != null ? UserProfile.fromIdToken(idToken) : null,
    );

    if (state.isExpired && refreshToken != null) {
      state = await refresh(refreshToken);
    }

    return state;
  }

  Future<AuthState> signIn() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        oidcClientId,
        oidcRedirectUri,
        discoveryUrl: '$oidcIssuer/.well-known/openid-configuration',
        scopes: oidcScopes,
      ),
    );

    final state = AuthState(
      accessToken: result?.accessToken,
      idToken: result?.idToken,
      refreshToken: result?.refreshToken,
      expiresAt: result?.accessTokenExpirationDateTime,
      profile: result?.idToken != null
          ? UserProfile.fromIdToken(result!.idToken!)
          : null,
    );

    await _persist(state);
    return state;
  }

  Future<AuthState> refresh(String refreshToken) async {
    final response = await _appAuth.token(
      TokenRequest(
        oidcClientId,
        oidcRedirectUri,
        discoveryUrl: '$oidcIssuer/.well-known/openid-configuration',
        refreshToken: refreshToken,
        scopes: oidcScopes,
      ),
    );

    final state = AuthState(
      accessToken: response?.accessToken,
      idToken: response?.idToken,
      refreshToken: response?.refreshToken ?? refreshToken,
      expiresAt: response?.accessTokenExpirationDateTime,
      profile: response?.idToken != null
          ? UserProfile.fromIdToken(response!.idToken!)
          : null,
    );

    await _persist(state);
    return state;
  }

  Future<void> clear() async {
    await Future.wait<void>([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _idTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiresAtKey),
    ]);
  }

  Future<void> _persist(AuthState state) async {
    await Future.wait<void>([
      if (state.accessToken != null)
        _storage.write(key: _accessTokenKey, value: state.accessToken),
      if (state.idToken != null)
        _storage.write(key: _idTokenKey, value: state.idToken),
      if (state.refreshToken != null)
        _storage.write(key: _refreshTokenKey, value: state.refreshToken),
      if (state.expiresAt != null)
        _storage.write(key: _expiresAtKey, value: state.expiresAt!.toIso8601String()),
    ]);
  }

  Future<String?> getValidAccessToken() async {
    final state = await load();
    return state?.accessToken;
  }
}

Future<List<Item>> fetchItems(String? accessToken) async {
  final uri = Uri.parse('$apiBaseUrl/api/items');
  final headers = _jsonApiHeaders(accessToken: accessToken);
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

class UploadInfo {
  UploadInfo({
    required this.pictureKey,
    required this.uploadUrl,
    required this.headers,
  });

  final String pictureKey;
  final String uploadUrl;
  final Map<String, String> headers;
}

Future<Item> createItem(String accessToken, ItemDraft draft) async {
  final uri = Uri.parse('$apiBaseUrl/api/items');
  final body = jsonEncode({
    'data': {
      'type': 'items',
      'attributes': draft.toAttributes(),
    },
  });
  final response = await http.post(
    uri,
    headers: _jsonApiHeaders(accessToken: accessToken, includeContentType: true),
    body: body,
  );
  return _parseItemResponse(response);
}

Future<Item> updateItem(String accessToken, String id, ItemDraft draft) async {
  final uri = Uri.parse('$apiBaseUrl/api/items/$id');
  final body = jsonEncode({
    'data': {
      'type': 'items',
      'id': id,
      'attributes': draft.toAttributes(),
    },
  });
  final response = await http.patch(
    uri,
    headers: _jsonApiHeaders(accessToken: accessToken, includeContentType: true),
    body: body,
  );
  return _parseItemResponse(response);
}

Future<void> deleteItem(String accessToken, String id) async {
  final uri = Uri.parse('$apiBaseUrl/api/items/$id');
  final response = await http.delete(
    uri,
    headers: _jsonApiHeaders(accessToken: accessToken),
  );
  if (response.statusCode != 204) {
    throw Exception('API error: ${response.statusCode} ${response.reasonPhrase}');
  }
}

Future<String> uploadImage(String accessToken, XFile file) async {
  final filename = file.name.isNotEmpty ? file.name : 'upload.jpg';
  final contentType =
      file.mimeType ?? lookupMimeType(file.path) ?? 'image/jpeg';
  final upload = await createUpload(accessToken, filename, contentType);
  final bytes = await file.readAsBytes();
  await uploadToPresignedUrl(upload, bytes);
  return upload.pictureKey;
}

Future<UploadInfo> createUpload(
  String accessToken,
  String filename,
  String contentType,
) async {
  final uri = Uri.parse('$apiBaseUrl/api/uploads');
  final response = await http.post(
    uri,
    headers: _jsonApiHeaders(
      accessToken: accessToken,
      includeContentType: false,
      overrideContentType: 'application/json',
    ),
    body: jsonEncode({
      'filename': filename,
      'content_type': contentType,
    }),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Upload init failed: ${response.statusCode} ${response.reasonPhrase}');
  }

  final payload = jsonDecode(response.body) as Map<String, dynamic>;
  final data = payload['data'] as Map<String, dynamic>? ?? {};
  final attributes = data['attributes'] as Map<String, dynamic>? ?? {};
  final headersRaw = attributes['headers'] as Map<String, dynamic>? ?? {};
  final headers = headersRaw.map(
    (key, value) => MapEntry(key.toString(), value.toString()),
  );

  return UploadInfo(
    pictureKey: attributes['picture_key']?.toString() ?? '',
    uploadUrl: attributes['upload_url']?.toString() ?? '',
    headers: headers,
  );
}

Future<void> uploadToPresignedUrl(UploadInfo upload, List<int> bytes) async {
  final response = await http.put(
    Uri.parse(upload.uploadUrl),
    headers: upload.headers,
    body: bytes,
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Upload failed: ${response.statusCode} ${response.reasonPhrase}');
  }
}

Future<String> fetchPreviewUrl(String accessToken, String pictureKey) async {
  final uri = Uri.parse('$apiBaseUrl/api/uploads/preview')
      .replace(queryParameters: {'picture_key': pictureKey});
  final response = await http.get(
    uri,
    headers: _jsonApiHeaders(accessToken: accessToken),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Preview failed: ${response.statusCode} ${response.reasonPhrase}',
    );
  }

  final payload = jsonDecode(response.body) as Map<String, dynamic>;
  final data = payload['data'] as Map<String, dynamic>? ?? {};
  final attributes = data['attributes'] as Map<String, dynamic>? ?? {};
  return attributes['preview_url']?.toString() ?? '';
}

Map<String, String> _jsonApiHeaders({
  String? accessToken,
  bool includeContentType = false,
  String? overrideContentType,
}) {
  final headers = <String, String>{
    'accept': 'application/vnd.api+json',
  };
  if (overrideContentType != null) {
    headers['content-type'] = overrideContentType;
  } else if (includeContentType) {
    headers['content-type'] = 'application/vnd.api+json';
  }
  if (accessToken != null && accessToken.isNotEmpty) {
    headers['authorization'] = 'Bearer $accessToken';
  }
  return headers;
}

Item _parseItemResponse(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('API error: ${response.statusCode} ${response.reasonPhrase}');
  }
  final payload = jsonDecode(response.body) as Map<String, dynamic>;
  final data = payload['data'];
  if (data is! Map<String, dynamic>) {
    throw Exception('Unexpected API response.');
  }
  return Item.fromJson(data);
}
