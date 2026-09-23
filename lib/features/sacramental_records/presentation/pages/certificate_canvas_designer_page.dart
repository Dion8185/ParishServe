import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/certificate_canvas_element.dart';
import '../../models/certificate_template_model.dart';
import '../../utils/placeholder_registry.dart';

class CertificateCanvasDesignerPage extends StatefulWidget {
  final CertificateTemplateModel template;

  const CertificateCanvasDesignerPage({super.key, required this.template});

  @override
  State<CertificateCanvasDesignerPage> createState() =>
      _CertificateCanvasDesignerPageState();
}

class _CertificateCanvasDesignerPageState
    extends State<CertificateCanvasDesignerPage> {
  late List<CertificateCanvasElement> _elements;
  String? _selectedElementId;

  // Preset Color Swatches for Canva Toolbar
  static const List<Map<String, dynamic>> _colorSwatches = [
    {'name': 'Dark Slate', 'hex': '#1E293B', 'color': Color(0xFF1E293B)},
    {'name': 'Marian Navy', 'hex': '#164E87', 'color': Color(0xFF164E87)},
    {'name': 'Eucharistic Gold', 'hex': '#D49B18', 'color': Color(0xFFD49B18)},
    {'name': 'Pentecost Red', 'hex': '#B91C1C', 'color': Color(0xFFB91C1C)},
    {'name': 'Pure Black', 'hex': '#000000', 'color': Colors.black},
  ];

  @override
  void initState() {
    super.initState();
    // Load existing canvas elements or initialize with canonical defaults
    if (widget.template.styleConfig.canvasElements.isNotEmpty) {
      _elements = widget.template.styleConfig.canvasElements
          .map((e) => e.copyWith())
          .toList();
    } else {
      _elements = _generateDefaultCanvasElements();
    }
  }

  /// Populates canonical default layout blocks if none exist
  List<CertificateCanvasElement> _generateDefaultCanvasElements() {
    final tpl = widget.template;
    return [
      // 1. Ecclesiastical Header Block
      CertificateCanvasElement(
        id: 'header_block',
        elementType: 'header',
        text: tpl.headerText,
        x: 0.5,
        y: 0.11,
        fontSize: 10.5,
        fontWeight: 'bold',
        fontFamily: tpl.styleConfig.fontFamily,
        colorHex: '#1E293B',
        textAlign: 'center',
      ),
      // 2. Certificate Title Banner
      CertificateCanvasElement(
        id: 'title_block',
        elementType: 'title',
        text: tpl.certificateTitle,
        x: 0.5,
        y: 0.22,
        fontSize: tpl.styleConfig.titleFontSize,
        fontWeight: 'bold',
        fontFamily: tpl.styleConfig.fontFamily,
        colorHex: '#164E87',
        textAlign: 'center',
      ),
      // 3. Narrative Body Text with Placeholders
      CertificateCanvasElement(
        id: 'body_block',
        elementType: 'text',
        text: tpl.bodyWording,
        x: 0.5,
        y: 0.48,
        fontSize: tpl.styleConfig.bodyFontSize,
        fontWeight: 'normal',
        fontFamily: tpl.styleConfig.fontFamily,
        colorHex: '#1E293B',
        textAlign: 'center',
      ),
      // 4. Signatory Block
      CertificateCanvasElement(
        id: 'signatory_block',
        elementType: 'signatory',
        text: '${tpl.signatoryName}\n${tpl.signatoryTitle}',
        x: 0.76,
        y: 0.86,
        fontSize: 10.0,
        fontWeight: 'bold',
        fontFamily: tpl.styleConfig.fontFamily,
        colorHex: '#1E293B',
        textAlign: 'center',
      ),
      // 5. QR Verification Block
      if (tpl.enableQrVerification)
        CertificateCanvasElement(
          id: 'qr_block',
          elementType: 'qr',
          text: 'QR Verification Token',
          x: 0.22,
          y: 0.86,
          fontSize: 8.0,
          fontWeight: 'normal',
          fontFamily: tpl.styleConfig.fontFamily,
          colorHex: '#64748B',
          textAlign: 'center',
        ),
    ];
  }

  CertificateCanvasElement? get _selectedElement {
    if (_selectedElementId == null) return null;
    try {
      return _elements.firstWhere((e) => e.id == _selectedElementId);
    } catch (_) {
      return null;
    }
  }

  void _updateSelectedElement(CertificateCanvasElement updated) {
    setState(() {
      final index = _elements.indexWhere((e) => e.id == updated.id);
      if (index != -1) {
        _elements[index] = updated;
      }
    });
  }

  void _addNewElement(String type, String defaultText, double defaultY, {double fontSize = 12.0, String fontWeight = 'normal', String colorHex = '#1E293B'}) {
    final newId = 'elem_${DateTime.now().millisecondsSinceEpoch}';
    final elem = CertificateCanvasElement(
      id: newId,
      elementType: type,
      text: defaultText,
      x: 0.5,
      y: defaultY,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: widget.template.styleConfig.fontFamily,
      colorHex: colorHex,
      textAlign: 'center',
    );

    setState(() {
      _elements.add(elem);
      _selectedElementId = newId;
    });
  }

  void _duplicateSelected() {
    final current = _selectedElement;
    if (current == null) return;

    final newId = 'elem_${DateTime.now().millisecondsSinceEpoch}';
    final clone = current.copyWith(
      id: newId,
      x: (current.x + 0.03).clamp(0.05, 0.95),
      y: (current.y + 0.03).clamp(0.05, 0.95),
    );

    setState(() {
      _elements.add(clone);
      _selectedElementId = newId;
    });
  }

  void _deleteSelected() {
    if (_selectedElementId == null) return;
    setState(() {
      _elements.removeWhere((e) => e.id == _selectedElementId);
      _selectedElementId = null;
    });
  }

  Future<void> _openTextEditorModal(CertificateCanvasElement element) async {
    final controller = TextEditingController(text: element.text);
    final availablePlaceholders =
    PlaceholderRegistry.getPlaceholdersFor(widget.template.sacramentType);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Element Text & Placeholders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Dynamic Placeholders:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: availablePlaceholders.map((tag) {
                      return ActionChip(
                        label: Text(tag, style: const TextStyle(fontSize: 11)),
                        backgroundColor: ParishColors.goldLight,
                        onPressed: () {
                          final text = controller.text;
                          controller.text = '$text $tag';
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: controller,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Text Content',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
              onPressed: () {
                _updateSelectedElement(element.copyWith(text: controller.text));
                Navigator.pop(ctx);
              },
              child: const Text('Apply Text'),
            ),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF1E293B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    // Calculate aspect ratio for the paper sheet (A4 = 1 / 1.414, Letter = 8.5 / 11)
    double aspectRatio = 1 / 1.414;
    if (widget.template.paperSize == 'Letter') aspectRatio = 8.5 / 11;
    if (widget.template.paperSize == 'Legal') aspectRatio = 8.5 / 14;
    if (widget.template.orientation == 'Landscape') aspectRatio = 1 / aspectRatio;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Canva-style dark studio workspace
      appBar: AppBar(
        backgroundColor: cardWhite,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.close, color: textDark),
          tooltip: 'Discard Changes & Exit Designer',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('VISUAL DESIGNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                ),
                const SizedBox(width: 8),
                Text(widget.template.templateName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
              ],
            ),
            Text('${widget.template.sacramentType} • ${widget.template.paperSize} (${widget.template.orientation})', style: TextStyle(fontSize: 11, color: textMuted)),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: textMuted),
            onPressed: () => setState(() => _elements = _generateDefaultCanvasElements()),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Reset Layout', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.oliveGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                // Return updated canvas elements back to the template editor
                Navigator.pop(context, _elements);
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Apply Canvas Design', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. TOP FLOATING CANVA-STYLE CONTEXTUAL TOOLBAR
          _buildCanvaContextualToolbar(),

          // 2. MAIN VISUAL CANVAS WORKSPACE
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedElementId = null), // Deselect on background tap
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final canvasWidth = constraints.maxWidth;
                          final canvasHeight = constraints.maxHeight;

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Decorative Background / Border layer
                              _buildCanvasBorderBackground(canvasWidth, canvasHeight),

                              // Interactive Draggable Canvas Elements
                              ..._elements.map((element) {
                                return _buildInteractiveDraggableElement(
                                  element: element,
                                  canvasWidth: canvasWidth,
                                  canvasHeight: canvasHeight,
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. BOTTOM FLOATING "ADD ELEMENT" PALETTE
          _buildBottomElementPalette(),
        ],
      ),
    );
  }

  // ===========================================================================
  // Top Canva-Style Contextual Tooling
  // ===========================================================================

  Widget _buildCanvaContextualToolbar() {
    final selected = _selectedElement;
    final textDark = ParishColors.textDark;

    if (selected == null) {
      return Container(
        height: 52,
        width: double.infinity,
        color: ParishColors.cardWhite,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        child: const Row(
          children: [
            Icon(Icons.touch_app, size: 18, color: ParishColors.marianBlue),
            SizedBox(width: 8),
            Text(
              'Click any element on the certificate paper below to adjust font, size, weight, color, or drag it.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        border: Border(bottom: BorderSide(color: ParishColors.borderGrey)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Edit Text Content Button
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: ParishColors.marianBlue),
            onPressed: () => _openTextEditorModal(selected),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit Text / Placeholders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const VerticalDivider(width: 20, indent: 12, endIndent: 12),

          // Font Family Dropdown
          DropdownButton<String>(
            value: selected.fontFamily,
            underline: const SizedBox.shrink(),
            style: TextStyle(fontSize: 12.5, color: textDark, fontWeight: FontWeight.w600),
            items: const [
              DropdownMenuItem(value: 'serif', child: Text('Times (Serif)')),
              DropdownMenuItem(value: 'sans', child: Text('Helvetica (Sans)')),
              DropdownMenuItem(value: 'courier', child: Text('Courier (Typewriter)')),
            ],
            onChanged: (val) {
              if (val != null) _updateSelectedElement(selected.copyWith(fontFamily: val));
            },
          ),
          const VerticalDivider(width: 20, indent: 12, endIndent: 12),

          // Font Size Stepper: [-] 12pt [+]
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                tooltip: 'Decrease font size',
                onPressed: selected.fontSize > 7.0
                    ? () => _updateSelectedElement(selected.copyWith(fontSize: selected.fontSize - 1.0))
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: ParishColors.borderGrey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${selected.fontSize.toInt()} pt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                tooltip: 'Increase font size',
                onPressed: selected.fontSize < 32.0
                    ? () => _updateSelectedElement(selected.copyWith(fontSize: selected.fontSize + 1.0))
                    : null,
              ),
            ],
          ),
          const VerticalDivider(width: 20, indent: 12, endIndent: 12),

          // Bold Weight Toggle: [B]
          IconButton(
            icon: Icon(
              Icons.format_bold,
              color: selected.isBold ? ParishColors.marianBlue : Colors.grey,
            ),
            tooltip: 'Toggle Bold',
            onPressed: () {
              _updateSelectedElement(
                selected.copyWith(fontWeight: selected.isBold ? 'normal' : 'bold'),
              );
            },
          ),

          // Alignment Toggles
          IconButton(
            icon: Icon(Icons.format_align_left, color: selected.textAlign == 'left' ? ParishColors.marianBlue : Colors.grey, size: 18),
            onPressed: () => _updateSelectedElement(selected.copyWith(textAlign: 'left')),
          ),
          IconButton(
            icon: Icon(Icons.format_align_center, color: selected.textAlign == 'center' ? ParishColors.marianBlue : Colors.grey, size: 18),
            onPressed: () => _updateSelectedElement(selected.copyWith(textAlign: 'center')),
          ),
          IconButton(
            icon: Icon(Icons.format_align_right, color: selected.textAlign == 'right' ? ParishColors.marianBlue : Colors.grey, size: 18),
            onPressed: () => _updateSelectedElement(selected.copyWith(textAlign: 'right')),
          ),
          const VerticalDivider(width: 20, indent: 12, endIndent: 12),

          // Color Swatches
          Row(
            children: _colorSwatches.map((item) {
              final color = item['color'] as Color;
              final hex = item['hex'] as String;
              final isChosen = selected.colorHex == hex;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => _updateSelectedElement(selected.copyWith(colorHex: hex)),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isChosen ? Colors.cyanAccent : Colors.grey.shade300,
                        width: isChosen ? 2.5 : 1.0,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const VerticalDivider(width: 20, indent: 12, endIndent: 12),

          // Duplicate & Delete
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Duplicate Element',
            onPressed: _duplicateSelected,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: ParishColors.mercyRed, size: 18),
            tooltip: 'Delete Element',
            onPressed: _deleteSelected,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Interactive Canvas Draggable Element
  // ===========================================================================

  Widget _buildInteractiveDraggableElement({
    required CertificateCanvasElement element,
    required double canvasWidth,
    required double canvasHeight,
  }) {
    final isSelected = element.id == _selectedElementId;
    final textColor = _hexToColor(element.colorHex);

    // Pixel coordinates derived from normalized (0.0 to 1.0) values
    final pixelX = element.x * canvasWidth;
    final pixelY = element.y * canvasHeight;

    TextAlign align;
    switch (element.textAlign) {
      case 'left':
        align = TextAlign.left;
        break;
      case 'right':
        align = TextAlign.right;
        break;
      case 'center':
      default:
        align = TextAlign.center;
        break;
    }

    return Positioned(
      left: pixelX - (canvasWidth * 0.4), // Center-anchor horizontal bounding box
      top: pixelY - 14,
      width: canvasWidth * 0.8,
      child: GestureDetector(
        onTap: () => setState(() => _selectedElementId = element.id),
        onPanUpdate: (details) {
          // Compute delta relative to canvas size to update normalized coordinates
          final deltaX = details.delta.dx / canvasWidth;
          final deltaY = details.delta.dy / canvasHeight;

          final newX = (element.x + deltaX).clamp(0.1, 0.9);
          final newY = (element.y + deltaY).clamp(0.05, 0.95);

          _updateSelectedElement(element.copyWith(x: newX, y: newY));
        },
        child: Container(
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: const Color(0xFF0284C7), width: 1.8) // Canva Blue highlight
                : Border.all(color: Colors.transparent),
            borderRadius: BorderRadius.circular(4),
            color: isSelected ? const Color(0xFF0284C7).withOpacity(0.04) : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (element.elementType == 'header')
                _buildHeaderDisplay(element, textColor, align)
              else if (element.elementType == 'qr')
                _buildQrPlaceholderDisplay(element, textColor)
              else if (element.elementType == 'signatory')
                  _buildSignatoryPlaceholderDisplay(element, textColor)
                else
                  Text(
                    element.text,
                    textAlign: align,
                    style: TextStyle(
                      fontSize: element.fontSize * (canvasWidth / 595.0), // Responsive font scaling
                      fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
                      fontFamily: element.fontFamily == 'courier' ? 'monospace' : null,
                      color: textColor,
                      height: 1.3,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderDisplay(CertificateCanvasElement element, Color color, TextAlign align) {
    return Column(
      children: [
        const Text('Diocese of San Pablo', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        const Text('Saint John Paul II Parish', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
        const Text('Santa Cruz, Laguna', style: TextStyle(fontSize: 8.5, color: Colors.grey)),
      ],
    );
  }

  Widget _buildQrPlaceholderDisplay(CertificateCanvasElement element, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
          child: const Icon(Icons.qr_code, size: 36, color: ParishColors.marianBlue),
        ),
        const SizedBox(height: 2),
        const Text('QR VERIFICATION', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSignatoryPlaceholderDisplay(CertificateCanvasElement element, Color color) {
    return Column(
      children: [
        Container(width: 120, height: 1, color: Colors.black54),
        const SizedBox(height: 2),
        Text(element.text, textAlign: TextAlign.center, style: TextStyle(fontSize: element.fontSize * 0.8, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildCanvasBorderBackground(double width, double height) {
    if (widget.template.backgroundImageUrl != null &&
        widget.template.backgroundImageUrl!.isNotEmpty) {
      return Positioned.fill(
        child: Image.network(
          widget.template.backgroundImageUrl!,
          fit: widget.template.backgroundMode == 'Full-Page'
              ? BoxFit.cover
              : BoxFit.fill,
          errorBuilder: (_, __, ___) => _buildClassicalVectorFrame(),
        ),
      );
    }
    return _buildClassicalVectorFrame();
  }

  Widget _buildClassicalVectorFrame() {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: ParishColors.goldAccent, width: 2.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: ParishColors.marianBlue, width: 1.0),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Bottom Element Palette (+ Add Text, + Add Placeholders)
  // ===========================================================================

  Widget _buildBottomElementPalette() {
    return Container(
      height: 60,
      width: double.infinity,
      color: ParishColors.cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAddElementChip(
            icon: Icons.title,
            label: '+ Title Banner',
            onTap: () => _addNewElement('title', 'CERTIFICATE OF ${widget.template.sacramentType.toUpperCase()}', 0.22, fontSize: 18, fontWeight: 'bold', colorHex: '#164E87'),
          ),
          const SizedBox(width: 8),
          _buildAddElementChip(
            icon: Icons.text_fields,
            label: '+ Text Box',
            onTap: () => _addNewElement('text', 'This is to certify that...', 0.50, fontSize: 12),
          ),
          const SizedBox(width: 8),
          _buildAddElementChip(
            icon: Icons.person_pin,
            label: '+ {Full Name}',
            onTap: () => _addNewElement('placeholder', '{Full Name}', 0.35, fontSize: 16, fontWeight: 'bold', colorHex: '#164E87'),
          ),
          const SizedBox(width: 8),
          _buildAddElementChip(
            icon: Icons.draw,
            label: '+ Signatory Block',
            onTap: () => _addNewElement('signatory', '${widget.template.signatoryName}\n${widget.template.signatoryTitle}', 0.85, fontSize: 10, fontWeight: 'bold'),
          ),
          const SizedBox(width: 8),
          _buildAddElementChip(
            icon: Icons.qr_code,
            label: '+ QR Verification Token',
            onTap: () => _addNewElement('qr', 'QR Verification Token', 0.85, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildAddElementChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: ParishColors.marianBlue),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
      backgroundColor: ParishColors.marianBlueSurface,
      side: BorderSide(color: ParishColors.marianBlue.withOpacity(0.3)),
      onPressed: onTap,
    );
  }
}