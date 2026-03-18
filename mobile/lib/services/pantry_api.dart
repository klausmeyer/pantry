import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../config.dart';
import '../models/item.dart';

Future<List<Item>> fetchItems(
  String? accessToken, {
  String sortBy = 'best_before',
  String sortOrder = 'asc',
  String? search,
  bool? hasImage,
}) async {
  final sort = sortOrder == 'desc' ? '-$sortBy' : sortBy;
  final params = <String, String>{'sort': sort};
  final trimmedSearch = search?.trim() ?? '';
  if (trimmedSearch.isNotEmpty) {
    params['q'] = trimmedSearch;
  }
  if (hasImage != null) {
    params['filter[has_image]'] = hasImage ? 'true' : 'false';
  }
  final uri = Uri.parse('$apiBaseUrl/api/items').replace(queryParameters: params);
  final headers = _jsonApiHeaders(accessToken: accessToken);
  final response = await http.get(uri, headers: headers);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('API error: ${response.statusCode} ${response.reasonPhrase}');
  }

  final payload =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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
  final prepared = await prepareUpload(file);
  final upload = await createUpload(
    accessToken,
    prepared.filename,
    prepared.contentType,
  );
  final bytes = prepared.bytes;
  await uploadToPresignedUrl(upload, bytes);
  return upload.pictureKey;
}

class PreparedUpload {
  PreparedUpload({
    required this.filename,
    required this.contentType,
    required this.bytes,
  });

  final String filename;
  final String contentType;
  final List<int> bytes;
}

Future<PreparedUpload> prepareUpload(XFile file) async {
  final filename = file.name.isNotEmpty ? file.name : 'upload.jpg';
  final contentType =
      file.mimeType ?? lookupMimeType(file.path) ?? 'application/octet-stream';
  final bytes = await file.readAsBytes();

  if (!shouldResize(contentType)) {
    return PreparedUpload(
      filename: filename,
      contentType: contentType,
      bytes: bytes,
    );
  }

  return resizeImageBytes(bytes, contentType, filename);
}

bool shouldResize(String contentType) {
  return contentType == 'image/jpeg' ||
      contentType == 'image/jpg' ||
      contentType == 'image/png' ||
      contentType == 'image/webp';
}

PreparedUpload resizeImageBytes(
  List<int> bytes,
  String contentType,
  String filename,
) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) {
    return PreparedUpload(
      filename: filename,
      contentType: contentType,
      bytes: bytes,
    );
  }

  const maxDimension = 1600;
  final width = image.width;
  final height = image.height;
  final scale = maxDimension / (width > height ? width : height);

  if (scale >= 1) {
    return PreparedUpload(
      filename: filename,
      contentType: contentType,
      bytes: bytes,
    );
  }

  final targetWidth = (width * scale).round().clamp(1, maxDimension);
  final targetHeight = (height * scale).round().clamp(1, maxDimension);
  final resized = img.copyResize(
    image,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.average,
  );

  if (contentType == 'image/png') {
    return PreparedUpload(
      filename: filename,
      contentType: contentType,
      bytes: img.encodePng(resized),
    );
  }
  if (contentType == 'image/webp') {
    final jpegName = _replaceExtension(filename, 'jpg');
    return PreparedUpload(
      filename: jpegName,
      contentType: 'image/jpeg',
      bytes: img.encodeJpg(resized, quality: 85),
    );
  }
  return PreparedUpload(
    filename: filename,
    contentType: contentType,
    bytes: img.encodeJpg(resized, quality: 85),
  );
}

String _replaceExtension(String filename, String newExtension) {
  final dotIndex = filename.lastIndexOf('.');
  if (dotIndex == -1) {
    return '$filename.$newExtension';
  }
  return '${filename.substring(0, dotIndex)}.$newExtension';
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
    throw Exception(
      'Upload init failed: ${response.statusCode} ${response.reasonPhrase}',
    );
  }

  final payload =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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

  final payload =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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
  final payload =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  final data = payload['data'];
  if (data is! Map<String, dynamic>) {
    throw Exception('Unexpected API response.');
  }
  return Item.fromJson(data);
}
