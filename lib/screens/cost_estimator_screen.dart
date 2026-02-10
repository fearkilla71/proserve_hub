import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../models/invoice_models.dart';
import '../services/labor_ai_service.dart';
import '../services/material_ai_service.dart';

double _computeDescriptionScore(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;

  final tokens = trimmed
      .split(RegExp(r'\s+'))
      .where((t) => t.trim().isNotEmpty)
      .length;
  final hasNumbers = RegExp(r'\d').hasMatch(trimmed);
  final hasKeywords = RegExp(
    r'(exterior|interior|sq\s*ft|sqft|linear|soffit|fascia|pressure|wash|paint|trim|walls?|ceilings?|rooms?|doors?|cabinets?|holes?|patch)',
    caseSensitive: false,
  ).hasMatch(trimmed);

  double score = (tokens / 18).clamp(0, 1).toDouble();
  if (hasNumbers) score = (score + 0.15).clamp(0, 1);
  if (hasKeywords) score = (score + 0.2).clamp(0, 1);
  return score;
}

class CostEstimatorScreen extends StatefulWidget {
  final String serviceType;

  const CostEstimatorScreen({super.key, required this.serviceType});

  @override
  State<CostEstimatorScreen> createState() => _CostEstimatorScreenState();
}

class _CostEstimatorScreenState extends State<CostEstimatorScreen> {
  final _flow = _EstimatorFlowState();

  @override
  void initState() {
    super.initState();
    _flow.serviceType = widget.serviceType;

    // If the picker selected a specific painting type, preselect the scope so
    // the follow-up questions match immediately.
    if (widget.serviceType == 'Interior Painting') {
      _flow.answers['paint_scope'] = 'Interior walls/ceilings';
    } else if (widget.serviceType == 'Exterior Painting') {
      _flow.answers['paint_scope'] = 'Exterior surfaces';
    } else if (widget.serviceType == 'Cabinet Painting') {
      _flow.answers['paint_scope'] = 'Cabinets';
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CostEstimatorFlow(flow: _flow);
  }
}

class _EstimatorFlowState {
  String serviceType = '';

  final descriptionController = TextEditingController();
  final zipController = TextEditingController();
  final Map<String, String> answers = <String, String>{};

  XFile? photo;
  PlatformFile? blueprint;

  bool busy = false;

  void dispose() {
    descriptionController.dispose();
    zipController.dispose();
  }
}

enum _EstimatorStep { describe, gathering, questions, estimate, renderPrompt }

class _CostEstimatorFlow extends StatefulWidget {
  final _EstimatorFlowState flow;

  const _CostEstimatorFlow({required this.flow});

  @override
  State<_CostEstimatorFlow> createState() => _CostEstimatorFlowState();
}

class _CostEstimatorFlowState extends State<_CostEstimatorFlow> {
  _EstimatorStep _step = _EstimatorStep.describe;
  bool _canPop = true;
  int _questionIndex = 0;

  static const String _paintScopeId = 'paint_scope';
  static const String _pressureSurfaceId = 'surface';
  static const String _drywallScopeId = 'drywall_scope';

  // The estimate builder uses these.
  final Map<String, double> _quantities = {};
  final Map<String, TextEditingController> _quantityControllers = {};
  final List<MaterialItem> _customMaterials = [];
  double? _laborOverride;
  bool _laborOverrideIsManual = false;
  LaborAiEstimate? _aiLabor;
  bool _aiLaborBusy = false;
  bool _aiLaborRequested = false;
  String? _aiLaborError;
  bool _aiSuggesting = false;

  final Map<String, List<MaterialItem>> _materialDatabase = {
    'Painting': [
      MaterialItem('Interior Paint (Gallon)', 35.00, 'gallon'),
      MaterialItem('Exterior Paint (Gallon)', 45.00, 'gallon'),
      MaterialItem('Primer (Gallon)', 25.00, 'gallon'),
      MaterialItem('Paint Roller Set', 15.00, 'set'),
      MaterialItem('Paint Brushes', 12.00, 'set'),
      MaterialItem('Drop Cloth', 10.00, 'unit'),
      MaterialItem('Painter\'s Tape', 8.00, 'roll'),
      MaterialItem('Sandpaper Pack', 12.00, 'pack'),
    ],
    'Drywall Repair': [
      MaterialItem('Drywall (4x8)', 15.00, 'sheet'),
      MaterialItem('Joint Compound', 18.00, 'bucket'),
      MaterialItem('Drywall Tape', 6.00, 'roll'),
      MaterialItem('Drywall Screws', 9.00, 'box'),
      MaterialItem('Corner Bead', 7.00, 'unit'),
      MaterialItem('Sanding Sponge', 5.00, 'unit'),
      MaterialItem('Primer (Gallon)', 25.00, 'gallon'),
    ],
    'Pressure Washing': [
      MaterialItem('Pressure Washer Rental (Day)', 85.00, 'day'),
      MaterialItem('Surface Cleaner Attachment', 35.00, 'unit'),
      MaterialItem('Degreaser/Cleaner', 18.00, 'bottle'),
      MaterialItem('Mildew Remover', 16.00, 'bottle'),
      MaterialItem('Hose (50ft)', 25.00, 'unit'),
      MaterialItem('Nozzle Set', 20.00, 'set'),
      MaterialItem('Safety Goggles', 12.00, 'unit'),
      MaterialItem('Gloves', 10.00, 'pair'),
    ],
  };

  String _baseServiceType(String selected) {
    switch (selected) {
      case 'Interior Painting':
      case 'Exterior Painting':
      case 'Cabinet Painting':
        return 'Painting';
      default:
        return selected;
    }
  }

  int _initialQuestionIndexForService() {
    final base = _baseServiceType(widget.flow.serviceType);
    if (base == 'Painting') {
      final scope = widget.flow.answers[_paintScopeId]?.trim() ?? '';
      if (scope.isNotEmpty) return 1;
    }
    return 0;
  }

  List<MaterialItem> get _currentMaterialsForFlow =>
      _materialDatabase[_baseServiceType(widget.flow.serviceType)] ?? [];

  List<MaterialItem> get _allMaterialsForFlow => [
    ..._currentMaterialsForFlow,
    ..._customMaterials,
  ];

  TextEditingController _controllerFor(String materialId) {
    return _quantityControllers.putIfAbsent(materialId, () {
      final qty = _quantities[materialId] ?? 0.0;
      return TextEditingController(text: _formatQuantityForField(qty));
    });
  }

  String _formatQuantityForField(double qty) {
    if (!qty.isFinite || qty <= 0) return '';
    return qty.round().toString();
  }

  void _setQuantity(
    String materialId,
    double qty, {
    bool fromController = false,
  }) {
    final next = qty.isFinite ? qty : 0.0;
    final clamped = next < 0 ? 0.0 : next;

    setState(() {
      _quantities[materialId] = clamped;

      if (!fromController) {
        final c = _controllerFor(materialId);
        final nextText = _formatQuantityForField(clamped);
        if (c.text != nextText) {
          c.text = nextText;
          c.selection = TextSelection.collapsed(offset: c.text.length);
        }
      }
    });
  }

  double get _totalMaterialCost {
    double total = 0.0;
    for (var item in _allMaterialsForFlow) {
      final qty = _quantities[item.id] ?? 0.0;
      total += item.pricePerUnit * qty;
    }
    return total;
  }

  double _calculateWithTax(double rate) {
    return _totalMaterialCost * (1 + rate / 100);
  }

