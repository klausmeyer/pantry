import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth.dart';
import '../models/item.dart';
import '../services/auth_service.dart';
import '../services/pantry_api.dart';
import '../widgets/best_before_badge.dart';
import '../widgets/states.dart';
import 'item_form.dart';

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
  final _searchController = TextEditingController();

  AuthState? _authState;
  bool _isBootstrapping = true;
  bool _isAuthenticating = false;
  String? _authError;
  Timer? _refreshTimer;
  Future<List<Item>>? _itemsFuture;
  ItemSortBy _sortBy = ItemSortBy.bestBefore;
  SortOrder _sortOrder = SortOrder.asc;
  ImageFilter _imageFilter = ImageFilter.all;
  String _searchTerm = '';

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
    return fetchItems(
      accessToken,
      sortBy: _sortByParam(_sortBy),
      sortOrder: _sortOrder == SortOrder.desc ? 'desc' : 'asc',
      search: _searchTerm,
      hasImage: _hasImageFilter(_imageFilter),
    );
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

  void _onSearchChanged(String value) {
    setState(() {
      _searchTerm = value;
    });
  }

  void _submitSearch() {
    setState(() {
      _searchTerm = _searchController.text.trim();
      _itemsFuture = _loadItems();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchTerm = '';
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
    _searchController.dispose();
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
              ? AuthGate(
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
                      return ErrorState(
                        message: snapshot.error.toString(),
                        onRetry: _reloadItems,
                      );
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return EmptyState(onCreate: _openCreate);
                    }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final profile = _authState?.profile;
                      return Column(
                        children: [
                          Card(
                            child: ListTile(
                              leading:
                                  const Icon(Icons.account_circle_outlined),
                              title: Text(profile?.displayName ?? 'Signed in'),
                              subtitle: Text(profile?.email ?? 'Token active'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _searchController,
                                          decoration: InputDecoration(
                                            labelText: 'Search',
                                            hintText: 'Search items',
                                            prefixIcon: const Icon(
                                              Icons.search_outlined,
                                            ),
                                            suffixIcon: _searchTerm.isEmpty
                                                ? null
                                                : IconButton(
                                                    onPressed: _clearSearch,
                                                    icon: const Icon(
                                                      Icons.close_rounded,
                                                    ),
                                                  ),
                                            border: const OutlineInputBorder(),
                                          ),
                                          onChanged: _onSearchChanged,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: _submitSearch,
                                        icon: const Icon(Icons.send_outlined),
                                        tooltip: 'Search',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<ItemSortBy>(
                                              value: _sortBy,
                                              decoration: const InputDecoration(
                                                labelText: 'Sort by',
                                                border: OutlineInputBorder(),
                                              ),
                                              items: ItemSortBy.values
                                                  .map(
                                                    (value) =>
                                                        DropdownMenuItem(
                                                      value: value,
                                                      child: Text(
                                                        _sortByLabel(value),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (value) {
                                                if (value == null) {
                                                  return;
                                                }
                                                setState(() {
                                                  _sortBy = value;
                                                  _itemsFuture = _loadItems();
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: DropdownButtonFormField<
                                                ImageFilter>(
                                              value: _imageFilter,
                                              decoration: const InputDecoration(
                                                labelText: 'Filter',
                                                border: OutlineInputBorder(),
                                              ),
                                              items: ImageFilter.values
                                                  .map(
                                                    (value) =>
                                                        DropdownMenuItem(
                                                      value: value,
                                                      child: Text(
                                                        _filterLabel(value),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (value) {
                                                if (value == null) {
                                                  return;
                                                }
                                                setState(() {
                                                  _imageFilter = value;
                                                  _itemsFuture = _loadItems();
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _sortOrder =
                                                  _sortOrder == SortOrder.asc
                                                      ? SortOrder.desc
                                                      : SortOrder.asc;
                                              _itemsFuture = _loadItems();
                                            });
                                          },
                                          icon: Icon(
                                            _sortOrder == SortOrder.asc
                                                ? Icons.arrow_upward
                                                : Icons.arrow_downward,
                                          ),
                                          label: Text(
                                            _sortOrder == SortOrder.asc
                                                ? 'Ascending'
                                                : 'Descending',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

enum ItemSortBy {
  name,
  bestBefore,
  createdAt,
  updatedAt,
}

enum SortOrder {
  asc,
  desc,
}

enum ImageFilter {
  all,
  hasImage,
  noImage,
}

String _sortByParam(ItemSortBy sortBy) {
  switch (sortBy) {
    case ItemSortBy.name:
      return 'name';
    case ItemSortBy.bestBefore:
      return 'best_before';
    case ItemSortBy.createdAt:
      return 'created_at';
    case ItemSortBy.updatedAt:
      return 'updated_at';
  }
}

String _sortByLabel(ItemSortBy sortBy) {
  switch (sortBy) {
    case ItemSortBy.name:
      return 'Name';
    case ItemSortBy.bestBefore:
      return 'EXP';
    case ItemSortBy.createdAt:
      return 'Created';
    case ItemSortBy.updatedAt:
      return 'Updated';
  }
}

String _filterLabel(ImageFilter filter) {
  switch (filter) {
    case ImageFilter.all:
      return 'All items';
    case ImageFilter.hasImage:
      return 'With image';
    case ImageFilter.noImage:
      return 'No image';
  }
}

bool? _hasImageFilter(ImageFilter filter) {
  final value = filter;
  if (value == ImageFilter.hasImage) {
    return true;
  }
  if (value == ImageFilter.noImage) {
    return false;
  }
  return null;
}
