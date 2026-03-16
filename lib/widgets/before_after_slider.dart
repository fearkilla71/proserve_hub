import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A draggable before/after photo comparison slider.
///
/// Place two images (before on left, after on right) and drag the handle
/// to reveal more of either side.
class BeforeAfterSlider extends StatefulWidget {
  final String beforeUrl;
  final String afterUrl;
  final String? beforeLabel;
  final String? afterLabel;
  final double height;

  const BeforeAfterSlider({
    super.key,
    required this.beforeUrl,
    required this.afterUrl,
    this.beforeLabel,
    this.afterLabel,
    this.height = 300,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _sliderPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final dividerX = width * _sliderPosition;

          return GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _sliderPosition =
                    (details.localPosition.dx / width).clamp(0.05, 0.95);
              });
            },
            child: Stack(
              children: [
                // After image (full width, behind)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: widget.afterUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade800,
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
                // Before image (clipped to left portion)
                Positioned.fill(
                  child: ClipRect(
                    clipper: _LeftClipper(dividerX),
                    child: CachedNetworkImage(
                      imageUrl: widget.beforeUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade800,
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                ),
                // Divider line
                Positioned(
                  left: dividerX - 1.5,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    color: Colors.white,
                  ),
                ),
                // Drag handle
                Positioned(
                  left: dividerX - 20,
                  top: (widget.height / 2) - 20,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.drag_handle,
                      color: Colors.black54,
                      size: 24,
                    ),
                  ),
                ),
                // Labels
                if (widget.beforeLabel != null)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _label(widget.beforeLabel!, Colors.orange.shade700),
                  ),
                if (widget.afterLabel != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _label(widget.afterLabel!, Colors.green.shade700),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Clips to only the left portion up to [clipWidth].
class _LeftClipper extends CustomClipper<Rect> {
  final double clipWidth;
  _LeftClipper(this.clipWidth);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, clipWidth, size.height);

  @override
  bool shouldReclip(_LeftClipper oldClipper) => oldClipper.clipWidth != clipWidth;
}