  String _includeMode() {
    return (widget.flow.answers['include_in_estimate'] ?? '').trim();
  }

  String _answer(String id) {
    return (widget.flow.answers[id] ?? '').trim().toLowerCase();
  }

  double _autoLaborEstimate() {
    final include = _includeMode().toLowerCase();
    if (include.contains('only material')) return 0.0;

    final base = _totalMaterialCost;
    if (base <= 0) return 0.0;

    final baseService = _baseServiceType(widget.flow.serviceType);
    double multiplier;
    switch (baseService) {
      case 'Painting':
        final scopeRaw = _answer(_paintScopeId);
        if (scopeRaw.contains('cabinet')) {
          multiplier = 3.2;
        } else if (scopeRaw.contains('exterior')) {
          multiplier = 2.8;
        } else {
          multiplier = 2.4;
        }
        break;
      case 'Drywall Repair':
        multiplier = 2.2;
        break;
      case 'Pressure Washing':
        multiplier = 1.3;
        break;
      default:
        multiplier = 2.0;
    }

    final coats = _answer('coats');
    if (coats.contains('2')) multiplier += 0.15;
    if (coats.contains('3')) multiplier += 0.3;

    final colorChange = _answer('color_change');
    if (colorChange.contains('light to dark') ||
        colorChange.contains('dark to light')) {
      multiplier += 0.15;
    }

    final duration = _answer('duration');
    if (duration.contains('2+')) multiplier += 0.2;
    if (duration.contains('1-2 weeks')) multiplier += 0.1;

    if (baseService == 'Painting') {
      final scopeRaw = _answer(_paintScopeId);
      if (scopeRaw.contains('interior')) {
        final wallCondition = _answer('interior_walls_condition');
        if (wallCondition.contains('some patching')) multiplier += 0.12;
        if (wallCondition.contains('a lot')) multiplier += 0.28;

        final furniture = _answer('interior_furniture');
        if (furniture.contains('yes')) multiplier += 0.12;
        if (furniture.contains('some')) multiplier += 0.06;

        final trim = _answer('interior_trim');
        if (trim.contains('yes')) multiplier += 0.18;
        if (trim.contains('some')) multiplier += 0.08;
      }

      if (scopeRaw.contains('cabinet')) {
        final boxes = _answer('cabinet_boxes');
        if (boxes.contains('doors + boxes')) multiplier += 0.35;

        final condition = _answer('cabinet_condition');
        if (condition.contains('grease') || condition.contains('wear')) {
          multiplier += 0.2;
        }
        if (condition.contains('stained') || condition.contains('varnished')) {
          multiplier += 0.15;
        }
        if (condition.contains('laminate')) multiplier += 0.1;

        final method = _answer('cabinet_method');
        if (method.contains('spray')) multiplier += 0.2;
        if (method.contains('brush')) multiplier += 0.08;
      }

      if (scopeRaw.contains('exterior')) {
        final stories = _answer('stories');
        if (stories.contains('2 stories')) multiplier += 0.18;
        if (stories.contains('3+')) multiplier += 0.35;

        final surface = _answer('surface_condition');
        if (surface.contains('moderate')) multiplier += 0.12;
        if (surface.contains('heavy')) multiplier += 0.22;

        final grade = _answer('paint_grade');
        if (grade.contains('premium')) multiplier += 0.08;
        if (grade.contains('elastomeric')) multiplier += 0.18;
        if (grade.contains('high-durability')) multiplier += 0.18;
      }
    }

    if (baseService == 'Drywall Repair') {
      final scope = _answer('drywall_scope');
      if (scope.contains('texture')) multiplier += 0.2;
      if (scope.contains('holes')) multiplier += 0.12;
      final size = _answer('drywall_patch_size');
      if (size.contains('medium')) multiplier += 0.1;
      if (size.contains('large')) multiplier += 0.2;
      final textureArea = _answer('drywall_texture_area');
      if (textureArea.contains('medium')) multiplier += 0.1;
      if (textureArea.contains('large')) multiplier += 0.2;
    }

    if (baseService == 'Pressure Washing') {
      final surface = _answer('surface');
      if (surface.contains('deck') || surface.contains('patio')) {
        multiplier += 0.1;
      }
      if (surface.contains('fence')) multiplier += 0.08;
      if (surface.contains('siding')) multiplier += 0.15;
      final mildew = _answer('mildew');
      if (mildew.contains('yes')) multiplier += 0.15;
      final condition = _answer('pw_condition');
      if (condition.contains('moderate')) multiplier += 0.08;
      if (condition.contains('heavy')) multiplier += 0.18;
      final area = _answer('pw_area');
      if (area.contains('medium')) multiplier += 0.1;
      if (area.contains('large')) multiplier += 0.2;
      final oil = _answer('pw_oil');
      if (oil.contains('yes')) multiplier += 0.15;
      final delicate = _answer('pw_delicate');
      if (delicate.contains('yes')) multiplier += 0.1;
    }

    final labor = base * multiplier;
    return labor < 0 ? 0 : labor;
  }

  double get _laborTotal {
    if (_laborOverride != null) return _laborOverride!;
    if (_aiLabor != null) return _aiLabor!.total;
    return _autoLaborEstimate();
  }

  double get _estimateTotal {
    final include = _includeMode().toLowerCase();
    if (include.contains('only labor')) return _laborTotal;
    if (include.contains('only material')) return _totalMaterialCost;
    return _totalMaterialCost + _laborTotal;
  }

  void _setLaborOverride(double? value, {bool manual = true}) {
    setState(() {
      _laborOverride = value;
      _laborOverrideIsManual = manual && value != null;
    });
  }

