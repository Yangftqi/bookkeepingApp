import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

class ImageCropperPage extends StatefulWidget {
  final Uint8List imageBytes;
  final double? initialAspectRatio;
  final String title;
  final bool allowFreeRatio;

  const ImageCropperPage({
    super.key,
    required this.imageBytes,
    this.initialAspectRatio,
    required this.title,
    this.allowFreeRatio = true,
  });

  @override
  State<ImageCropperPage> createState() => _ImageCropperPageState();
}

class _ImageCropperPageState extends State<ImageCropperPage> {
  final CropController _controller = CropController();
  double? _aspectRatio;
  bool _cropping = false;

  @override
  void initState() {
    super.initState();
    _aspectRatio = widget.initialAspectRatio;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.allowFreeRatio)
            TextButton(
              onPressed: () {
                setState(() {
                  _aspectRatio =
                      _aspectRatio == null ? widget.initialAspectRatio : null;
                });
                _controller.aspectRatio = _aspectRatio;
              },
              child: Text(_aspectRatio == null ? '切回推荐比例' : '自由比例'),
            ),
          FilledButton(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _controller.crop();
                  },
            child: _cropping
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('应用裁剪'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Crop(
        image: widget.imageBytes,
        controller: _controller,
        aspectRatio: _aspectRatio,
        withCircleUi: false,
        baseColor: Colors.black,
        maskColor: Colors.black.withOpacity(0.55),
        onCropped: (Uint8List croppedBytes) {
          if (!mounted) return;
          Navigator.of(context).pop<Uint8List>(croppedBytes);
        },
      ),
    );
  }
}
