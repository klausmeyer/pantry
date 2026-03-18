import 'package:flutter/cupertino.dart';
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
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        DateTime selected = initialDate;
        return Container(
          height: 300,
          color: CupertinoColors.systemBackground,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _bestBeforeController.text = _formatDate(selected);
                    });
                  },
                  child: const Text('Done'),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  minimumDate: DateTime(now.year - 5),
                  maximumDate: DateTime(now.year + 10),
                  onDateTimeChanged: (value) {
                    selected = value;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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

  Future<void> _selectPackaging() async {
    final selected = await _showOptionsSheet(
      title: 'Packaging',
      options: _packagingOptions,
      current: _packaging,
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _packaging = selected;
    });
  }

  Future<void> _selectContentUnit() async {
    final selected = await _showOptionsSheet(
      title: 'Content unit',
      options: _contentUnitOptions,
      current: _contentUnit,
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _contentUnit = selected;
    });
  }

  Future<String?> _showOptionsSheet({
    required String title,
    required List<String> options,
    required String? current,
  }) {
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(option),
              isDefaultAction: option == current,
              child: Text(option),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final nameError = _validateName(_nameController.text);
    final dateError = _validateBestBefore(_bestBeforeController.text);
    if (nameError != null || dateError != null) {
      setState(() {
        _errorMessage = nameError ?? dateError;
      });
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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CupertinoField(
              label: 'Name',
              child: CupertinoTextField(
                controller: _nameController,
                placeholder: 'Name',
              ),
            ),
            const SizedBox(height: 12),
            _CupertinoField(
              label: 'Best before',
              child: CupertinoTextField(
                controller: _bestBeforeController,
                placeholder: 'YYYY-MM-DD',
                readOnly: true,
                onTap: _pickBestBeforeDate,
              ),
            ),
            const SizedBox(height: 12),
            _CupertinoField(
              label: 'Content amount',
              child: CupertinoTextField(
                controller: _contentAmountController,
                placeholder: 'e.g. 250',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(height: 12),
            _CupertinoField(
              label: 'Content unit',
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                color: CupertinoColors.systemGrey6,
                onPressed: _selectContentUnit,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_contentUnit ?? 'Select unit'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _CupertinoField(
              label: 'Packaging',
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                color: CupertinoColors.systemGrey6,
                onPressed: _selectPackaging,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_packaging ?? 'Select packaging'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _CupertinoField(
              label: 'Comment',
              child: CupertinoTextField(
                controller: _commentController,
                placeholder: 'Optional',
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Picture',
              style: CupertinoTheme.of(context)
                  .textTheme
                  .textStyle
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CupertinoButton(
                  onPressed: _isSaving
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  child: const Text('Select image'),
                ),
                CupertinoButton(
                  onPressed: _isSaving
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  child: const Text('Take photo'),
                ),
                if (_selectedImage != null || _pictureKey != null)
                  CupertinoButton(
                    onPressed: _isSaving ? null : _removeImage,
                    child: const Text('Remove'),
                  ),
              ],
            ),
            if (_selectedImage != null)
              Text('Selected: ${_selectedImage!.name}'),
            if (_selectedImage == null && _pictureKey != null)
              Text('Existing: ${_pictureKey!}'),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: CupertinoColors.systemRed),
              ),
            ],
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: _isSaving ? null : _submit,
              child: Text(_isSaving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CupertinoField extends StatelessWidget {
  const _CupertinoField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CupertinoTheme.of(context)
              .textTheme
              .textStyle
              .copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