  Future<void> _requestAiLaborEstimate({bool force = false}) async {
    if (_aiLaborBusy) return;
    if (!force && _aiLaborRequested) return;

    final include = _includeMode().toLowerCase();
    if (!force && include.contains('only material')) return;

    setState(() {
      _aiLaborBusy = true;
      _aiLaborError = null;
      _aiLaborRequested = true;
    });

    try {
      final description = widget.flow.descriptionController.text.trim();
      final zip = widget.flow.zipController.text.trim();
      final answers = Map<String, String>.from(widget.flow.answers);

      final materials = <Map<String, dynamic>>[];
      for (final item in _allMaterialsForFlow) {
        final qty = _quantities[item.id] ?? 0.0;
        if (qty <= 0) continue;
        materials.add({
          'name': item.name,
          'unit': item.unit,
          'pricePerUnit': item.pricePerUnit,
          'quantity': qty.round(),
        });
      }

      final estimate = await LaborAiService().estimateLabor(
        serviceType: widget.flow.serviceType,
        description: description,
        answers: answers,
        materials: materials,
        materialTotal: _totalMaterialCost,
        zip: zip.isEmpty ? null : zip,
        urgency: widget.flow.answers['urgency'],
      );

      if (!mounted) return;

      setState(() {
        _aiLabor = estimate;
        _laborOverride = null;
        _laborOverrideIsManual = false;
      });

      final summary = estimate.summary.trim().isNotEmpty
          ? estimate.summary.trim()
          : 'AI labor updated.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(summary)));
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _aiLaborError = message.isEmpty ? 'AI labor failed.' : message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI labor failed: ${_aiLaborError!}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _aiLaborBusy = false;
        });
      }
    }
  }

  void _addCustomItem({
    required String name,
    required String unit,
    required double price,
    required int quantity,
  }) {
    final id =
        'custom_${DateTime.now().millisecondsSinceEpoch}_${_customMaterials.length}';
    final item = MaterialItem(name, price, unit, id: id, isCustom: true);
    setState(() {
      _customMaterials.add(item);
    });
    _setQuantity(id, quantity.toDouble());
  }

  void _updateCustomItemPrice(String id, double price) {
    final index = _customMaterials.indexWhere((item) => item.id == id);
    if (index < 0) return;
    setState(() {
      _customMaterials[index] = _customMaterials[index].copyWith(
        pricePerUnit: price,
      );
    });
  }

  Future<String?> _promptForJobDetails() async {
    final controller = TextEditingController(
      text: widget.flow.descriptionController.text,
    );
    final res = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Job details (optional)'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'Example: 2 bedrooms + hallway, 900 sq ft, semi-gloss trim\nOr: patch 3 holes + skim coat one wall',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Use AI'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return res;
  }

  Future<void> _suggestQuantitiesWithAi() async {
    if (_aiSuggesting) return;
    final messenger = ScaffoldMessenger.of(context);

    final notes = await _promptForJobDetails();
    if (!mounted || notes == null) return;

    setState(() {
      _aiSuggesting = true;
    });

    try {
      final materials = _currentMaterialsForFlow
          .map(
            (m) => {
              'name': m.name,
              'unit': m.unit,
              'pricePerUnit': m.pricePerUnit,
            },
          )
          .toList(growable: false);

      final suggestion = await MaterialAiService().suggestQuantities(
        serviceType: widget.flow.serviceType,
        materials: materials,
        notes: notes,
      );

      // Apply only to materials in the current list.
      final names = _currentMaterialsForFlow.map((m) => m.id).toSet();
      for (final entry in suggestion.quantities.entries) {
        if (!names.contains(entry.key)) continue;
        final q = entry.value;
        if (q < 0) continue;
        _setQuantity(entry.key, q.toDouble());
      }

      final assumptions = suggestion.assumptions.trim();
      final canCreateInvoice = _totalMaterialCost > 0;
      final snackText = assumptions.isNotEmpty
          ? assumptions
          : 'AI quantities applied.';

      messenger.showSnackBar(
        SnackBar(
          content: Text(snackText),
          action: canCreateInvoice
              ? SnackBarAction(
                  label: 'Create invoice',
                  onPressed: _createInvoiceFromMaterials,
                )
              : null,
        ),
      );
    } catch (e) {
      var msg = e.toString().trim();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring('Exception: '.length).trim();
      }
      final upper = msg.toUpperCase();
      if (upper == 'INTERNAL' ||
          upper.endsWith(': INTERNAL') ||
          upper == 'INTERNAL: INTERNAL') {
        msg = 'AI service error. Try again in a minute.';
      }
      messenger.showSnackBar(
        SnackBar(content: Text('AI suggestion failed: $msg')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _aiSuggesting = false;
        });
      }
    }
  }

  void _createInvoiceFromMaterials() {
    final items = <InvoiceLineItem>[];

    for (final item in _allMaterialsForFlow) {
      final qty = _quantities[item.id] ?? 0.0;
      if (qty <= 0) continue;

      final qtyInt = qty.isFinite ? qty.round() : 0;
      if (qtyInt <= 0) continue;

      items.add(
        InvoiceLineItem(
          description: item.name,
          quantity: qtyInt,
          unitPrice: item.pricePerUnit,
        ),
      );
    }

    final fallbackItems = items.isEmpty
        ? [
            InvoiceLineItem(
              description: 'Materials',
              quantity: 1,
              unitPrice: _totalMaterialCost,
            ),
          ]
        : items;

    final draft = InvoiceDraft.empty().copyWith(
      jobTitle: '${widget.flow.serviceType} materials estimate',
      jobDescription:
          'Material estimate based on market averages. Review pricing before sending to a customer.',
      items: fallbackItems,
    );

    context.push('/invoice-maker', extra: {'initialDraft': draft});
  }

  @override
  void didUpdateWidget(covariant _CostEstimatorFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flow.serviceType != widget.flow.serviceType) {
      for (final c in _quantityControllers.values) {
        c.dispose();
      }
      _quantityControllers.clear();
      _quantities.clear();
      _aiLabor = null;
      _aiLaborRequested = false;
      _aiLaborError = null;
    }
  }

  @override
  void dispose() {
    for (final c in _quantityControllers.values) {
      c.dispose();
    }
    _quantityControllers.clear();
    super.dispose();
  }

  void _goTo(_EstimatorStep next) {
    setState(() => _step = next);
    if (next == _EstimatorStep.estimate) {
      _requestAiLaborEstimate();
    }
  }

  Future<void> _beginGathering() async {
    if (widget.flow.busy) return;
    setState(() {
      widget.flow.busy = true;
      _canPop = false;
      _step = _EstimatorStep.gathering;
      _questionIndex = 0;
    });

    // Small, intentional delay so the user sees the animation.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    // Pre-fill some quantities based on service type and description.
    // If AI is configured and available, users can still run it later.
    _applyTemplateQuantities(
      serviceType: _baseServiceType(widget.flow.serviceType),
      description: widget.flow.descriptionController.text,
    );

    // Optional: if the user attached an image/blueprint, we could run OCR later.
    // For now we just proceed.
    if (!mounted) return;
    setState(() {
      widget.flow.busy = false;
      _canPop = true;
      _step = _EstimatorStep.questions;
      _questionIndex = _initialQuestionIndexForService();
    });
  }

  void _applyTemplateQuantities({
    required String serviceType,
    required String description,
  }) {
    final text = description.toLowerCase();
    final materials = _currentMaterialsForFlow;
    if (materials.isEmpty) return;

    int scale = 1;
    if (text.contains('exterior') || text.contains('outside')) scale += 2;
    if (text.contains('pressure') || text.contains('washing')) scale += 1;
    if (text.contains('color change')) scale += 1;
    if (text.contains('soffit') || text.contains('fascia')) scale += 1;
    if (text.contains('2 bedroom') || text.contains('3 bedroom')) scale += 1;
    scale = scale.clamp(1, 6).toInt();

    for (final m in materials) {
      final name = m.name.toLowerCase();
      double qty = 0;
      if (serviceType == 'Painting') {
        if (name.contains('paint') && name.contains('gallon')) {
          qty = (2 * scale).toDouble();
        }
        if (name.contains('primer')) qty = (1 * scale).toDouble();
        if (name.contains('tape')) qty = 2;
        if (name.contains('drop cloth')) qty = 1;
        if (name.contains('roller')) qty = 1;
        if (name.contains('brush')) qty = 1;
        if (name.contains('sandpaper')) qty = 1;
      } else if (serviceType == 'Pressure Washing') {
        if (name.contains('rental')) qty = 1;
        if (name.contains('cleaner')) qty = (1 * scale).toDouble();
        if (name.contains('mildew')) qty = 1;
        if (name.contains('nozzle')) qty = 1;
        if (name.contains('glove')) qty = 1;
        if (name.contains('goggle')) qty = 1;
      } else if (serviceType == 'Drywall Repair') {
        if (name.contains('drywall') && name.contains('4x8')) {
          qty = (1 * scale).toDouble();
        }
        if (name.contains('compound')) qty = 1;
        if (name.contains('tape')) qty = 1;
        if (name.contains('screw')) qty = 1;
        if (name.contains('corner')) qty = 1;
        if (name.contains('sanding')) qty = 1;
        if (name.contains('primer')) qty = 1;
      }
      if (qty > 0) {
        _setQuantity(m.id, qty);
      }
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (!mounted) return;
    setState(() => widget.flow.photo = picked);
  }

  Future<void> _pickBlueprint() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: false,
    );
    if (!mounted) return;
    setState(() => widget.flow.blueprint = res?.files.first);
  }

  Future<void> _showAddMediaSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add a photo or blueprint?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Improves accuracy of estimate',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _SheetAction(
                  icon: Icons.photo_camera_outlined,
                  title: 'Take a Picture',
                  onTap: () async {
                    Navigator.pop(context);
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (!mounted) return;
                    setState(() => widget.flow.photo = picked);
                  },
                ),
                const SizedBox(height: 10),
                _SheetAction(
                  icon: Icons.photo_outlined,
                  title: 'Image from Gallery',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickPhoto();
                  },
                ),
                const SizedBox(height: 10),
                _SheetAction(
                  icon: Icons.attach_file,
                  title: 'Upload Blueprint',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickBlueprint();
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_Question> _questionsForService(String serviceType) {
    final base = _baseServiceType(serviceType);

    if (base == 'Painting') {
      final scopeRaw = (widget.flow.answers[_paintScopeId] ?? '').toLowerCase();
      final scope = scopeRaw.contains('interior')
          ? 'interior'
          : (scopeRaw.contains('exterior')
                ? 'exterior'
                : (scopeRaw.contains('cabinet') ? 'cabinets' : ''));

      final questions = <_Question>[
        const _Question(
          id: _paintScopeId,
          title: 'What are you painting?',
          emoji: '🧭',
          options: [
            'Interior walls/ceilings',
            'Exterior surfaces',
            'Cabinets',
            'Unsure',
            'Other',
          ],
        ),
      ];

      // Don’t proceed until scope is selected.
      if (scope.isEmpty) return questions;

      // Common painting questions.
      questions.addAll(const [
        _Question(
          id: 'include_in_estimate',
          title: 'What do you want to include in the estimate?',
          emoji: '🧾',
          options: [
            'Only Material cost',
            'Only Labor cost',
            'Both Material and labor cost',
            'Other',
          ],
        ),
        _Question(
          id: 'coats',
          title: 'How many finish coats?',
          emoji: '🖌️',
          options: ['1 coat', '2 coats', '3 coats', 'Unsure', 'Other'],
        ),
        _Question(
          id: 'color_change',
          title: 'How significant is the color change?',
          emoji: '🔁',
          options: [
            'Same color',
            'Light to dark',
            'Dark to light',
            'Unsure',
            'Other',
          ],
        ),
        _Question(
          id: 'duration',
          title: 'What is the expected project duration including idle time?',
          emoji: '🕐',
          options: [
            '1-2 days',
            '3-5 days',
            '1-2 weeks',
            '2+ weeks',
            'Unsure',
            'Other',
          ],
        ),
        _Question(
          id: 'pricing_model',
          title: 'How do you want to charge for painting?',
          emoji: '📏',
          options: ['Per square foot', 'Per hour', 'Unsure', 'Other'],
        ),
      ]);

      if (scope == 'interior') {
        questions.addAll(const [
          _Question(
            id: 'interior_rooms',
            title: 'How many rooms/areas are being painted?',
            emoji: '🚪',
            options: ['1-2', '3-5', '6-8', '9+', 'Unsure', 'Other'],
          ),
          _Question(
            id: 'interior_walls_condition',
            title: 'What condition are the walls in?',
            emoji: '🧱',
            options: [
              'Good (minimal patches)',
              'Some patching/sanding',
              'A lot of repair/texture work',
              'Unsure',
              'Other',
            ],
          ),
          _Question(
            id: 'interior_furniture',
            title: 'Will furniture need moving/covering?',
            emoji: '🛋️',
            options: ['Yes', 'No', 'Some', 'Unsure', 'Other'],
          ),
          _Question(
            id: 'interior_trim',
            title: 'Are you also painting trim/doors?',
            emoji: '🚪',
            options: ['Yes', 'No', 'Some', 'Unsure', 'Other'],
          ),
        ]);
      } else if (scope == 'cabinets') {
        questions.addAll(const [
          _Question(
            id: 'cabinet_boxes',
            title: 'Are you painting cabinet doors only or doors + boxes?',
            emoji: '🗄️',
            options: ['Doors only', 'Doors + boxes', 'Unsure', 'Other'],
          ),
          _Question(
            id: 'cabinet_condition',
            title: 'What is the cabinet finish/condition?',
            emoji: '🪵',
            options: [
              'Previously painted',
              'Stained/varnished',
              'Laminate',
              'Grease/wear present',
              'Unsure',
              'Other',
            ],
          ),
          _Question(
            id: 'cabinet_method',
            title: 'Preferred finish method?',
            emoji: '🎨',
            options: ['Spray', 'Brush/roll', 'Unsure', 'Other'],
          ),
        ]);
      } else {
        // Exterior painting.
        questions.addAll(const [
          _Question(
            id: 'stories',
            title: 'How many stories is the house?',
            emoji: '🏠',
            options: ['1 story', '2 stories', '3+ stories', 'Unsure', 'Other'],
          ),
          _Question(
            id: 'surface_condition',
            title: 'What is the condition of the exterior surfaces?',
            emoji: '🧹',
            options: [
              'Clean, no significant dirt or grime',
              'Moderate dirt/grime',
              'Heavy dirt/grime or mildew',
              'Unsure',
              'Other',
            ],
          ),
          _Question(
            id: 'paint_grade',
            title: 'What grade of exterior paint do you want to use?',
            emoji: '🎨',
            options: [
              'Contractor-grade acrylic',
              'Premium acrylic',
              'Elastomeric',
              'High-durability',
              'Unsure',
              'Other',
            ],
          ),
        ]);
      }

      return questions;
    }
    if (base == 'Pressure Washing') {
      final surfaceRaw = (widget.flow.answers[_pressureSurfaceId] ?? '')
          .toLowerCase();
      final surface = surfaceRaw.contains('drive')
          ? 'driveway'
          : (surfaceRaw.contains('deck') || surfaceRaw.contains('patio')
                ? 'deck'
                : (surfaceRaw.contains('fence')
                      ? 'fence'
                      : (surfaceRaw.contains('siding')
                            ? 'siding'
                            : (surfaceRaw.contains('mixed') ? 'mixed' : ''))));

      final questions = <_Question>[
        const _Question(
          id: _pressureSurfaceId,
          title:
              'What surface are you washing?'
              ' (Pick the main one)',
          emoji: '💧',
          options: ['Siding', 'Driveway', 'Deck/Patio', 'Fence', 'Mixed'],
        ),
      ];

      if (surface.isEmpty) return questions;

      questions.addAll(const [
        _Question(
          id: 'pw_condition',
          title: 'How dirty is it overall?',
          emoji: '🧽',
          options: [
            'Light dirt',
            'Moderate dirt/grime',
            'Heavy buildup',
            'Unsure',
            'Other',
          ],
        ),
        _Question(
          id: 'pw_area',
          title: 'How much area are you washing?',
          emoji: '📐',
          options: [
            'Small (single area)',
            'Medium (a couple areas)',
            'Large (whole property)',
            'Unsure',
            'Other',
          ],
        ),
      ]);

      if (surface == 'driveway') {
        questions.addAll(const [
          _Question(
            id: 'pw_oil',
            title: 'Any oil/rust stains that need treatment?',
            emoji: '🛢️',
            options: ['Yes', 'No', 'Unsure', 'Other'],
          ),
          _Question(
            id: 'pw_concrete_type',
            title: 'What type of concrete? (optional)',
            emoji: '🧱',
            options: ['Regular', 'Stamped', 'Pavers', 'Unsure', 'Other'],
          ),
        ]);
      } else {
        // Siding / deck / fence / mixed.
        questions.addAll(const [
          _Question(
            id: 'mildew',
            title: 'Any mildew or heavy staining?',
            emoji: '🧼',
            options: ['Yes', 'No', 'Unsure', 'Other'],
          ),
          _Question(
            id: 'pw_delicate',
            title: 'Any delicate areas to avoid high pressure?',
            emoji: '⚠️',
            options: ['Yes', 'No', 'Unsure', 'Other'],
          ),
        ]);
      }

      return questions;
    }
    if (base == 'Drywall Repair') {
      final scopeRaw = (widget.flow.answers[_drywallScopeId] ?? '')
          .toLowerCase();
      final scope = scopeRaw.contains('patch') || scopeRaw.contains('holes')
          ? 'patch'
          : (scopeRaw.contains('replace')
                ? 'replace'
                : (scopeRaw.contains('skim')
                      ? 'skim'
                      : (scopeRaw.contains('texture')
                            ? 'texture'
                            : (scopeRaw.contains('water') ? 'water' : ''))));

      final questions = <_Question>[
        const _Question(
          id: _drywallScopeId,
          title: 'What type of drywall work is it?',
          emoji: '🧱',
          options: [
            'Patch holes / dents',
            'Replace damaged sections',
            'Skim coat',
            'Match texture',
            'Water damage',
            'Unsure',
            'Other',
          ],
        ),
      ];

      if (scope.isEmpty) return questions;

      questions.addAll(const [
        _Question(
          id: 'drywall_location',
          title: 'Where is the drywall?',
          emoji: '📍',
          options: ['Walls', 'Ceilings', 'Both', 'Unsure', 'Other'],
        ),
        _Question(
          id: 'drywall_paint',
          title: 'Do you want painting included after repair?',
          emoji: '🎨',
          options: ['Yes', 'No', 'Unsure', 'Other'],
        ),
      ]);

      if (scope == 'patch') {
        questions.addAll(const [
          _Question(
            id: 'drywall_holes_count',
            title: 'How many holes/patch spots?',
            emoji: '🕳️',
            options: ['1-2', '3-5', '6-10', '10+', 'Unsure', 'Other'],
          ),
          _Question(
            id: 'drywall_hole_size',
            title: 'Typical hole size?',
            emoji: '📏',
            options: [
              'Nail/screw holes',
              'Small (up to 2")',
              'Medium (2"-6")',
              'Large (6"+)',
              'Unsure',
              'Other',
            ],
          ),
        ]);
      } else if (scope == 'replace' || scope == 'water') {
        questions.addAll(const [
          _Question(
            id: 'drywall_area_replace',
            title: 'How much needs replacing?',
            emoji: '📐',
            options: [
              'Small section (under 4 sq ft)',
              '1 sheet area (up to 32 sq ft)',
              'Multiple sheets',
              'Unsure',
              'Other',
            ],
          ),
          _Question(
            id: 'drywall_mold',
            title: 'Any signs of mold or soft drywall?',
            emoji: '🦠',
            options: ['Yes', 'No', 'Unsure', 'Other'],
          ),
        ]);
      } else if (scope == 'skim') {
        questions.addAll(const [
          _Question(
            id: 'drywall_skim_area',
            title: 'How much area will be skim coated?',
            emoji: '🧽',
            options: [
              'One wall',
              'One room',
              'Multiple rooms',
              'Whole level',
              'Unsure',
              'Other',
            ],
          ),
          _Question(
            id: 'drywall_level',
            title: 'Desired finish level?',
            emoji: '✨',
            options: ['Basic', 'Smooth (Level 5)', 'Unsure', 'Other'],
          ),
        ]);
      } else {
        // Texture match.
        questions.addAll(const [
          _Question(
            id: 'drywall_texture_type',
            title: 'What texture is it?',
            emoji: '🌀',
            options: [
              'Orange peel',
              'Knockdown',
              'Popcorn',
              'Smooth',
              'Unsure',
              'Other',
            ],
          ),
          _Question(
            id: 'drywall_texture_area',
            title: 'How big is the texture repair area?',
            emoji: '📐',
            options: ['Small', 'Medium', 'Large', 'Unsure', 'Other'],
          ),
        ]);
      }

      questions.add(
        const _Question(
          id: 'drywall_urgency',
          title: 'When do you need this done?',
          emoji: '⏱️',
          options: ['ASAP', 'This week', 'This month', 'Flexible', 'Other'],
        ),
      );

      return questions;
    }
    return const [
      _Question(
        id: 'urgency',
        title: 'When do you need this done?',
        emoji: '⏱️',
        options: ['ASAP', 'This week', 'This month', 'Flexible'],
      ),
    ];
  }

  void _answerQuestion(String id, String answer) {
    setState(() {
      widget.flow.answers[id] = answer;
      _aiLabor = null;
      _aiLaborRequested = false;
      _aiLaborError = null;

      // If the user changes paint scope, clear scope-specific answers to prevent mismatches.
      if (id == _paintScopeId) {
        const keep = <String>{
          _paintScopeId,
          'include_in_estimate',
          'coats',
          'color_change',
          'duration',
          'pricing_model',
        };
        final toRemove = <String>[];
        for (final k in widget.flow.answers.keys) {
          if (k == _paintScopeId) continue;
          final isPaintKey =
              k.startsWith('interior_') ||
              k.startsWith('cabinet_') ||
              k == 'stories' ||
              k == 'surface_condition' ||
              k == 'paint_grade';
          if (isPaintKey && !keep.contains(k)) {
            toRemove.add(k);
          }
        }
        for (final k in toRemove) {
          widget.flow.answers.remove(k);
        }
        _questionIndex = 0;
      }

      // If the user changes pressure washing surface, clear surface-specific answers.
      if (id == _pressureSurfaceId) {
        final toRemove = <String>[];
        for (final k in widget.flow.answers.keys) {
          if (k == _pressureSurfaceId) continue;
          if (k == 'mildew' || k.startsWith('pw_')) {
            toRemove.add(k);
          }
        }
        for (final k in toRemove) {
          widget.flow.answers.remove(k);
        }
        _questionIndex = 0;
      }

      // If the user changes drywall scope, clear scope-specific answers.
      if (id == _drywallScopeId) {
        final toRemove = <String>[];
        for (final k in widget.flow.answers.keys) {
          if (k == _drywallScopeId) continue;
          if (k.startsWith('drywall_')) {
            toRemove.add(k);
          }
        }
        for (final k in toRemove) {
          widget.flow.answers.remove(k);
        }
        _questionIndex = 0;
      }
    });
  }

  Future<void> _onNext() async {
    if (_step == _EstimatorStep.describe) {
      await _beginGathering();
      return;
    }

    if (_step == _EstimatorStep.questions) {
      final questions = _questionsForService(widget.flow.serviceType);
      if (questions.isEmpty) {
        _goTo(_EstimatorStep.estimate);
        return;
      }

      final idx = _questionIndex.clamp(0, questions.length - 1);
      final q = questions[idx];
      final answered = widget.flow.answers[q.id]?.trim().isNotEmpty ?? false;
      if (!answered) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick an option to continue.')),
        );
        return;
      }

      if (idx < questions.length - 1) {
        setState(() {
          _questionIndex = idx + 1;
        });
        return;
      }

      _goTo(_EstimatorStep.estimate);
      return;
    }

    if (_step == _EstimatorStep.estimate) {
      _goTo(_EstimatorStep.renderPrompt);
      return;
    }

    if (_step == _EstimatorStep.renderPrompt) {
      Navigator.pop(context);
    }
  }

  void _onBack() {
    if (_step == _EstimatorStep.describe) {
      Navigator.pop(context);
      return;
    }
    if (_step == _EstimatorStep.gathering) {
      // Do nothing; gathering is short.
      return;
    }
    if (_step == _EstimatorStep.questions) {
      if (_questionIndex > 0) {
        setState(() {
          _questionIndex -= 1;
        });
        return;
      }
      _goTo(_EstimatorStep.describe);
      return;
    }
    if (_step == _EstimatorStep.estimate) {
      _goTo(_EstimatorStep.questions);
      return;
    }
    if (_step == _EstimatorStep.renderPrompt) {
      _goTo(_EstimatorStep.estimate);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandNavy = Color(0xFF0C1B3A);
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: brandNavy,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
          centerTitle: true,
          title: Text(
            _step == _EstimatorStep.describe
                ? 'Describe Project'
                : (_step == _EstimatorStep.questions
                      ? 'Further Questions'
                      : (_step == _EstimatorStep.renderPrompt
                            ? 'Project Render'
                            : '${widget.flow.serviceType} Cost Estimator')),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _canPop ? _onBack : null,
          ),
          actions: [
            if (_step == _EstimatorStep.describe)
              IconButton(
                tooltip: 'Next',
                icon: const Icon(Icons.arrow_forward),
                onPressed: widget.flow.descriptionController.text.trim().isEmpty
                    ? null
                    : _onNext,
              ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: switch (_step) {
            _EstimatorStep.describe => _DescribeProjectStep(
              key: const ValueKey('describe'),
              flow: widget.flow,
              onAddMedia: _showAddMediaSheet,
              onNext: _onNext,
            ),
            _EstimatorStep.gathering => const _GatheringStep(
              key: ValueKey('gathering'),
            ),
            _EstimatorStep.questions => _QuestionsStep(
              key: const ValueKey('questions'),
              serviceType: widget.flow.serviceType,
              questions: _questionsForService(widget.flow.serviceType),
              answers: widget.flow.answers,
              onAnswer: _answerQuestion,
              questionIndex: _questionIndex,
              onNext: _onNext,
            ),
            _EstimatorStep.estimate => _EstimateBuilderStep(
              key: const ValueKey('estimate'),
              serviceType: widget.flow.serviceType,
              quantities: _quantities,
              materials: _allMaterialsForFlow,
              controllerFor: _controllerFor,
              setQuantity: _setQuantity,
              total: _estimateTotal,
              laborTotal: _laborTotal,
              laborIsManualOverride: _laborOverrideIsManual,
              laborEnabled: !_includeMode().toLowerCase().contains(
                'only material',
              ),
              aiLaborBusy: _aiLaborBusy,
              aiLaborSummary: _aiLabor?.summary,
              aiLaborAssumptions: _aiLabor?.assumptions,
              aiLaborHours: _aiLabor?.hours,
              aiLaborRate: _aiLabor?.hourlyRate,
              aiLaborConfidence: _aiLabor?.confidence,
              aiLaborError: _aiLaborError,
              onLaborOverride: (value) =>
                  _setLaborOverride(value, manual: true),
              onAutoLabor: () => _requestAiLaborEstimate(force: true),
              calculateWithTax: _calculateWithTax,
              aiSuggesting: _aiSuggesting,
              suggestQuantitiesWithAi: _suggestQuantitiesWithAi,
              createInvoiceFromMaterials: _createInvoiceFromMaterials,
              onAddCustomItem: _addCustomItem,
              onUpdateCustomItemPrice: _updateCustomItemPrice,
              onNext: _onNext,
            ),
            _EstimatorStep.renderPrompt => _RenderPromptStep(
              key: const ValueKey('renderPrompt'),
              onGenerate: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Project Render is coming soon.'),
                  ),
                );
              },
              onNo: _onNext,
            ),
          },
        ),
      ),
    );
  }
}

