import 'dart:async';

import 'package:flutter/cupertino.dart';

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

  Future<void> _selectSortBy() async {
    final selected = await showCupertinoModalPopup<ItemSortBy>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Sort by'),
        actions: [
          for (final value in ItemSortBy.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(value),
              isDefaultAction: value == _sortBy,
              child: Text(_sortByLabel(value)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (selected == null) {
      return;
    }
    setState(() {
      _sortBy = selected;
      _itemsFuture = _loadItems();
    });
  }

  Future<void> _selectImageFilter() async {
    final selected = await showCupertinoModalPopup<ImageFilter>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filter'),
        actions: [
          for (final value in ImageFilter.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(value),
              isDefaultAction: value == _imageFilter,
              child: Text(_filterLabel(value)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (selected == null) {
      return;
    }
    setState(() {
      _imageFilter = selected;
      _itemsFuture = _loadItems();
    });
  }

  Widget _buildHeader(UserProfile? profile) {
    return Column(
      children: [
        _CupertinoCard(
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.person_circle,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.displayName ?? 'Signed in',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile?.email ?? 'Token active',
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CupertinoCard(
          child: Column(
            children: [
              Row(
                children: [
                Expanded(
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Search items',
                    onChanged: _onSearchChanged,
                    autocorrect: false,
                  ),
                ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _submitSearch,
                    child: const Icon(
                      CupertinoIcons.arrow_right_circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: CupertinoColors.systemGrey6,
                      onPressed: _selectSortBy,
                      child: Text('Sort: ${_sortByLabel(_sortBy)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: CupertinoColors.systemGrey6,
                      onPressed: _selectImageFilter,
                      child: Text(_filterLabel(_imageFilter)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CupertinoSlidingSegmentedControl<SortOrder>(
                groupValue: _sortOrder,
                onValueChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _sortOrder = value;
                    _itemsFuture = _loadItems();
                  });
                },
                children: const {
                  SortOrder.asc: Text('Ascending'),
                  SortOrder.desc: Text('Descending'),
                },
              ),
            ],
          ),
        ),
      ],
    );
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
      CupertinoPageRoute(
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
      CupertinoPageRoute(
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
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete item?'),
        content: Text('This will remove "${item.name}" from your pantry.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            isDestructiveAction: true,
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
      await _reloadItems();
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Delete failed'),
          content: Text(error.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _viewImage(Item item) async {
    if (item.pictureKey == null || item.pictureKey!.isEmpty) {
      return;
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(item.name),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
          child: SafeArea(
            child: FutureBuilder<String>(
              future: _withAccessToken(
                (token) => fetchPreviewUrl(token, item.pictureKey!),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Unable to load image: ${snapshot.error}'),
                    ),
                  );
                }
                final url = snapshot.data;
                if (url == null || url.isEmpty) {
                  return const Center(child: Text('No preview available.'));
                }
                return InteractiveViewer(
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Text('Image failed to load: $error');
                      },
                    ),
                  ),
                );
              },
            ),
          ),
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Pantry'),
        trailing: _authState == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _openCreate,
                    child: const Icon(CupertinoIcons.add),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _signOut,
                    child: const Icon(CupertinoIcons.square_arrow_right),
                  ),
                ],
              ),
      ),
      child: SafeArea(
        child: _isBootstrapping
            ? const Center(child: CupertinoActivityIndicator())
            : _authState == null
                ? AuthGate(
                    isAuthenticating: _isAuthenticating,
                    errorMessage: _authError,
                    onSignIn: _signIn,
                  )
                : FutureBuilder<List<Item>>(
                    future: _itemsFuture ?? _loadItems(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CupertinoActivityIndicator(),
                        );
                      }
                      if (snapshot.hasError) {
                        return ErrorState(
                          message: snapshot.error.toString(),
                          onRetry: _reloadItems,
                        );
                      }
                      final items = snapshot.data ?? [];
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.isEmpty ? 2 : items.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final profile = _authState?.profile;
                            return _buildHeader(profile);
                          }

                          if (items.isEmpty) {
                            return EmptyState(onCreate: _openCreate);
                          }
                          final item = items[index - 1];
                          return Stack(
                            children: [
                              _CupertinoCard(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    96,
                                    44,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(
                                          CupertinoIcons.cube_box,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
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
                                right: 6,
                                bottom: 6,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item.pictureKey != null &&
                                        item.pictureKey!.isNotEmpty)
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _viewImage(item),
                                        child: const Icon(
                                          CupertinoIcons.photo,
                                          size: 20,
                                        ),
                                      ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _openEdit(item),
                                      child: const Icon(
                                        CupertinoIcons.pencil,
                                        size: 20,
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _confirmDelete(item),
                                      child: const Icon(
                                        CupertinoIcons.delete_simple,
                                        size: 20,
                                      ),
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
      ),
    );
  }
}

class _CupertinoCard extends StatelessWidget {
  const _CupertinoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
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
