import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// An image that is replaced often, such as a camera frame or the board image after each takeout. Each one leaves the
/// image cache once the next one takes its place, so a live preview does not keep every frame it showed.
class LiveJpeg extends StatefulWidget {
  const LiveJpeg(this.jpeg, {super.key, this.fit = BoxFit.contain, this.cacheWidth, this.semanticLabel});

  final Uint8List jpeg;
  final BoxFit fit;

  /// Pixels to decode into; null keeps the image's size
  final int? cacheWidth;

  /// What the image shows, for screen readers: which camera
  final String? semanticLabel;

  @override
  State<LiveJpeg> createState() => _LiveJpegState();
}

class _LiveJpegState extends State<LiveJpeg> {
  late ImageProvider _provider = _providerFor(widget);

  static ImageProvider _providerFor(LiveJpeg image) =>
      ResizeImage.resizeIfNeeded(image.cacheWidth, null, MemoryImage(image.jpeg));

  @override
  void didUpdateWidget(LiveJpeg old) {
    super.didUpdateWidget(old);
    if (identical(old.jpeg, widget.jpeg) && old.cacheWidth == widget.cacheWidth) return;
    // The frame on screen stays until the next one is decoded; only the cache lets go of it.
    final previous = _provider;
    _provider = _providerFor(widget);
    previous.evict();
  }

  @override
  void dispose() {
    _provider.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Image(image: _provider, fit: widget.fit, gaplessPlayback: true, semanticLabel: widget.semanticLabel);
}