class MaterialItem {
  final String id;
  final String name;
  final double pricePerUnit;
  final String unit;
  final bool isCustom;

  const MaterialItem(
    this.name,
    this.pricePerUnit,
    this.unit, {
    String? id,
    this.isCustom = false,
  }) : id = id ?? name;

  MaterialItem copyWith({String? name, double? pricePerUnit, String? unit}) {
    return MaterialItem(
      name ?? this.name,
      pricePerUnit ?? this.pricePerUnit,
      unit ?? this.unit,
      id: id,
      isCustom: isCustom,
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DescribeProjectStep extends StatefulWidget {
  final _EstimatorFlowState flow;
  final Future<void> Function() onAddMedia;
  final Future<void> Function() onNext;

  const _DescribeProjectStep({
    super.key,
    required this.flow,
    required this.onAddMedia,
    required this.onNext,
  });

  @override
  State<_DescribeProjectStep> createState() => _DescribeProjectStepState();
}

class _DescribeProjectStepState extends State<_DescribeProjectStep> {
  @override
  Widget build(BuildContext context) {
    final score = _computeDescriptionScore(
      widget.flow.descriptionController.text,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Description Score',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _ScoreChip(score: score),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: include measurements (sq ft), surfaces/rooms, coats/prep, and any stains or damage for a better estimate.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: widget.flow.descriptionController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText:
                      'interior 3 bed 2 bath, patch holes, paint walls + trim\nexterior siding + fascia + soffit, color change\npressure washing driveway w/ oil stains',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.flow.zipController,
              keyboardType: TextInputType.number,
              maxLength: 5,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'ZIP code (optional) - Houston default',
                hintText: 'Enter 5-digit ZIP',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onAddMedia,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      (widget.flow.photo != null ||
                              widget.flow.blueprint != null)
                          ? 'Media added'
                          : 'Add photo/blueprint',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 64,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Voice input coming soon.'),
                        ),
                      );
                    },
                    child: const Icon(Icons.mic_none),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.flow.descriptionController.text.trim().isEmpty
                    ? null
                    : widget.onNext,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final double score;

  const _ScoreChip({required this.score});

  @override
  Widget build(BuildContext context) {
    return _AnimatedScoreChip(score: score);
  }
}

class _AnimatedScoreChip extends StatefulWidget {
  final double score;

  const _AnimatedScoreChip({required this.score});

  @override
  State<_AnimatedScoreChip> createState() => _AnimatedScoreChipState();
}

class _AnimatedScoreChipState extends State<_AnimatedScoreChip> {
  double _from = 0.0;

  @override
  void didUpdateWidget(covariant _AnimatedScoreChip oldWidget) {
    _from = oldWidget.score;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final to = widget.score.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _from.clamp(0.0, 1.0), end: to),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        final pct = (value * 100).round();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Stack(
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 4,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  const Center(child: SizedBox(width: 1, height: 1)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$pct%',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        );
      },
    );
  }
}

class _GatheringStep extends StatelessWidget {
  const _GatheringStep({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: Center(child: _TapeMeasureLoader()));
  }
}

class _TapeMeasureLoader extends StatefulWidget {
  const _TapeMeasureLoader();

