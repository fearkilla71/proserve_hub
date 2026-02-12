import 'dart:async';

import 'package:flutter/material.dart';

import '../services/places_service.dart';

/// A [TextFormField] with Google Places Autocomplete overlay.
///
/// If no API key is configured it falls back to a regular text input.
///
/// [onPlaceSelected] fires after the user picks a suggestion and the
/// details are fetched — gives you structured city / state / zip to
/// auto-fill other fields.
class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.decoration,
    this.validator,
    this.textInputAction,
    this.onPlaceSelected,
    this.focusNode,
  });

  final TextEditingController controller;
  final InputDecoration? decoration;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  /// Fires after the user picks a suggestion and details are fetched.
  final void Function(PlaceDetails details)? onPlaceSelected;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;
  Timer? _debounce;
  List<PlacePrediction> _predictions = [];
  bool _suppressSearch = false;

  late final FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _onChanged(String value) {
    if (_suppressSearch || !PlacesService.isAvailable) return;

    _debounce?.cancel();
    if (value.trim().length < 3) {
      _removeOverlay();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await PlacesService.instance.autocomplete(value);
      if (!mounted) return;
      setState(() => _predictions = results);
      if (results.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  Future<void> _onPredictionTap(PlacePrediction prediction) async {
    _suppressSearch = true;
    widget.controller.text = prediction.description;
    _removeOverlay();

    // Fetch full details for structured fields
    try {
      final details = await PlacesService.instance.getDetails(
        prediction.placeId,
      );

      if (details != null) {
        // Use the street address for the field, not the full formatted address
        final street = details.streetAddress;
        if (street.isNotEmpty) {
          widget.controller.text = street;
        }
        widget.onPlaceSelected?.call(details);
      }
    } catch (e) {
      debugPrint('Place details fetch failed: $e');
    } finally {
      _suppressSearch = false;
    }
  }

  // ────────────────────── Overlay ──────────────────────────────

  void _showOverlay() {
    _removeOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 300;

    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, renderBox?.size.height ?? 56),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: _SuggestionList(
              predictions: _predictions,
              onTap: _onPredictionTap,
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  // ────────────────────── Build ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: widget.decoration,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        onChanged: _onChanged,
      ),
    );
  }
}

// ──────────────────── Suggestion dropdown ───────────────────────

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.predictions, required this.onTap});

  final List<PlacePrediction> predictions;
  final ValueChanged<PlacePrediction> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: predictions.length + 1, // +1 for Google attribution
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.2),
        ),
        itemBuilder: (context, index) {
          // Last item = Google attribution
          if (index == predictions.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'powered by ',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    'Google',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          final p = predictions[index];
          return InkWell(
            onTap: () => onTap(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.mainText,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.secondaryText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            p.secondaryText,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
