import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/item.dart';

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
    final regex = RegExp(r'^\\d{4}-\\d{2}-\\d{2}$');
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

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
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
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _takePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Take photo'),
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