  @override
  State<_TapeMeasureLoader> createState() => _TapeMeasureLoaderState();
}

class _TapeMeasureLoaderState extends State<_TapeMeasureLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Gathering Information...',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 26),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_c.value);
              return CustomPaint(
                size: const Size(double.infinity, 90),
                painter: _TapeMeasurePainter(progress: t),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TapeMeasurePainter extends CustomPainter {
  final double progress;

  _TapeMeasurePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF2F2F2F)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final tapePaint = Paint()..color = const Color(0xFFF2B134);
    final tapeDark = Paint()..color = const Color(0xFFD79A2A);

    final y = size.height * 0.62;
    final left = 18.0;
    final right = size.width - 18.0;
    final len = (right - left) * (0.15 + 0.7 * progress);
    final endX = left + len;

    // Draw the measuring line.
    canvas.drawLine(Offset(left, y), Offset(endX, y), linePaint);

    // Small end cap.
    canvas.drawRect(
      Rect.fromLTWH(endX - 2, y - 6, 4, 12),
      Paint()..color = Colors.black,
    );

    // Tape measure body moving slightly.
    final bodyW = 62.0;
    final bodyH = 54.0;
    final bodyX = left + (len - bodyW * 0.4).clamp(0, right - bodyW);
    final bodyY = y - bodyH;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyX, bodyY, bodyW, bodyH),
      const Radius.circular(16),
    );

    canvas.drawRRect(r, tapePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bodyX, bodyY + bodyH * 0.55, bodyW, bodyH * 0.45),
        const Radius.circular(16),
      ),
      tapeDark,
    );

    // Lens circle.
    canvas.drawCircle(
      Offset(bodyX + bodyW * 0.42, bodyY + bodyH * 0.55),
      bodyH * 0.18,
      Paint()..color = Colors.black,
    );
    canvas.drawCircle(
      Offset(bodyX + bodyW * 0.42, bodyY + bodyH * 0.55),
      bodyH * 0.08,
      Paint()..color = const Color(0xFF4B4B4B),
    );
  }

  @override
  bool shouldRepaint(covariant _TapeMeasurePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Question {
  final String id;
  final String title;
  final String emoji;
  final List<String> options;

  const _Question({
    required this.id,
    required this.title,
    required this.emoji,
    required this.options,
  });
}

class _QuestionsStep extends StatelessWidget {
  final String serviceType;
  final List<_Question> questions;
  final Map<String, String> answers;
  final void Function(String id, String answer) onAnswer;
  final int questionIndex;
  final Future<void> Function() onNext;

  const _QuestionsStep({
    super.key,
    required this.serviceType,
    required this.questions,
    required this.answers,
    required this.onAnswer,
    required this.questionIndex,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final clampedIndex = questions.isEmpty
        ? 0
        : questionIndex.clamp(0, questions.length - 1);
    final q = questions.isEmpty ? null : questions[clampedIndex];
    final selected = q == null ? null : answers[q.id]?.trim();
    final canContinue = selected != null && selected.isNotEmpty;
    final progress = questions.isEmpty
        ? 0.0
        : ((clampedIndex + 1) / questions.length).clamp(0.0, 1.0);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: progress,
                backgroundColor: const Color(0xFFE0E0E0),
                color: const Color(0xFF00A8C6),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: q == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${q.emoji} ${q.title}',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: RadioGroup<String>(
                            groupValue: answers[q.id],
                            onChanged: (v) {
                              if (v == null) return;
                              onAnswer(q.id, v);
                            },
                            child: Column(
                              children: [
                                for (int i = 0; i < q.options.length; i++)
                                  Column(
                                    children: [
                                      RadioListTile<String>(
                                        value: q.options[i],
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                        title: Text(
                                          q.options[i],
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (i != q.options.length - 1)
                                        const Divider(height: 1),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: canContinue ? onNext : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00A8C6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  (questions.isNotEmpty && clampedIndex == questions.length - 1)
                      ? 'Continue'
                      : 'Next',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimateBuilderStep extends StatefulWidget {
  final String serviceType;
  final Map<String, double> quantities;
  final List<MaterialItem> materials;
  final TextEditingController Function(String materialName) controllerFor;
  final void Function(String materialName, double qty, {bool fromController})
  setQuantity;
  final double total;
  final double laborTotal;
  final bool laborIsManualOverride;
  final bool laborEnabled;
  final bool aiLaborBusy;
  final String? aiLaborSummary;
  final String? aiLaborAssumptions;
  final double? aiLaborHours;
  final double? aiLaborRate;
  final double? aiLaborConfidence;
  final String? aiLaborError;
  final void Function(double? value) onLaborOverride;
  final VoidCallback onAutoLabor;
  final double Function(double rate) calculateWithTax;
  final bool aiSuggesting;
  final Future<void> Function() suggestQuantitiesWithAi;
  final VoidCallback createInvoiceFromMaterials;
  final void Function({
    required String name,
    required String unit,
    required double price,
    required int quantity,
  })
  onAddCustomItem;
  final void Function(String id, double price) onUpdateCustomItemPrice;
  final Future<void> Function() onNext;

  const _EstimateBuilderStep({
    super.key,
    required this.serviceType,
    required this.quantities,
    required this.materials,
    required this.controllerFor,
    required this.setQuantity,
    required this.total,
    required this.laborTotal,
    required this.laborIsManualOverride,
    required this.laborEnabled,
    required this.aiLaborBusy,
    required this.aiLaborSummary,
    required this.aiLaborAssumptions,
    required this.aiLaborHours,
    required this.aiLaborRate,
    required this.aiLaborConfidence,
    required this.aiLaborError,
    required this.onLaborOverride,
    required this.onAutoLabor,
    required this.calculateWithTax,
    required this.aiSuggesting,
    required this.suggestQuantitiesWithAi,
    required this.createInvoiceFromMaterials,
    required this.onAddCustomItem,
    required this.onUpdateCustomItemPrice,
    required this.onNext,
  });

  @override
  State<_EstimateBuilderStep> createState() => _EstimateBuilderStepState();
}

class _EstimateBuilderStepState extends State<_EstimateBuilderStep> {
  static final NumberFormat _money = NumberFormat.currency(
    symbol: r'$',
    decimalDigits: 2,
  );

  static const Color _accent = Color(0xFF00A8C6);

  bool _sectionExpanded = true;
  bool _materialExpanded = true;
  bool _laborExpanded = false;

  String _fmtMoney(double v) => _money.format(v.isFinite ? v : 0);

  double _materialGroupTotal() {
    double total = 0;
    for (final item in widget.materials) {
      final qty = (widget.quantities[item.id] ?? 0.0);
      total += item.pricePerUnit * qty;
    }
    return total;
  }

  int _qtyInt(MaterialItem item) {
    final raw = widget.quantities[item.id] ?? 0.0;
    if (!raw.isFinite || raw <= 0) return 0;
    return raw.round();
  }

  Future<void> _editQuantity(MaterialItem item) async {
    final current = _qtyInt(item);
    final controller = TextEditingController(
      text: current > 0 ? '$current' : '',
    );
    final priceController = TextEditingController(
      text: item.pricePerUnit.toStringAsFixed(2),
    );

    final next = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      final v = int.tryParse(controller.text.trim()) ?? 0;
                      final next = (v - 1).clamp(0, 999);
                      controller.text = next == 0 ? '' : '$next';
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '0',
                        suffixText: item.unit,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final v = int.tryParse(controller.text.trim()) ?? 0;
                      final next = (v + 1).clamp(0, 999);
                      controller.text = next == 0 ? '' : '$next';
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              if (item.isCustom) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Unit price',
                    prefixText: r'$ ',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim()) ?? 0;
                final price =
                    double.tryParse(
                      priceController.text.trim().replaceAll(',', ''),
                    ) ??
                    item.pricePerUnit;
                Navigator.pop(context, {
                  'qty': v.clamp(0, 999),
                  'price': price,
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    priceController.dispose();
    if (!mounted || next == null) return;
    final qty = (next['qty'] as int?) ?? 0;
    final price = (next['price'] as num?)?.toDouble() ?? item.pricePerUnit;
    widget.setQuantity(item.id, qty.toDouble());
    if (item.isCustom) {
      widget.onUpdateCustomItemPrice(item.id, price);
    }
  }

  Future<void> _addCustomItem() async {
    final nameController = TextEditingController();
    final unitController = TextEditingController(text: 'unit');
    final priceController = TextEditingController();
    final qtyController = TextEditingController(text: '1');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit (e.g. gallon, box)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Unit price',
                  prefixText: r'$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Home Depot live prices are not connected yet. Enter price manually.',
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (!mounted || result != true) {
      nameController.dispose();
      unitController.dispose();
      priceController.dispose();
      qtyController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final unit = unitController.text.trim();
    final price = double.tryParse(priceController.text.trim()) ?? 0;
    final qty = int.tryParse(qtyController.text.trim()) ?? 0;

    nameController.dispose();
    unitController.dispose();
    priceController.dispose();
    qtyController.dispose();

    if (name.isEmpty || unit.isEmpty || price <= 0 || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter name, unit, price, and quantity.')),
      );
      return;
    }

    widget.onAddCustomItem(name: name, unit: unit, price: price, quantity: qty);
  }

  void _toggleAllSections() {
    final next = !(_sectionExpanded && _materialExpanded);
    setState(() {
      _sectionExpanded = next;
      _materialExpanded = next;
      if (!next) {
        _laborExpanded = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dividerColor = scheme.outlineVariant;
    final estimateTotal = widget.total;
    final materialTotal = _materialGroupTotal();
    final laborTotal = widget.laborTotal;
    final hasAi =
        (widget.aiLaborSummary?.trim().isNotEmpty ?? false) ||
        widget.aiLaborHours != null ||
        widget.aiLaborRate != null;
    final laborSubtitle = widget.laborIsManualOverride
        ? 'Custom labor total'
        : (hasAi ? 'AI-estimated labor total' : 'Auto-estimated labor total');

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 150),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Text(
                    'ESTIMATE TOTAL',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      border: Border.all(color: dividerColor),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      _fmtMoney(estimateTotal),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _toggleAllSections,
                        icon: const Icon(Icons.unfold_more, color: _accent),
                        label: const Text(
                          'Sections',
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: dividerColor),

                // Section header
                InkWell(
                  onTap: () =>
                      setState(() => _sectionExpanded = !_sectionExpanded),
                  child: Container(
                    color: const Color(0xFFEDEDED),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Center(
                            child: Icon(
                              _sectionExpanded ? Icons.remove : Icons.add,
                              size: 28,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${widget.serviceType} Materials',
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                        ),
                        Text(
                          _fmtMoney(materialTotal),
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_sectionExpanded) ...[
                  Divider(height: 1, thickness: 1, color: dividerColor),

                  // Labor group
                  InkWell(
                    onTap: () =>
                        setState(() => _laborExpanded = !_laborExpanded),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Row(
                        children: [
                          Icon(
                            _laborExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            color: scheme.onSurfaceVariant,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Labor',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            _fmtMoney(laborTotal),
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_laborExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            laborSubtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          if (widget.aiLaborBusy) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Estimating labor...'
                                  ' (this can take a few seconds)',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ],
                          if (widget.aiLaborError != null &&
                              widget.aiLaborError!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.aiLaborError!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.error),
                            ),
                          ],
                          if (hasAi) ...[
                            const SizedBox(height: 10),
                            Text(
                              [
                                if (widget.aiLaborHours != null)
                                  '${widget.aiLaborHours!.toStringAsFixed(1)} hrs',
                                if (widget.aiLaborRate != null)
                                  '${_fmtMoney(widget.aiLaborRate!)}/hr',
                                if (widget.aiLaborConfidence != null)
                                  '${(widget.aiLaborConfidence! * 100).round()}% confidence',
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            if (widget.aiLaborSummary != null &&
                                widget.aiLaborSummary!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                widget.aiLaborSummary!.trim(),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                            if (widget.aiLaborAssumptions != null &&
                                widget.aiLaborAssumptions!
                                    .trim()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                widget.aiLaborAssumptions!.trim(),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    widget.laborEnabled && !widget.aiLaborBusy
                                    ? widget.onAutoLabor
                                    : null,
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('AI estimate'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    widget.laborEnabled && !widget.aiLaborBusy
                                    ? () async {
                                        final controller =
                                            TextEditingController(
                                              text: laborTotal.toStringAsFixed(
                                                2,
                                              ),
                                            );
                                        final next = await showDialog<double>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              'Set labor total',
                                            ),
                                            content: TextField(
                                              controller: controller,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                prefixText: r'$ ',
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () {
                                                  final value =
                                                      double.tryParse(
                                                        controller.text
                                                            .trim()
                                                            .replaceAll(
                                                              ',',
                                                              '',
                                                            ),
                                                      ) ??
                                                      0;
                                                  Navigator.pop(context, value);
                                                },
                                                child: const Text('Save'),
                                              ),
                                            ],
                                          ),
                                        );
                                        controller.dispose();
                                        if (!mounted || next == null) return;
                                        widget.onLaborOverride(
                                          next <= 0 ? null : next,
                                        );
                                      }
                                    : null,
                                icon: const Icon(Icons.edit),
                                label: const Text('Set labor'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Divider(height: 1, thickness: 1, color: dividerColor),

                  // Material group
                  InkWell(
                    onTap: () =>
                        setState(() => _materialExpanded = !_materialExpanded),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Row(
                        children: [
                          Icon(
                            _materialExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            color: scheme.onSurfaceVariant,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Material',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            _fmtMoney(materialTotal),
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_materialExpanded) ...[
                    for (final item in widget.materials) ...[
                      Divider(height: 1, thickness: 1, color: dividerColor),
                      InkWell(
                        onTap: () => _editQuantity(item),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w900,
                                        height: 1.08,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_qtyInt(item)} x ${_fmtMoney(item.pricePerUnit)}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _fmtMoney(item.pricePerUnit * _qtyInt(item)),
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _addCustomItem,
                        child: const Text(
                          '+ Item',
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: OutlinedButton.icon(
                      onPressed: widget.aiSuggesting
                          ? null
                          : widget.suggestQuantitiesWithAi,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        side: BorderSide(color: dividerColor),
                        backgroundColor: scheme.surface,
                        foregroundColor: scheme.onSurface,
                      ),
                      icon: widget.aiSuggesting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, color: _accent),
                      label: Text(
                        widget.aiSuggesting ? 'Working…' : 'Edit with AI',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 80,
                    child: FilledButton(
                      onPressed: widget.total > 0 ? widget.onNext : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(44),
                        ),
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RenderPromptStep extends StatelessWidget {
  final VoidCallback onGenerate;
  final Future<void> Function() onNo;

  const _RenderPromptStep({
    super.key,
    required this.onGenerate,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Include a Project Render?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4B23A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'BETA',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Estimates with A.I renders\nwin 2x as often',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed: onGenerate,
                child: const Text(
                  'Generate Render',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onNo,
              child: Text(
                'No',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
