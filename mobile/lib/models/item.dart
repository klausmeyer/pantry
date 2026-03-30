class Item {
  Item({
    required this.id,
    required this.inventoryTag,
    required this.name,
    required this.bestBefore,
    required this.contentAmount,
    required this.contentUnit,
    required this.packaging,
    required this.comment,
    required this.pictureKey,
  });

  final String id;
  final String inventoryTag;
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
      inventoryTag: attributes['inventory_tag']?.toString() ?? '',
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
