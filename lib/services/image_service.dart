import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class _CompressRequest {
  final Uint8List rawBytes;
  final int maxLongEdge;
  final int jpegQuality;

  const _CompressRequest({
    required this.rawBytes,
    required this.maxLongEdge,
    required this.jpegQuality,
  });
}

Uint8List _compressImageInIsolate(_CompressRequest req) {
  final decoded = img.decodeImage(req.rawBytes);
  if (decoded == null) return req.rawBytes;

  img.Image target = decoded;
  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longest > req.maxLongEdge) {
    if (decoded.width >= decoded.height) {
      target = img.copyResize(
        decoded,
        width: req.maxLongEdge,
        interpolation: img.Interpolation.linear,
      );
    } else {
      target = img.copyResize(
        decoded,
        height: req.maxLongEdge,
        interpolation: img.Interpolation.linear,
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(target, quality: req.jpegQuality));
}

class ImageService {
  static const _uuid = Uuid();

  static Future<Directory> themesRootDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'themes'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> themeAssetDir(String themeId) async {
    final root = await themesRootDir();
    final dir = Directory(p.join(root.path, themeId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Processes and saves a cropped theme image according to the spec:
  /// - [keepLossless] == true: saves original cropped bytes losslessly (.png)
  /// - [keepLossless] == false:
  ///   - Global background ([isGlobalBg] == true): max long edge 2560px, JPEG 90%
  ///   - Category card background ([isGlobalBg] == false): max long edge 1280px, JPEG 85%
  static Future<String> saveThemeImage({
    required String themeId,
    required Uint8List croppedBytes,
    required bool isGlobalBg,
    required bool keepLossless,
    String? prefix,
  }) async {
    final dir = await themeAssetDir(themeId);
    final tag = prefix ?? (isGlobalBg ? 'global_bg' : 'cat_bg');
    final uid = _uuid.v4().substring(0, 8);

    if (keepLossless) {
      final outPath = p.join(dir.path, '${tag}_$uid.png');
      await File(outPath).writeAsBytes(croppedBytes, flush: true);
      return outPath;
    }

    final compressed = await compute(
      _compressImageInIsolate,
      _CompressRequest(
        rawBytes: croppedBytes,
        maxLongEdge: isGlobalBg ? 2560 : 1280,
        jpegQuality: isGlobalBg ? 90 : 85,
      ),
    );
    final outPath = p.join(dir.path, '${tag}_$uid.jpg');
    await File(outPath).writeAsBytes(compressed, flush: true);
    return outPath;
  }
}
