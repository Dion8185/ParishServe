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
  final TransformationController _transformationController = TransformationController();

  // 8 Canonical & Decorative Font Options
  static const List<Map<String, String>> _availableFonts = [
    {'id': 'serif', 'name': 'Times / Classical Serif'},
    {'id': 'sans', 'name': 'Helvetica / Modern Sans'},
    {'id': 'courier', 'name': 'Courier / Typewriter'},
    {'id': 'georgia', 'name': 'Georgia / Editorial'},
    {'id': 'garamond', 'name': 'Garamond / Traditional'},
    {'id': 'cinzel', 'name': 'Roman Inscription (Cinzel)'},
    {'id': 'script', 'name': 'Chancery Script (Cursive)'},
    {'id': 'trebuchet', 'name': 'Trebuchet / Display Sans'},
  ];

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
    if (widget.template.styleConfig.canvasElements.isNotEmpty) {
      _elements = widget.template.styleConfig.canvasElements
          .map((e) => e.copyWith())
          .toList();
    } else {
      _elements = _generateDefaultCanvasElements();
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  /// Resolves standard physical page dimensions in PostScript points
  Size _getPageDimensions() {
    double width = 595.28; // Standard A4 points
    double height = 841.89;

    if (widget.template.paperSize == 'Letter') {
      width = 612.0;
      height = 792.0;
    } else if (widget.template.paperSize == 'Legal') {
      width = 612.0;
      height = 1008.0;
    }

    if (widget.template.orientation == 'Landscape') {
      return Size(height, width);
    }
    return Size(width, height);
  }

  /// Populates canonical default layout blocks with 1:1 matching normalized coordinates
  List<CertificateCanvasElement> _generateDefaultCanvasElements() {
    final tpl = widget.template;
    return [
      CertificateCanvasElement(
        id: 'header_block',
        elementType: 'header',
        text: tpl.headerText,
        x: 0.5,
        y: 0.12,
        width: 0.84,
        fontSize: 11.0,
        fontWeight: 'bold',
        fontFamily: tpl.styleConfig.fontFamily,
        colorHex: '#1E293B',
        textAlign: 'center',
      ),
      CertificateCanvasElement(
        id: 'title_block',
        elementType: 'title',
        text: tpl.certificateTitle,
        x: 0.5,
        y: 0.23,
        width: 0.60,
        fontSize: tpl.styleConfig.titleFontSize,
        fontWeight: 'bold',
        fontFamily: tpl.styleConfig.fontFamily,
        colorHex: '#164E87',
        textAlign: 'center',
      ),
      CertificateCanvasElement(
        id: 'body_block',
        elementType: 'text',
        text: tpl.bodyWording,
        x: 0.5,
        y: 0.50,
        width: 0.84,
        fontSize: tpl.styleConfig.bodyFontSize,
        fontWeight: 'normal',
        fontFamily: tpl.styleConfig.fontFamily,
        colorHex: '#1E293B',
        textAlign: 'center',
      ),
      CertificateCanvasElement(
        id: 'signatory_block',
        elementType: 'signatory',
        text: '${tpl.signatoryName}\n${tpl.signatoryTitle}',
        x: 0.76,
        y: 0.86,
        width: 0.34,
        fontSize: 10.5,
        fontWeight: 'bold',
        fontFamily: tpl.styleConfig.fontFamily,
        colorHex: '#1E293B',
        textAlign: 'center',
      ),
      if (tpl.enableQrVerification)
        CertificateCanvasElement(
          id: 'qr_block',
          elementType: 'qr',
          text: 'QR Verification Token',
          x: 0.22,
          y: 0.86,
          width: 0.18,
          fontSize: 8.0,
          fontWeight: 'normal',
          fontFamily: tpl.styleConfig.fontFamily,
          colorHex: '#64748B',
          textAlign: 'center',
        ),
      // Default independent Parish Seal positioned in lower canvas
      CertificateCanvasElement(
        id: 'parish_seal_elem',
        elementType: 'parish_seal',
        text: 'Parish Seal',
        x: 0.50,
        y: 0.86,
        width: 0.15,
        fontSize: 16.0, // Multiplied by 4.5 = 72pt diameter
        fontWeight: 'bold',
        fontFamily: 'serif',
        colorHex: '#D49B18',
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

  void _addNewElement(
      String type,
      String defaultText,
      double defaultY, {
        double defaultX = 0.5,
        double? width,
        double fontSize = 12.0,
        String fontWeight = 'normal',
        String colorHex = '#1E293B',
      }) {
    final newId = 'elem_${DateTime.now().millisecondsSinceEpoch}';
    final elem = CertificateCanvasElement(
      id: newId,
      elementType: type,
      text: defaultText,
      x: defaultX,
      y: defaultY,
      width: width ?? (type.contains('seal') ? 0.15 : 0.84),
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
      x: (current.x + 0.03).clamp(0.08, 0.92),
      y: (current.y + 0.03).clamp(0.06, 0.94),
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
                  const SizedBox(height: 8),
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

  /// Resolves true cross-platform font families for 1:1 canvas-to-PDF rendering
  TextStyle _resolveCanvasTextStyle({
    required CertificateCanvasElement element,
    required Color textColor,
  }) {
    String? fontFamily;
    List<String>? fontFallback;
    FontStyle fontStyle = FontStyle.normal;
    double letterSpacing = 0.0;

    switch (element.fontFamily.toLowerCase()) {
      case 'sans':
        fontFamily = 'Arial';
        fontFallback = const ['Helvetica', 'Roboto', 'sans-serif'];
        break;
      case 'courier':
        fontFamily = 'Courier New';
        fontFallback = const ['Courier', 'monospace'];
        break;
      case 'georgia':
        fontFamily = 'Georgia';
        fontFallback = const ['Times New Roman', 'serif'];
        break;
      case 'garamond':
        fontFamily = 'Garamond';
        fontFallback = const ['Baskerville', 'Times New Roman', 'serif'];
        break;
      case 'cinzel':
        fontFamily = 'Palatino Linotype';
        fontFallback = const ['Palatino', 'Book Antiqua', 'serif'];
        letterSpacing = 2.0;
        break;
      case 'script':
        fontFamily = 'Brush Script MT';
        fontFallback = const ['Zapfino', 'cursive'];
        fontStyle = FontStyle.italic;
        break;
      case 'trebuchet':
        fontFamily = 'Trebuchet MS';
        fontFallback = const ['Arial', 'sans-serif'];
        break;
      case 'serif':
      default:
        fontFamily = 'Times New Roman';
        fontFallback = const ['Times', 'Georgia', 'serif'];
        break;
    }

    return TextStyle(
      fontSize: element.fontSize,
      fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      color: textColor,
      height: 1.35,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final pageSize = _getPageDimensions();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: cardWhite,
            elevation: 1,
            leading: IconButton(
              icon: Icon(Icons.close, color: textDark),
              tooltip: 'Discard & Exit',
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ParishColors.marianBlueSurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('1:1 CANVA STUDIO', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.template.templateName,
                        style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold, color: textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text('${widget.template.sacramentType} • ${widget.template.paperSize} (${widget.template.orientation}) • True 1:1 Points', style: TextStyle(fontSize: 11, color: textMuted)),
              ],
            ),
            actions: [
              if (!isMobile)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: textMuted),
                  onPressed: () => setState(() => _elements = _generateDefaultCanvasElements()),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset Layout', style: TextStyle(fontSize: 12)),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.oliveGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context, _elements),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(isMobile ? 'Apply' : 'Apply Canvas Design', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // 1. Contextual Formatting Toolbar
                _buildCanvaContextualToolbar(isMobile: isMobile),

                // 2. Exact 1:1 Point-Scalable Canvas Workspace
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedElementId = null),
                    child: LayoutBuilder(
                      builder: (context, workspaceConstraints) {
                        final availableWidth = workspaceConstraints.maxWidth - (isMobile ? 16 : 48);
                        final availableHeight = workspaceConstraints.maxHeight - (isMobile ? 16 : 48);
                        final pageAspectRatio = pageSize.width / pageSize.height;

                        double displayedWidth;
                        double displayedHeight;

                        if (availableWidth / availableHeight > pageAspectRatio) {
                          displayedHeight = availableHeight;
                          displayedWidth = availableHeight * pageAspectRatio;
                        } else {
                          displayedWidth = availableWidth;
                          displayedHeight = availableWidth / pageAspectRatio;
                        }

                        // Exact scaling ratio between screen pixels and PDF points
                        final double scaleFactor = displayedWidth / pageSize.width;

                        return InteractiveViewer(
                          transformationController: _transformationController,
                          panEnabled: _selectedElementId == null,
                          scaleEnabled: true,
                          minScale: 0.5,
                          maxScale: 3.5,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Container(
                                width: pageSize.width,
                                height: pageSize.height,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.55),
                                      blurRadius: 28,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Decorative Border matching exact PDF padding
                                    _buildCanvasBorderBackground(pageSize.width, pageSize.height),

                                    // Interactive Draggable Elements in Point Coordinates
                                    ..._elements.map((element) {
                                      return _buildInteractiveDraggableElement(
                                        element: element,
                                        pageWidth: pageSize.width,
                                        pageHeight: pageSize.height,
                                        scaleFactor: scaleFactor,
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 3. Element Palette with Independent Parish & Diocese Seals
                _buildBottomElementPalette(isMobile: isMobile),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Contextual Formatting Toolbar
  // ===========================================================================

  Widget _buildCanvaContextualToolbar({required bool isMobile}) {
    final selected = _selectedElement;
    final textDark = ParishColors.textDark;

    if (selected == null) {
      return Container(
        height: 48,
        width: double.infinity,
        color: ParishColors.cardWhite,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.touch_app, size: 18, color: ParishColors.marianBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMobile
                    ? 'Tap any item to move, resize, or change font.'
                    : 'Click any element to format its font, point size, bold weight, color, or drag its position freely.',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    final bool isSeal = selected.elementType.contains('seal');

    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        border: Border(bottom: BorderSide(color: ParishColors.borderGrey)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          if (!isSeal && selected.elementType != 'header' && selected.elementType != 'qr') ...[
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: ParishColors.marianBlue,
                minimumSize: const Size(44, 44),
              ),
              onPressed: () => _openTextEditorModal(selected),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const VerticalDivider(width: 16, indent: 10, endIndent: 10),

            // Font Selector with All 8 Working Options
            DropdownButton<String>(
              value: _availableFonts.any((f) => f['id'] == selected.fontFamily)
                  ? selected.fontFamily
                  : 'serif',
              underline: const SizedBox.shrink(),
              style: TextStyle(fontSize: 12, color: textDark, fontWeight: FontWeight.w600),
              items: _availableFonts.map((f) {
                return DropdownMenuItem<String>(
                  value: f['id'],
                  child: Text(f['name']!),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) _updateSelectedElement(selected.copyWith(fontFamily: val));
              },
            ),
            const VerticalDivider(width: 16, indent: 10, endIndent: 10),
          ],

          // Resizing Stepper [-] Size [+]
          Row(
            children: [
              Text(
                isSeal ? 'Seal Diameter: ' : 'Font Size: ',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                tooltip: 'Decrease size',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: selected.fontSize > 6.0
                    ? () => _updateSelectedElement(selected.copyWith(fontSize: selected.fontSize - (isSeal ? 2.0 : 1.0)))
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: ParishColors.borderGrey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isSeal
                      ? '${(selected.fontSize * 4.5).toInt()} pt'
                      : '${selected.fontSize.toInt()} pt',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                tooltip: 'Increase size',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: selected.fontSize < 44.0
                    ? () => _updateSelectedElement(selected.copyWith(fontSize: selected.fontSize + (isSeal ? 2.0 : 1.0)))
                    : null,
              ),
            ],
          ),
          const VerticalDivider(width: 16, indent: 10, endIndent: 10),

          if (!isSeal && selected.elementType != 'header' && selected.elementType != 'qr') ...[
            IconButton(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(
                Icons.format_bold,
                color: selected.isBold ? ParishColors.marianBlue : Colors.grey,
              ),
              tooltip: 'Toggle Bold',
              onPressed: () {
                _updateSelectedElement(selected.copyWith(fontWeight: selected.isBold ? 'normal' : 'bold'));
              },
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(Icons.format_align_left, color: selected.textAlign == 'left' ? ParishColors.marianBlue : Colors.grey, size: 18),
              onPressed: () => _updateSelectedElement(selected.copyWith(textAlign: 'left')),
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(Icons.format_align_center, color: selected.textAlign == 'center' ? ParishColors.marianBlue : Colors.grey, size: 18),
              onPressed: () => _updateSelectedElement(selected.copyWith(textAlign: 'center')),
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(Icons.format_align_right, color: selected.textAlign == 'right' ? ParishColors.marianBlue : Colors.grey, size: 18),
              onPressed: () => _updateSelectedElement(selected.copyWith(textAlign: 'right')),
            ),
            const VerticalDivider(width: 16, indent: 10, endIndent: 10),
          ],

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
                    width: 24,
                    height: 24,
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
          const VerticalDivider(width: 16, indent: 10, endIndent: 10),

          IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Duplicate Element',
            onPressed: _duplicateSelected,
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(Icons.delete_outline, color: ParishColors.mercyRed, size: 18),
            tooltip: 'Delete Element',
            onPressed: _deleteSelected,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1:1 Unified Interactive Element Renderer
  // ===========================================================================

  Widget _buildInteractiveDraggableElement({
    required CertificateCanvasElement element,
    required double pageWidth,
    required double pageHeight,
    required double scaleFactor,
  }) {
    final isSelected = element.id == _selectedElementId;
    final textColor = _hexToColor(element.colorHex);

    final double elementWidth = (element.width ?? 0.84) * pageWidth;
    final double pixelCenterX = element.x * pageWidth;
    final double pixelCenterY = element.y * pageHeight;

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

    Widget contentWidget;
    if (element.elementType == 'header') {
      contentWidget = _buildHeaderDisplay(element, textColor, align);
    } else if (element.elementType == 'qr') {
      contentWidget = _buildQrPlaceholderDisplay();
    } else if (element.elementType == 'signatory') {
      contentWidget = _buildSignatoryPlaceholderDisplay(element, textColor);
    } else if (element.elementType == 'parish_seal') {
      contentWidget = _buildIndividualSealDisplay(
        isParish: true,
        element: element,
        color: textColor,
      );
    } else if (element.elementType == 'diocese_seal') {
      contentWidget = _buildIndividualSealDisplay(
        isParish: false,
        element: element,
        color: textColor,
      );
    } else if (element.elementType == 'title') {
      contentWidget = _buildTitleBannerDisplay(element, textColor);
    } else {
      contentWidget = Text(
        element.text,
        textAlign: align,
        style: _resolveCanvasTextStyle(
          element: element,
          textColor: textColor,
        ),
      );
    }

    final double sealSize = element.fontSize * 4.5;
    final bool isSeal = element.elementType.contains('seal');

    return Positioned(
      left: isSeal ? pixelCenterX - (sealSize / 2) : pixelCenterX - (elementWidth / 2),
      top: isSeal ? pixelCenterY - (sealSize / 2) : pixelCenterY - 18,
      width: isSeal ? sealSize : elementWidth,
      child: GestureDetector(
        onTap: () => setState(() => _selectedElementId = element.id),
        onPanUpdate: (details) {
          // Adjust by scaleFactor so pointer tracking matches screen movement
          final deltaX = (details.delta.dx / scaleFactor) / pageWidth;
          final deltaY = (details.delta.dy / scaleFactor) / pageHeight;

          final newX = (element.x + deltaX).clamp(0.06, 0.94);
          final newY = (element.y + deltaY).clamp(0.05, 0.95);

          _updateSelectedElement(element.copyWith(x: newX, y: newY));
        },
        child: Container(
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: const Color(0xFF0284C7), width: 2.0)
                : Border.all(color: Colors.transparent),
            borderRadius: BorderRadius.circular(4),
            color: isSelected ? const Color(0xFF0284C7).withOpacity(0.06) : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: contentWidget,
        ),
      ),
    );
  }

  Widget _buildTitleBannerDisplay(CertificateCanvasElement element, Color color) {
    return Column(
      children: [
        Container(
          width: 340,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: ParishColors.goldAccent, width: 2.0)),
          ),
          child: Text(
            element.text.toUpperCase(),
            textAlign: TextAlign.center,
            style: _resolveCanvasTextStyle(
              element: element,
              textColor: color,
            ).copyWith(letterSpacing: 2.0),
          ),
        ),
      ],
    );
  }

  /// Independent Draggable & Resizable Seal Element (Parish or Diocese)
  Widget _buildIndividualSealDisplay({
    required bool isParish,
    required CertificateCanvasElement element,
    required Color color,
  }) {
    final double diameter = element.fontSize * 4.5;
    final tpl = widget.template;
    final imageUrl = isParish ? tpl.parishSealUrl : tpl.dioceseLogoUrl;
    final fallbackLabel = isParish ? 'SJP2' : 'DSP';
    final sealTitle = isParish ? 'PARISH SEAL' : 'DIOCESE EMBLEM';

    return Center(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: color, width: 2.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(3.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.65), width: 1.0),
            ),
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? ClipOval(child: Image.network(imageUrl, fit: BoxFit.contain))
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isParish ? Icons.church : Icons.shield, size: diameter * 0.32, color: color),
                const SizedBox(height: 1),
                Text(
                  fallbackLabel,
                  style: TextStyle(
                    fontSize: diameter * 0.16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  sealTitle,
                  style: TextStyle(
                    fontSize: diameter * 0.08,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderDisplay(CertificateCanvasElement element, Color color, TextAlign align) {
    final tpl = widget.template;
    final lines = tpl.headerLines;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (tpl.showDioceseLogo)
          SizedBox(
            width: 58,
            height: 58,
            child: (tpl.dioceseLogoUrl != null && tpl.dioceseLogoUrl!.isNotEmpty)
                ? Image.network(tpl.dioceseLogoUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _buildFallbackBadge('DSP'))
                : _buildFallbackBadge('DSP'),
          )
        else
          const SizedBox(width: 58),

        Expanded(
          child: Column(
            children: [
              Text(
                lines.isNotEmpty ? lines[0] : 'Diocese of San Pablo',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.8),
              ),
              const SizedBox(height: 3),
              Text(
                lines.length > 1 ? lines[1] : 'Saint John Paul II Parish',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: ParishColors.marianBlue, letterSpacing: 0.5),
              ),
              const SizedBox(height: 3),
              Text(
                lines.length > 2 ? lines.sublist(2).join(', ') : 'Santa Cruz, Laguna',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9.5, color: Colors.black54),
              ),
            ],
          ),
        ),

        if (tpl.showParishSeal)
          SizedBox(
            width: 58,
            height: 58,
            child: (tpl.parishSealUrl != null && tpl.parishSealUrl!.isNotEmpty)
                ? Image.network(tpl.parishSealUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _buildFallbackBadge('SJP2'))
                : _buildFallbackBadge('SJP2'),
          )
        else
          const SizedBox(width: 58),
      ],
    );
  }

  Widget _buildFallbackBadge(String label) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ParishColors.goldAccent, width: 1.5),
        color: Colors.grey.shade100,
      ),
      child: Center(
        child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
      ),
    );
  }

  Widget _buildQrPlaceholderDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.qr_code_2, size: 48, color: ParishColors.marianBlue),
        ),
        const SizedBox(height: 3),
        const Text('QR VERIFICATION', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSignatoryPlaceholderDisplay(CertificateCanvasElement element, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(width: 180, height: 1.2, color: Colors.black87),
        const SizedBox(height: 4),
        Text(
          element.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: element.fontSize,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.2,
          ),
        ),
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
        padding: const EdgeInsets.all(16.0), // Matches exact 16pt PDF margin
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: ParishColors.goldAccent, width: 2.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5.0), // Matches exact 5pt inner PDF offset
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
  // Bottom Element Palette with Independent Parish and Diocese Seal Chips
  // ===========================================================================

  Widget _buildBottomElementPalette({required bool isMobile}) {
    return Container(
      height: 56,
      width: double.infinity,
      color: ParishColors.cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildAddElementChip(
            icon: Icons.title,
            label: '+ Title Banner',
            onTap: () => _addNewElement('title', 'CERTIFICATE OF ${widget.template.sacramentType.toUpperCase()}', 0.23, width: 0.60, fontSize: 18, fontWeight: 'bold', colorHex: '#164E87'),
          ),
          const SizedBox(width: 8),
          _buildAddElementChip(
            icon: Icons.text_fields,
            label: '+ Text Box',
            onTap: () => _addNewElement('text', 'This is to certify that...', 0.50, width: 0.84, fontSize: 12),
          ),
          const SizedBox(width: 8),
          _buildAddElementChip(
            icon: Icons.person_pin,
            label: '+ {Full Name}',
            onTap: () => _addNewElement('placeholder', '{Full Name}', 0.36, width: 0.65, fontSize: 16, fontWeight: 'bold', colorHex: '#164E87'),
          ),
          const SizedBox(width: 8),
          // INDEPENDENT PARISH SEAL
          _buildAddElementChip(
            icon: Icons.verified,
            label: '+ Parish Seal',
            onTap: () => _addNewElement('parish_seal', 'Parish Seal', 0.86, defaultX: 0.50, width: 0.15, fontSize: 16, colorHex: '#D49B18'),
          ),
          const SizedBox(width: 8),
          // INDEPENDENT DIOCESE SEAL
          _buildAddElementChip(
            icon: Icons.shield,
            label: '+ Diocese Seal',
            onTap: () => _addNewElement('diocese_seal', 'Diocese Seal', 0.86, defaultX: 0.20, width: 0.15, fontSize: 16, colorHex: '#164E87'),
          ),
          const SizedBox(width: 8),
          _buildAddElementChip(
            icon: Icons.draw,
            label: '+ Signatory Block',
            onTap: () => _addNewElement('signatory', '${widget.template.signatoryName}\n${widget.template.signatoryTitle}', 0.86, defaultX: 0.76, width: 0.34, fontSize: 10.5, fontWeight: 'bold'),
          ),
          const SizedBox(width: 8),
          _buildAddElementChip(
            icon: Icons.qr_code,
            label: '+ QR Verification Token',
            onTap: () => _addNewElement('qr', 'QR Verification Token', 0.86, defaultX: 0.22, width: 0.18, fontSize: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onPressed: onTap,
    );
  }
}