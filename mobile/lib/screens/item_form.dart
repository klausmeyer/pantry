import 'dart:io';

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
  static const double _prefixWidth = 110;
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

  String _normalizeBestBefore(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed
        .replaceAll(RegExp(r'[–—−]'), '-')
        .replaceAll(RegExp(r'\\s+'), '');
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
      final bestBefore = _normalizeBestBefore(_bestBeforeController.text);
      final normalizedBestBefore = bestBefore.isEmpty
          ? null
          : _formatDate(DateTime.parse(bestBefore));
      final draft = ItemDraft(
        name: _nameController.text.trim(),
        bestBefore: normalizedBestBefore,
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

  Future<void> _showImageActions() async {
    final action = await showCupertinoModalPopup<_ImageAction>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Picture'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(_ImageAction.gallery),
            child: const Text('Select image'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(_ImageAction.camera),
            child: const Text('Take photo'),
          ),
          if (_selectedImage != null || _pictureKey != null)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(_ImageAction.remove),
              isDestructiveAction: true,
              child: const Text('Remove'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );

    switch (action) {
      case _ImageAction.gallery:
        await _pickImage(ImageSource.gallery);
        break;
      case _ImageAction.camera:
        await _pickImage(ImageSource.camera);
        break;
      case _ImageAction.remove:
        _removeImage();
        break;
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(widget.title),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 6),
                CupertinoFormSection.insetGrouped(
                  header: const Text('Details'),
                  children: [
                    CupertinoTextFormFieldRow(
                      controller: _nameController,
                      placeholder: 'Name',
                      prefix: _formPrefix('Name'),
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _bestBeforeController,
                      placeholder: 'YYYY-MM-DD',
                      readOnly: true,
                      prefix: _formPrefix('Best before'),
                      onTap: _pickBestBeforeDate,
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _contentAmountController,
                      placeholder: 'e.g. 250',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      prefix: _formPrefix('Amount'),
                    ),
                    CupertinoFormRow(
                      prefix: _formPrefix('Unit'),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CupertinoButton(
                          padding:
                              const EdgeInsets.only(left: 6, top: 2, bottom: 2),
                          onPressed: _selectContentUnit,
                          child: Text(_contentUnit ?? 'Select'),
                        ),
                      ),
                    ),
                    CupertinoFormRow(
                      prefix: _formPrefix('Packaging'),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CupertinoButton(
                          padding:
                              const EdgeInsets.only(left: 6, top: 2, bottom: 2),
                          onPressed: _selectPackaging,
                          child: Text(_packaging ?? 'Select'),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 6, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _formPrefix('Comment'),
                          Expanded(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: CupertinoTextField(
                                controller: _commentController,
                                placeholder: 'Optional',
                                maxLines: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                CupertinoFormSection.insetGrouped(
                  header: const Text('Picture'),
                  children: [
                    CupertinoFormRow(
                      prefix: _formPrefix('Image'),
                      child: Row(
                        children: [
                          _ImagePreview(
                            filePath: _selectedImage?.path,
                            hasExisting: _pictureKey != null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedImage != null || _pictureKey != null
                                  ? 'Selected'
                                  : 'None',
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _isSaving ? null : _showImageActions,
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: CupertinoColors.systemRed),
                    ),
                  ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CupertinoButton.filled(
                    onPressed: _isSaving ? null : _submit,
                    child: Text(_isSaving ? 'Saving…' : 'Save'),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ImageAction { gallery, camera, remove }

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({this.filePath, required this.hasExisting});

  final String? filePath;
  final bool hasExisting;

  @override
  Widget build(BuildContext context) {
    final size = 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: filePath != null
          ? Image.file(
              File(filePath!),
              fit: BoxFit.cover,
            )
          : Icon(
              hasExisting
                  ? CupertinoIcons.photo_on_rectangle
                  : CupertinoIcons.photo,
              color: CupertinoColors.systemGrey,
              size: 22,
            ),
    );
  }
}

Widget _formPrefix(String label) {
  return SizedBox(
    width: _ItemFormPageState._prefixWidth,
    child: Text(label),
  );
}
