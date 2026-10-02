import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/certificate_canvas_element.dart';
import '../../models/certificate_template_model.dart';
import '../../utils/placeholder_registry.dart';

enum CanvasToolMode { select, pan }
enum MobileToolPanel { none, size, format, color, font, nudge }

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
  late String _backgroundMode;
  late String _globalFontFamily;
  String? _selectedElementId;
  CanvasToolMode _toolMode = CanvasToolMode.select;
  MobileToolPanel _activeMobilePanel = MobileToolPanel.none;
  final TransformationController _transformationController = TransformationController();

  // Undo & Redo History Stacks
  final List<List<CertificateCanvasElement>> _undoStack = [];
  final List<List<CertificateCanvasElement>> _redoStack = [];

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
    _backgroundMode = widget.template.backgroundMode;
    _globalFontFamily = widget.template.styleConfig.fontFamily;
    if (widget.template.styleConfig.canvasElements.isNotEmpty) {
      _elements = widget.template.styleConfig.canvasElements
          .map((e) => e.copyWith())
          .toList();
    } else {
      _elements = _generateUngroupedCanvasElements();
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Undo & Redo History Management
  // ===========================================================================
  void _pushHistorySnapshot() {
    final snapshot = _elements.map((e) => e.copyWith()).toList();
    _undoStack.add(snapshot);
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    setState(() {});
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final currentState = _elements.map((e) => e.copyWith()).toList();
    _redoStack.add(currentState);
    final previousState = _undoStack.removeLast();

    setState(() {
      _elements = previousState;
      if (_selectedElementId != null &&
          !_elements.any((e) => e.id == _selectedElementId)) {
        _selectedElementId = null;
        _activeMobilePanel = MobileToolPanel.none;
      }
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final currentState = _elements.map((e) => e.copyWith()).toList();
    _undoStack.add(currentState);
    final nextState = _redoStack.removeLast();

    setState(() {
      _elements = nextState;
    });
  }

  Size _getPageDimensions() {
    double width = 595.28;
    double height = 841.89;

    if (widget.template.paperSize == 'Letter') {
      width = 612.0;
      height = 792.0;
    } else if (widget.template.paperSize == 'Legal') {
      width = 612.0;
      height = 936.0;
    }

    if (widget.template.orientation == 'Landscape') {
      return Size(height, width);
    }
    return Size(width, height);
  }

  List<CertificateCanvasElement> _generateUngroupedCanvasElements() {
    final tpl = widget.template;
    final lines = tpl.headerLines;

    return [
      CertificateCanvasElement(
        id: 'elem_diocese_seal',
        elementType: 'diocese_seal',
        text: 'DSP Emblem',
        x: 0.14,
        y: 0.10,
        fontSize: 14.0,
        colorHex: '#164E87',
      ),
      CertificateCanvasElement(
        id: 'elem_diocese_text',
        elementType: 'text',
        text: lines.isNotEmpty ? lines[0] : 'Diocese of San Pablo',
        x: 0.50,
        y: 0.08,
        width: 0.60,
        fontSize: 10.5,
        fontWeight: 'bold',
        fontFamily: _globalFontFamily,
        colorHex: '#1E293B',
        textAlign: 'center',
        verticalAlign: 'center',
      ),
      CertificateCanvasElement(
        id: 'elem_parish_title',
        elementType: 'text',
        text: lines.length > 1 ? lines[1] : 'Saint John Paul II Parish',
        x: 0.50,
        y: 0.11,
        width: 0.60,
        fontSize: 16.0,
        fontWeight: 'bold',
        fontFamily: _globalFontFamily,
        colorHex: '#164E87',
        textAlign: 'center',
        verticalAlign: 'center',
      ),
      CertificateCanvasElement(
        id: 'elem_parish_loc',
        elementType: 'text',
        text: lines.length > 2 ? lines.sublist(2).join(', ') : 'Santa Cruz, Laguna',
        x: 0.50,
        y: 0.15,
        width: 0.60,
        fontSize: 9.5,
        fontFamily: _globalFontFamily,
        colorHex: '#64748B',
        textAlign: 'center',
        verticalAlign: 'center',
      ),
      CertificateCanvasElement(
        id: 'elem_parish_seal',
        elementType: 'parish_seal',
        text: 'SJP2 Seal',
        x: 0.86,
        y: 0.10,
        fontSize: 14.0,
        colorHex: '#D49B18',
      ),
      CertificateCanvasElement(
        id: 'elem_title',
        elementType: 'title',
        text: tpl.certificateTitle,
        x: 0.50,
        y: 0.22,
        width: 0.60,
        height: 0.06,
        fontSize: tpl.styleConfig.titleFontSize,
        fontWeight: 'bold',
        fontFamily: _globalFontFamily,
        colorHex: '#164E87',
        textAlign: 'center',
        verticalAlign: 'center',
      ),
      CertificateCanvasElement(
        id: 'elem_recipient',
        elementType: 'text',
        text: '{Full Name}',
        x: 0.50,
        y: 0.34,
        width: 0.65,
        fontSize: 17.0,
        fontWeight: 'bold',
        fontFamily: _globalFontFamily,
        colorHex: '#164E87',
        textAlign: 'center',
        verticalAlign: 'center',
      ),
      CertificateCanvasElement(
        id: 'elem_body',
        elementType: 'textbox',
        text: tpl.bodyWording,
        x: 0.50,
        y: 0.48,
        width: 0.84,
        height: 0.32,
        fontSize: tpl.styleConfig.bodyFontSize,
        fontWeight: 'normal',
        fontFamily: _globalFontFamily,
        colorHex: '#1E293B',
        textAlign: 'center',
        verticalAlign: 'center',
      ),
      CertificateCanvasElement(
        id: 'elem_signatory_line',
        elementType: 'signature_line',
        text: 'Signature Line',
        x: 0.76,
        y: 0.82,
        width: 0.32,
        colorHex: '#1E293B',
      ),
      CertificateCanvasElement(
        id: 'elem_signatory_name',
        elementType: 'text',
        text: tpl.signatoryName,
        x: 0.76,
        y: 0.86,
        width: 0.32,
        fontSize: 11.0,
        fontWeight: 'bold',
        fontFamily: _globalFontFamily,
        colorHex: '#1E293B',
        textAlign: 'center',
        verticalAlign: 'center',
      ),
      CertificateCanvasElement(
        id: 'elem_signatory_title',
        elementType: 'text',
        text: tpl.signatoryTitle,
        x: 0.76,
        y: 0.90,
        width: 0.32,
        fontSize: 9.5,
        fontFamily: _globalFontFamily,
        colorHex: '#64748B',
        textAlign: 'center',
        verticalAlign: 'center',
      ),
      if (tpl.enableQrVerification)
        CertificateCanvasElement(
          id: 'elem_qr',
          elementType: 'qr',
          text: 'QR Verification Token',
          x: 0.22,
          y: 0.86,
          width: 0.18,
          fontSize: 8.0,
          fontWeight: 'normal',
          fontFamily: _globalFontFamily,
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

  void _applyFontToAllElements(String fontFamily) {
    _pushHistorySnapshot();
    setState(() {
      _globalFontFamily = fontFamily;
      _elements = _elements.map((e) {
        if (e.elementType.contains('seal') || e.elementType == 'qr' || e.elementType == 'signature_line') {
          return e;
        }
        return e.copyWith(fontFamily: fontFamily);
      }).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied "${_getFontName(fontFamily)}" to all elements.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getFontName(String fontId) {
    return _availableFonts.firstWhere(
          (f) => f['id'] == fontId,
      orElse: () => {'name': fontId},
    )['name']!;
  }

  void _nudgeSelected(double dx, double dy) {
    final current = _selectedElement;
    if (current == null) return;
    _pushHistorySnapshot();
    _updateSelectedElement(current.copyWith(
      x: (current.x + dx).clamp(0.04, 0.96),
      y: (current.y + dy).clamp(0.04, 0.96),
    ));
  }

  void _addNewElement(
      String type,
      String defaultText,
      double defaultY, {
        double defaultX = 0.5,
        double width = 0.84,
        double? height,
        double fontSize = 12.0,
        String fontWeight = 'normal',
        String colorHex = '#1E293B',
        String textAlign = 'center',
        String verticalAlign = 'center',
      }) {
    _pushHistorySnapshot();
    final newId = 'elem_${DateTime.now().millisecondsSinceEpoch}';
    final elem = CertificateCanvasElement(
      id: newId,
      elementType: type,
      text: defaultText,
      x: defaultX,
      y: defaultY,
      width: width,
      height: height ?? (type == 'textbox' ? 0.18 : null),
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: _globalFontFamily,
      colorHex: colorHex,
      textAlign: textAlign,
      verticalAlign: verticalAlign,
    );

    setState(() {
      _elements.add(elem);
      _selectedElementId = newId;
      _toolMode = CanvasToolMode.select;
      _activeMobilePanel = MobileToolPanel.none;
    });
  }

  void _duplicateSelected() {
    final current = _selectedElement;
    if (current == null) return;

    _pushHistorySnapshot();
    final newId = 'elem_${DateTime.now().millisecondsSinceEpoch}';
    final clone = current.copyWith(
      id: newId,
      x: (current.x + 0.03).clamp(0.06, 0.94),
      y: (current.y + 0.03).clamp(0.06, 0.94),
    );

    setState(() {
      _elements.add(clone);
      _selectedElementId = newId;
    });
  }

  void _deleteSelected() {
    if (_selectedElementId == null) return;
    _pushHistorySnapshot();
    setState(() {
      _elements.removeWhere((e) => e.id == _selectedElementId);
      _selectedElementId = null;
      _activeMobilePanel = MobileToolPanel.none;
    });
  }

  // ===========================================================================
  // HIG Grouped Placeholders & Text Editor Dialog
  // ===========================================================================
  Future<void> _openTextEditorModal(CertificateCanvasElement element) async {
    final controller = TextEditingController(text: element.text);
    final allTags = PlaceholderRegistry.getPlaceholdersFor(widget.template.sacramentType);

    final List<String> personalTags = [];
    final List<String> familyTags = [];
    final List<String> liturgyTags = [];
    final List<String> registryTags = [];

    for (final tag in allTags) {
      final t = tag.toLowerCase();
      if (t.contains('father') || t.contains('mother') || t.contains('godfather') || t.contains('godmother') || t.contains('sponsor') || t.contains('spouse')) {
        familyTags.add(tag);
      } else if (t.contains('date of baptism') || t.contains('date of confirmation') || t.contains('date of communion') || t.contains('date of marriage') || t.contains('date of death') || t.contains('minister') || t.contains('church') || t.contains('place of')) {
        liturgyTags.add(tag);
      } else if (t.contains('book') || t.contains('page') || t.contains('line') || t.contains('reference') || t.contains('purpose') || t.contains('date issued') || t.contains('record') || t.contains('year')) {
        registryTags.add(tag);
      } else {
        personalTags.add(tag);
      }
    }

    String activeTab = 'Personal';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          List<String> visibleTags;
          switch (activeTab) {
            case 'Family':
              visibleTags = familyTags;
              break;
            case 'Liturgy':
              visibleTags = liturgyTags;
              break;
            case 'Registry':
              visibleTags = registryTags;
              break;
            case 'Personal':
            default:
              visibleTags = personalTags;
              break;
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: ParishColors.cardWhite,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit Text & Placeholders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: ParishColors.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ParishColors.borderGrey),
                      ),
                      child: Row(
                        children: [
                          _buildModalTabItem('Personal', Icons.person_outline, activeTab, () {
                            setModalState(() => activeTab = 'Personal');
                          }),
                          _buildModalTabItem('Family', Icons.people_outline, activeTab, () {
                            setModalState(() => activeTab = 'Family');
                          }),
                          _buildModalTabItem('Liturgy', Icons.church_outlined, activeTab, () {
                            setModalState(() => activeTab = 'Liturgy');
                          }),
                          _buildModalTabItem('Registry', Icons.menu_book_outlined, activeTab, () {
                            setModalState(() => activeTab = 'Registry');
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Tap to insert $activeTab tags into text box:',
                      style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: visibleTags.map((tag) {
                          return ActionChip(
                            label: Text(tag, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            backgroundColor: ParishColors.goldLight,
                            side: BorderSide(color: ParishColors.goldAccent.withValues(alpha: 0.6)),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            onPressed: () {
                              final text = controller.text;
                              controller.text = '$text $tag';
                              setModalState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: controller,
                      maxLines: 5,
                      style: TextStyle(fontSize: 13.5, color: ParishColors.textDark, height: 1.4),
                      decoration: const InputDecoration(
                        labelText: 'Text Content (Auto-wraps inside box)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
                onPressed: () {
                  _pushHistorySnapshot();
                  _updateSelectedElement(element.copyWith(text: controller.text));
                  Navigator.pop(ctx);
                },
                child: const Text('Apply Text'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModalTabItem(String label, IconData icon, String activeTab, VoidCallback onTap) {
    final bool isSelected = activeTab == label;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? ParishColors.marianBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : ParishColors.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : ParishColors.textDark,
                ),
              ),
            ],
          ),
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

  TextStyle _resolveCanvasTextStyle({
    required CertificateCanvasElement element,
    required Color textColor,
  }) {
    String? fontFamily;
    List<String> fontFallback = const [];
    FontStyle fontStyle = FontStyle.normal;
    double letterSpacing = 0.0;

    switch (element.fontFamily.toLowerCase()) {
      case 'sans':
        fontFamily = 'Arial';
        fontFallback = const ['Helvetica', 'Roboto', 'Segoe UI', 'sans-serif'];
        break;
      case 'courier':
        fontFamily = 'Courier New';
        fontFallback = const ['Courier', 'Lucida Console', 'monospace'];
        break;
      case 'georgia':
        fontFamily = 'Georgia';
        fontFallback = const ['Times New Roman', 'Times', 'serif'];
        break;
      case 'garamond':
        fontFamily = 'Garamond';
        fontFallback = const ['Baskerville', 'Times New Roman', 'serif'];
        break;
      case 'cinzel':
        fontFamily = 'Palatino Linotype';
        fontFallback = const ['Palatino', 'Book Antiqua', 'Georgia', 'serif'];
        letterSpacing = 2.0;
        break;
      case 'script':
        fontFamily = 'Brush Script MT';
        fontFallback = const ['Lucida Calligraphy', 'Zapfino', 'Segoe Script', 'cursive'];
        fontStyle = FontStyle.italic;
        break;
      case 'trebuchet':
        fontFamily = 'Trebuchet MS';
        fontFallback = const ['Arial', 'Helvetica', 'sans-serif'];
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

  TextStyle _resolveFontPreviewStyle(String fontId, Color color) {
    return _resolveCanvasTextStyle(
      element: CertificateCanvasElement(
        id: 'preview',
        elementType: 'text',
        text: '',
        x: 0,
        y: 0,
        fontFamily: fontId,
        fontSize: 12.5,
      ),
      textColor: color,
    );
  }

  Alignment _resolveBoxAlignment(String textAlign, String verticalAlign) {
    double x = 0.0;
    if (textAlign == 'left') x = -1.0;
    if (textAlign == 'right') x = 1.0;
    if (textAlign == 'center' || textAlign == 'justify') x = 0.0;

    double y = 0.0;
    if (verticalAlign == 'top') y = -1.0;
    if (verticalAlign == 'center' || verticalAlign == 'middle') y = 0.0;
    if (verticalAlign == 'bottom') y = 1.0;

    return Alignment(x, y);
  }

  // ===========================================================================
  // Phone Navigation & Dedicated Non-Blocking Control Bar
  // ===========================================================================
  void _openMobileAddElementSheet() {
    final tpl = widget.template;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ParishColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final screenHeight = MediaQuery.of(context).size.height;
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Add Canvas Element', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.8,
                    children: [
                      _buildMobileMenuTile(
                        icon: Icons.text_fields,
                        label: 'Text Box',
                        color: ParishColors.marianBlue,
                        onTap: () {
                          Navigator.pop(ctx);
                          _addNewElement('textbox', 'Enter text content here...', 0.50, width: 0.65, height: 0.16);
                        },
                      ),
                      _buildMobileMenuTile(
                        icon: Icons.title,
                        label: 'Title Banner',
                        color: ParishColors.marianBlue,
                        onTap: () {
                          Navigator.pop(ctx);
                          _addNewElement('title', tpl.certificateTitle.toUpperCase(), 0.22, width: 0.60, height: 0.06, fontSize: 16, fontWeight: 'bold');
                        },
                      ),
                      _buildMobileMenuTile(
                        icon: Icons.person_pin,
                        label: '{Full Name}',
                        color: ParishColors.marianBlue,
                        onTap: () {
                          Navigator.pop(ctx);
                          _addNewElement('text', '{Full Name}', 0.34, width: 0.65, fontSize: 17, fontWeight: 'bold');
                        },
                      ),
                      _buildMobileMenuTile(
                        icon: Icons.verified,
                        label: 'Parish Seal',
                        color: ParishColors.goldAccent,
                        onTap: () {
                          Navigator.pop(ctx);
                          _addNewElement('parish_seal', 'Parish Seal', 0.12, defaultX: 0.86, width: 0.14, fontSize: 14);
                        },
                      ),
                      _buildMobileMenuTile(
                        icon: Icons.shield,
                        label: 'Diocese Logo',
                        color: ParishColors.marianBlue,
                        onTap: () {
                          Navigator.pop(ctx);
                          _addNewElement('diocese_seal', 'Diocese Logo', 0.12, defaultX: 0.14, width: 0.14, fontSize: 14);
                        },
                      ),
                      _buildMobileMenuTile(
                        icon: Icons.horizontal_rule,
                        label: 'Signature Line',
                        color: Colors.black87,
                        onTap: () {
                          Navigator.pop(ctx);
                          _addNewElement('signature_line', 'Signature Line', 0.82, defaultX: 0.76, width: 0.32);
                        },
                      ),
                      _buildMobileMenuTile(
                        icon: Icons.person_outline,
                        label: 'Signatory Name',
                        color: Colors.black87,
                        onTap: () {
                          Navigator.pop(ctx);
                          _addNewElement('text', tpl.signatoryName, 0.86, defaultX: 0.76, width: 0.32, fontSize: 11.0, fontWeight: 'bold');
                        },
                      ),
                      _buildMobileMenuTile(
                        icon: Icons.qr_code,
                        label: 'QR Code',
                        color: Colors.grey.shade700,
                        onTap: () {
                          Navigator.pop(ctx);
                          _addNewElement('qr', 'QR Verification', 0.86, defaultX: 0.22, width: 0.18, fontSize: 8);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileMenuTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ParishColors.backgroundLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mobile Font Selection Sheet (Scroll-Controlled to prevent bottom overflow)
  void _openMobileFontSheet(CertificateCanvasElement? selected) {
    final textDark = ParishColors.textDark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ParishColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final screenHeight = MediaQuery.of(context).size.height;
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(maxHeight: screenHeight * 0.65),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  selected == null ? 'Select Default Certificate Font' : 'Select Font for Element',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _availableFonts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final f = _availableFonts[index];
                      final isSelected = selected != null
                          ? selected.fontFamily == f['id']
                          : _globalFontFamily == f['id'];

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        title: Text(f['name']!, style: _resolveFontPreviewStyle(f['id']!, textDark)),
                        trailing: isSelected ? const Icon(Icons.check, color: ParishColors.marianBlue, size: 20) : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        tileColor: isSelected ? ParishColors.marianBlueSurface : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          if (selected != null) {
                            _pushHistorySnapshot();
                            _updateSelectedElement(selected.copyWith(fontFamily: f['id']));
                          } else {
                            _applyFontToAllElements(f['id']!);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Build Method
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final cardWhite = ParishColors.cardWhite;
    final pageSize = _getPageDimensions();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;

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
            title: isMobile
                ? Text(
              widget.template.templateName,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
              overflow: TextOverflow.ellipsis,
            )
                : Column(
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
                      child: Text(
                        _backgroundMode == 'None' ? 'PLAIN CANVA' : 'BORDERED CANVA',
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.template.templateName,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${widget.template.sacramentType} • ${widget.template.paperSize} (${widget.template.orientation}) • ${pageSize.width.toStringAsFixed(0)} × ${pageSize.height.toStringAsFixed(0)} pt',
                  style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
                ),
              ],
            ),
            actions: [
              // UNDO BUTTON
              IconButton(
                icon: const Icon(Icons.undo),
                color: _undoStack.isNotEmpty ? ParishColors.marianBlue : Colors.grey.shade400,
                tooltip: 'Undo',
                onPressed: _undoStack.isNotEmpty ? _undo : null,
              ),
              // REDO BUTTON
              IconButton(
                icon: const Icon(Icons.redo),
                color: _redoStack.isNotEmpty ? ParishColors.marianBlue : Colors.grey.shade400,
                tooltip: 'Redo',
                onPressed: _redoStack.isNotEmpty ? _redo : null,
              ),

              // Tool Mode (Select vs Pan)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  children: [
                    Tooltip(
                      message: 'Select Element Mode',
                      child: InkWell(
                        onTap: () => setState(() => _toolMode = CanvasToolMode.select),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: _toolMode == CanvasToolMode.select ? ParishColors.marianBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(Icons.near_me, size: 16, color: _toolMode == CanvasToolMode.select ? Colors.white : textDark),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Pan & Zoom Mode',
                      child: InkWell(
                        onTap: () => setState(() {
                          _toolMode = CanvasToolMode.pan;
                          _selectedElementId = null;
                          _activeMobilePanel = MobileToolPanel.none;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: _toolMode == CanvasToolMode.pan ? ParishColors.marianBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(Icons.pan_tool, size: 16, color: _toolMode == CanvasToolMode.pan ? Colors.white : textDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.oliveGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(40, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context, _elements),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(isMobile ? 'Save' : 'Apply Design', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (!isMobile)
                  _buildDesktopContextualToolbar(pageWidth: pageSize.width, pageHeight: pageSize.height),

                // Interactive Workspace
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedElementId = null;
                      _activeMobilePanel = MobileToolPanel.none;
                    }),
                    child: LayoutBuilder(
                      builder: (context, workspaceConstraints) {
                        final availableWidth = workspaceConstraints.maxWidth - (isMobile ? 12 : 48);
                        final availableHeight = workspaceConstraints.maxHeight - (isMobile ? 12 : 48);
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

                        final double scaleFactor = displayedWidth / pageSize.width;

                        return InteractiveViewer(
                          transformationController: _transformationController,
                          panEnabled: _toolMode == CanvasToolMode.pan,
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
                                    _buildCanvasBorderBackground(pageSize.width, pageSize.height),
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

                isMobile
                    ? _buildMobileDockedControls(context, pageSize.width, pageSize.height)
                    : _buildDesktopBottomPalette(context),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Desktop Toolbar
  // ===========================================================================
  Widget _buildDesktopContextualToolbar({
    required double pageWidth,
    required double pageHeight,
  }) {
    final selected = _selectedElement;
    final textDark = ParishColors.textDark;

    if (selected == null) {
      return Container(
        height: 50,
        width: double.infinity,
        color: ParishColors.cardWhite,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.text_format, size: 18, color: ParishColors.marianBlue),
            const SizedBox(width: 8),
            const Text('Certificate Font: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _availableFonts.any((f) => f['id'] == _globalFontFamily)
                  ? _globalFontFamily
                  : 'serif',
              underline: const SizedBox.shrink(),
              items: _availableFonts.map((f) {
                return DropdownMenuItem(
                  value: f['id'],
                  child: Text(f['name']!, style: _resolveFontPreviewStyle(f['id']!, textDark)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) _applyFontToAllElements(val);
              },
            ),
            const Spacer(),
            Row(
              children: [
                Text(_backgroundMode == 'None' ? 'Border: Plain' : 'Border: Frame', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                Switch(
                  value: _backgroundMode != 'None',
                  activeColor: ParishColors.marianBlue,
                  onChanged: (val) => setState(() => _backgroundMode = val ? 'Border' : 'None'),
                ),
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left, size: 18),
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  onPressed: () => _nudgeSelected(-0.005, 0),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_drop_up, size: 18),
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  onPressed: () => _nudgeSelected(0, -0.005),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_drop_down, size: 18),
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  onPressed: () => _nudgeSelected(0, 0.005),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_right, size: 18),
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  onPressed: () => _nudgeSelected(0.005, 0),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 14, indent: 8, endIndent: 8),

          if (!isSeal && selected.elementType != 'qr' && selected.elementType != 'signature_line') ...[
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: ParishColors.marianBlue),
              onPressed: () => _openTextEditorModal(selected),
              icon: const Icon(Icons.edit, size: 15),
              label: const Text('Edit Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const VerticalDivider(width: 14, indent: 8, endIndent: 8),

            DropdownButton<String>(
              value: _availableFonts.any((f) => f['id'] == selected.fontFamily)
                  ? selected.fontFamily
                  : 'serif',
              underline: const SizedBox.shrink(),
              items: _availableFonts.map((f) {
                return DropdownMenuItem(
                  value: f['id'],
                  child: Text(f['name']!, style: _resolveFontPreviewStyle(f['id']!, textDark)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  _pushHistorySnapshot();
                  _updateSelectedElement(selected.copyWith(fontFamily: val));
                }
              },
            ),
            const VerticalDivider(width: 14, indent: 8, endIndent: 8),
          ],

          Row(
            children: [
              Text(isSeal ? 'Diameter: ' : 'Font Size: ', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.remove, size: 15),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: selected.fontSize > 6.0
                    ? () {
                  _pushHistorySnapshot();
                  _updateSelectedElement(selected.copyWith(fontSize: selected.fontSize - (isSeal ? 2.0 : 1.0)));
                }
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(border: Border.all(color: ParishColors.borderGrey), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  isSeal ? '${(selected.fontSize * 4.0).toInt()} pt' : '${selected.fontSize.toInt()} pt',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 15),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: selected.fontSize < 48.0
                    ? () {
                  _pushHistorySnapshot();
                  _updateSelectedElement(selected.copyWith(fontSize: selected.fontSize + (isSeal ? 2.0 : 1.0)));
                }
                    : null,
              ),
            ],
          ),
          const VerticalDivider(width: 14, indent: 8, endIndent: 8),

          if (!isSeal && selected.elementType != 'qr' && selected.elementType != 'signature_line') ...[
            IconButton(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(Icons.format_bold, color: selected.isBold ? ParishColors.marianBlue : Colors.grey),
              onPressed: () {
                _pushHistorySnapshot();
                _updateSelectedElement(selected.copyWith(fontWeight: selected.isBold ? 'normal' : 'bold'));
              },
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(Icons.format_align_left, color: selected.textAlign == 'left' ? ParishColors.marianBlue : Colors.grey, size: 17),
              onPressed: () {
                _pushHistorySnapshot();
                _updateSelectedElement(selected.copyWith(textAlign: 'left'));
              },
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(Icons.format_align_center, color: selected.textAlign == 'center' ? ParishColors.marianBlue : Colors.grey, size: 17),
              onPressed: () {
                _pushHistorySnapshot();
                _updateSelectedElement(selected.copyWith(textAlign: 'center'));
              },
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(Icons.format_align_right, color: selected.textAlign == 'right' ? ParishColors.marianBlue : Colors.grey, size: 17),
              onPressed: () {
                _pushHistorySnapshot();
                _updateSelectedElement(selected.copyWith(textAlign: 'right'));
              },
            ),
            const VerticalDivider(width: 14, indent: 8, endIndent: 8),

            IconButton(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(Icons.vertical_align_top, color: selected.verticalAlign == 'top' ? ParishColors.marianBlue : Colors.grey, size: 18),
              onPressed: () {
                _pushHistorySnapshot();
                final currentH = selected.height ?? 0.18;
                _updateSelectedElement(selected.copyWith(verticalAlign: 'top', height: currentH));
              },
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(Icons.vertical_align_center, color: (selected.verticalAlign == 'center' || selected.verticalAlign == 'middle') ? ParishColors.marianBlue : Colors.grey, size: 18),
              onPressed: () {
                _pushHistorySnapshot();
                final currentH = selected.height ?? 0.18;
                _updateSelectedElement(selected.copyWith(verticalAlign: 'center', height: currentH));
              },
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(Icons.vertical_align_bottom, color: selected.verticalAlign == 'bottom' ? ParishColors.marianBlue : Colors.grey, size: 18),
              onPressed: () {
                _pushHistorySnapshot();
                final currentH = selected.height ?? 0.18;
                _updateSelectedElement(selected.copyWith(verticalAlign: 'bottom', height: currentH));
              },
            ),
            const VerticalDivider(width: 14, indent: 8, endIndent: 8),
          ],

          Row(
            children: _colorSwatches.map((item) {
              final color = item['color'] as Color;
              final hex = item['hex'] as String;
              final isChosen = selected.colorHex == hex;

              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: InkWell(
                  onTap: () {
                    _pushHistorySnapshot();
                    _updateSelectedElement(selected.copyWith(colorHex: hex));
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: isChosen ? Colors.cyanAccent : Colors.grey.shade300, width: isChosen ? 2.5 : 1.0),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const VerticalDivider(width: 14, indent: 8, endIndent: 8),

          IconButton(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.copy, size: 17),
            tooltip: 'Duplicate',
            onPressed: _duplicateSelected,
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.delete_outline, color: ParishColors.mercyRed, size: 17),
            tooltip: 'Delete',
            onPressed: _deleteSelected,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Mobile Docked Controls (Non-Obtrusive, Real-Time Canvas View)
  // ===========================================================================
  Widget _buildMobileDockedControls(
      BuildContext context, double pageWidth, double pageHeight) {
    final selected = _selectedElement;

    // A. When NO element is selected
    if (selected == null) {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openMobileAddElementSheet,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add Element', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: ParishColors.borderGrey),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _openMobileFontSheet(null),
              icon: const Icon(Icons.font_download_outlined, size: 16, color: ParishColors.marianBlue),
              label: const Text('Font', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                _backgroundMode == 'None' ? Icons.crop_square : Icons.border_clear,
                color: ParishColors.marianBlue,
                size: 22,
              ),
              tooltip: 'Toggle Border Frame',
              onPressed: () {
                setState(() {
                  _backgroundMode = _backgroundMode == 'None' ? 'Border' : 'None';
                });
              },
            ),
          ],
        ),
      );
    }

    final bool isSeal = selected.elementType.contains('seal');

    // B. Contextual Tools for Selected Element
    return Container(
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dynamic Non-blocking Subpanel
          if (_activeMobilePanel != MobileToolPanel.none)
            Container(
              height: 52,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: ParishColors.backgroundLight,
                border: Border(bottom: BorderSide(color: ParishColors.borderGrey)),
              ),
              child: _buildMobileSubpanelContent(selected),
            ),

          // Main Action Dock with Large Tap Targets
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (!isSeal && selected.elementType != 'qr' && selected.elementType != 'signature_line')
                  _buildMobileDockIconBtn(
                    icon: Icons.edit_note,
                    label: 'Text',
                    isActive: false,
                    onTap: () => _openTextEditorModal(selected),
                  ),
                _buildMobileDockIconBtn(
                  icon: Icons.format_size,
                  label: 'Size',
                  isActive: _activeMobilePanel == MobileToolPanel.size,
                  onTap: () {
                    setState(() {
                      _activeMobilePanel = _activeMobilePanel == MobileToolPanel.size
                          ? MobileToolPanel.none
                          : MobileToolPanel.size;
                    });
                  },
                ),
                if (!isSeal && selected.elementType != 'qr' && selected.elementType != 'signature_line')
                  _buildMobileDockIconBtn(
                    icon: Icons.tune,
                    label: 'Format',
                    isActive: _activeMobilePanel == MobileToolPanel.format,
                    onTap: () {
                      setState(() {
                        _activeMobilePanel = _activeMobilePanel == MobileToolPanel.format
                            ? MobileToolPanel.none
                            : MobileToolPanel.format;
                      });
                    },
                  ),
                _buildMobileDockIconBtn(
                  icon: Icons.palette_outlined,
                  label: 'Color',
                  isActive: _activeMobilePanel == MobileToolPanel.color,
                  onTap: () {
                    setState(() {
                      _activeMobilePanel = _activeMobilePanel == MobileToolPanel.color
                          ? MobileToolPanel.none
                          : MobileToolPanel.color;
                    });
                  },
                ),
                if (!isSeal && selected.elementType != 'qr' && selected.elementType != 'signature_line')
                  _buildMobileDockIconBtn(
                    icon: Icons.font_download_outlined,
                    label: 'Font',
                    isActive: false,
                    onTap: () => _openMobileFontSheet(selected),
                  ),
                // Non-blocking live nudge tool
                _buildMobileDockIconBtn(
                  icon: Icons.control_camera,
                  label: 'Nudge',
                  isActive: _activeMobilePanel == MobileToolPanel.nudge,
                  onTap: () {
                    setState(() {
                      _activeMobilePanel = _activeMobilePanel == MobileToolPanel.nudge
                          ? MobileToolPanel.none
                          : MobileToolPanel.nudge;
                    });
                  },
                ),
                _buildMobileDockIconBtn(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: ParishColors.mercyRed,
                  onTap: _deleteSelected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDockIconBtn({
    required IconData icon,
    required String label,
    bool isActive = false,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? ParishColors.marianBlueSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isActive ? ParishColors.marianBlue : (color ?? ParishColors.textDark)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? ParishColors.marianBlue : (color ?? ParishColors.textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSubpanelContent(CertificateCanvasElement selected) {
    final bool isSeal = selected.elementType.contains('seal');

    switch (_activeMobilePanel) {
      case MobileToolPanel.nudge:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Nudge: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 8),
            _buildNudgeBtn(Icons.arrow_left, () => _nudgeSelected(-0.005, 0)),
            const SizedBox(width: 6),
            _buildNudgeBtn(Icons.arrow_drop_up, () => _nudgeSelected(0, -0.005)),
            const SizedBox(width: 6),
            _buildNudgeBtn(Icons.arrow_drop_down, () => _nudgeSelected(0, 0.005)),
            const SizedBox(width: 6),
            _buildNudgeBtn(Icons.arrow_right, () => _nudgeSelected(0.005, 0)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _activeMobilePanel = MobileToolPanel.none),
            ),
          ],
        );

      case MobileToolPanel.size:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isSeal ? 'Diameter: ' : 'Font Size: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20, color: ParishColors.marianBlue),
              onPressed: selected.fontSize > 6.0
                  ? () {
                _pushHistorySnapshot();
                _updateSelectedElement(selected.copyWith(fontSize: selected.fontSize - (isSeal ? 2.0 : 1.0)));
              }
                  : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: ParishColors.borderGrey)),
              child: Text(
                isSeal ? '${(selected.fontSize * 4.0).toInt()} pt' : '${selected.fontSize.toInt()} pt',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20, color: ParishColors.marianBlue),
              onPressed: selected.fontSize < 48.0
                  ? () {
                _pushHistorySnapshot();
                _updateSelectedElement(selected.copyWith(fontSize: selected.fontSize + (isSeal ? 2.0 : 1.0)));
              }
                  : null,
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _activeMobilePanel = MobileToolPanel.none),
            ),
          ],
        );

      case MobileToolPanel.color:
        return Row(
          children: [
            const Text('Color: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 8),
            ..._colorSwatches.map((item) {
              final color = item['color'] as Color;
              final hex = item['hex'] as String;
              final isChosen = selected.colorHex == hex;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: InkWell(
                  onTap: () {
                    _pushHistorySnapshot();
                    _updateSelectedElement(selected.copyWith(colorHex: hex));
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isChosen ? Colors.cyanAccent : Colors.grey.shade400,
                        width: isChosen ? 3.0 : 1.0,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _activeMobilePanel = MobileToolPanel.none),
            ),
          ],
        );

      case MobileToolPanel.format:
        return Row(
          children: [
            IconButton(
              icon: Icon(Icons.format_bold, color: selected.isBold ? ParishColors.marianBlue : Colors.grey, size: 20),
              onPressed: () {
                _pushHistorySnapshot();
                _updateSelectedElement(selected.copyWith(fontWeight: selected.isBold ? 'normal' : 'bold'));
              },
            ),
            const VerticalDivider(width: 12, indent: 8, endIndent: 8),
            IconButton(
              icon: Icon(Icons.format_align_left, color: selected.textAlign == 'left' ? ParishColors.marianBlue : Colors.grey, size: 18),
              onPressed: () {
                _pushHistorySnapshot();
                _updateSelectedElement(selected.copyWith(textAlign: 'left'));
              },
            ),
            IconButton(
              icon: Icon(Icons.format_align_center, color: selected.textAlign == 'center' ? ParishColors.marianBlue : Colors.grey, size: 18),
              onPressed: () {
                _pushHistorySnapshot();
                _updateSelectedElement(selected.copyWith(textAlign: 'center'));
              },
            ),
            IconButton(
              icon: Icon(Icons.format_align_right, color: selected.textAlign == 'right' ? ParishColors.marianBlue : Colors.grey, size: 18),
              onPressed: () {
                _pushHistorySnapshot();
                _updateSelectedElement(selected.copyWith(textAlign: 'right'));
              },
            ),
            const VerticalDivider(width: 12, indent: 8, endIndent: 8),
            IconButton(
              icon: Icon(Icons.vertical_align_top, color: selected.verticalAlign == 'top' ? ParishColors.marianBlue : Colors.grey, size: 18),
              onPressed: () {
                _pushHistorySnapshot();
                final currentH = selected.height ?? 0.18;
                _updateSelectedElement(selected.copyWith(verticalAlign: 'top', height: currentH));
              },
            ),
            IconButton(
              icon: Icon(Icons.vertical_align_center, color: (selected.verticalAlign == 'center' || selected.verticalAlign == 'middle') ? ParishColors.marianBlue : Colors.grey, size: 18),
              onPressed: () {
                _pushHistorySnapshot();
                final currentH = selected.height ?? 0.18;
                _updateSelectedElement(selected.copyWith(verticalAlign: 'center', height: currentH));
              },
            ),
            IconButton(
              icon: Icon(Icons.vertical_align_bottom, color: selected.verticalAlign == 'bottom' ? ParishColors.marianBlue : Colors.grey, size: 18),
              onPressed: () {
                _pushHistorySnapshot();
                final currentH = selected.height ?? 0.18;
                _updateSelectedElement(selected.copyWith(verticalAlign: 'bottom', height: currentH));
              },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _activeMobilePanel = MobileToolPanel.none),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNudgeBtn(IconData icon, VoidCallback onTap) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: ParishColors.marianBlueSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ParishColors.marianBlue.withOpacity(0.3)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: ParishColors.marianBlue),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  // ===========================================================================
  // Interactive Draggable Element (Pinned Resize Anchors & Nudge Support)
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
    final double? elementHeight = element.height != null ? element.height! * pageHeight : null;
    final double pixelCenterX = element.x * pageWidth;
    final double pixelCenterY = element.y * pageHeight;

    TextAlign align;
    switch (element.textAlign) {
      case 'right':
        align = TextAlign.right;
        break;
      case 'left':
        align = TextAlign.left;
        break;
      case 'center':
      default:
        align = TextAlign.center;
        break;
    }

    Widget contentWidget;
    if (element.elementType == 'qr') {
      contentWidget = _buildQrPlaceholderDisplay();
    } else if (element.elementType == 'signature_line') {
      contentWidget = Column(
        children: [
          Container(width: elementWidth, height: 1.2, color: textColor),
        ],
      );
    } else if (element.elementType == 'signatory') {
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 170, height: 1.0, color: Colors.black87),
          const SizedBox(height: 4),
          Text(
            element.text,
            textAlign: TextAlign.center,
            style: _resolveCanvasTextStyle(element: element, textColor: textColor),
          ),
        ],
      );
    } else if (element.elementType == 'parish_seal') {
      contentWidget = _buildCleanSealDisplay(isParish: true, element: element, color: textColor);
    } else if (element.elementType == 'diocese_seal') {
      contentWidget = _buildCleanSealDisplay(isParish: false, element: element, color: textColor);
    } else if (element.elementType == 'title') {
      contentWidget = _buildTitleBannerDisplay(element, textColor);
    } else {
      contentWidget = Container(
        width: elementWidth,
        height: elementHeight,
        alignment: _resolveBoxAlignment(element.textAlign, element.verticalAlign),
        child: Text(
          element.text,
          textAlign: align,
          softWrap: true,
          overflow: TextOverflow.clip,
          style: _resolveCanvasTextStyle(element: element, textColor: textColor),
        ),
      );
    }

    final double sealSize = element.fontSize * 4.0;
    final bool isSeal = element.elementType.contains('seal');
    final double boxWidth = isSeal ? sealSize : elementWidth;
    final double boxHeight = isSeal
        ? sealSize
        : (elementHeight ?? (element.fontSize * 1.6));

    final double left = isSeal ? pixelCenterX - (sealSize / 2) : pixelCenterX - (boxWidth / 2);
    final double top = isSeal ? pixelCenterY - (sealSize / 2) : pixelCenterY - (boxHeight / 2);

    return Positioned(
      left: left,
      top: top,
      width: boxWidth,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedElementId = element.id;
            _toolMode = CanvasToolMode.select;
          });
        },
        onPanStart: (_) => _pushHistorySnapshot(),
        onPanUpdate: _toolMode == CanvasToolMode.select
            ? (details) {
          final deltaX = (details.delta.dx / scaleFactor) / pageWidth;
          final deltaY = (details.delta.dy / scaleFactor) / pageHeight;

          final newX = (element.x + deltaX).clamp(0.04, 0.96);
          final newY = (element.y + deltaY).clamp(0.04, 0.96);

          _updateSelectedElement(element.copyWith(x: newX, y: newY));
        }
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                border: isSelected
                    ? Border.all(color: const Color(0xFF0284C7), width: 1.8)
                    : Border.all(color: Colors.transparent),
                borderRadius: BorderRadius.circular(4),
                color: isSelected ? const Color(0xFF0284C7).withOpacity(0.05) : Colors.transparent,
              ),
              padding: const EdgeInsets.all(2),
              child: contentWidget,
            ),

            if (isSelected)
              Positioned(
                top: -24,
                left: (boxWidth / 2) - 34,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_with, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('MOVE', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),

            // Pinned Left Edge Width Handle
            if (isSelected && !isSeal && element.elementType != 'signature_line')
              Positioned(
                right: -6,
                top: (boxHeight / 2) - 10,
                child: GestureDetector(
                  onPanStart: (_) => _pushHistorySnapshot(),
                  onPanUpdate: (details) {
                    final deltaW = (details.delta.dx / scaleFactor) / pageWidth;
                    final currentW = element.width ?? 0.84;
                    final newW = (currentW + deltaW).clamp(0.12, 0.96);
                    final actualDeltaW = newW - currentW;
                    final newX = (element.x + (actualDeltaW / 2)).clamp(0.04, 0.96);
                    _updateSelectedElement(element.copyWith(width: newW, x: newX));
                  },
                  child: Container(
                    width: 14,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Icon(Icons.unfold_more, size: 12, color: Colors.white),
                  ),
                ),
              ),

            // Pinned Top Edge Height Handle
            if (isSelected && !isSeal && element.elementType != 'signature_line')
              Positioned(
                bottom: -8,
                left: (boxWidth / 2) - 14,
                child: GestureDetector(
                  onPanStart: (_) => _pushHistorySnapshot(),
                  onPanUpdate: (details) {
                    final deltaH = (details.delta.dy / scaleFactor) / pageHeight;
                    final currentH = element.height ?? 0.18;
                    final newH = (currentH + deltaH).clamp(0.04, 0.85);
                    final actualDeltaH = newH - currentH;
                    final newY = (element.y + (actualDeltaH / 2)).clamp(0.04, 0.96);
                    _updateSelectedElement(element.copyWith(height: newH, y: newY));
                  },
                  child: Container(
                    width: 28,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Icon(Icons.drag_handle, size: 11, color: Colors.white),
                  ),
                ),
              ),

            // Corner Resize Handle
            if (isSelected && !isSeal && element.elementType != 'signature_line')
              Positioned(
                right: -6,
                bottom: -6,
                child: GestureDetector(
                  onPanStart: (_) => _pushHistorySnapshot(),
                  onPanUpdate: (details) {
                    final deltaW = (details.delta.dx / scaleFactor) / pageWidth;
                    final deltaH = (details.delta.dy / scaleFactor) / pageHeight;
                    final currentW = element.width ?? 0.84;
                    final currentH = element.height ?? 0.18;
                    final newW = (currentW + deltaW).clamp(0.12, 0.96);
                    final newH = (currentH + deltaH).clamp(0.04, 0.85);
                    final actualDeltaW = newW - currentW;
                    final actualDeltaH = newH - currentH;
                    final newX = (element.x + (actualDeltaW / 2)).clamp(0.04, 0.96);
                    final newY = (element.y + (actualDeltaH / 2)).clamp(0.04, 0.96);
                    _updateSelectedElement(element.copyWith(
                      width: newW,
                      height: newH,
                      x: newX,
                      y: newY,
                    ));
                  },
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0284C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.open_in_full, size: 10, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBannerDisplay(CertificateCanvasElement element, Color color) {
    return Column(
      children: [
        Container(
          width: 340,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: _backgroundMode == 'None'
              ? null
              : const BoxDecoration(
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

  Widget _buildCleanSealDisplay({
    required bool isParish,
    required CertificateCanvasElement element,
    required Color color,
  }) {
    final double diameter = element.fontSize * 4.0;
    final tpl = widget.template;
    final imageUrl = isParish ? tpl.parishSealUrl : tpl.dioceseLogoUrl;
    final fallbackLabel = isParish ? 'SJP2' : 'DSP';

    return Center(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: (imageUrl != null && imageUrl.isNotEmpty)
            ? Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackBadge(fallbackLabel),
        )
            : _buildFallbackBadge(fallbackLabel),
      ),
    );
  }

  Widget _buildFallbackBadge(String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
      ),
    );
  }

  Widget _buildQrPlaceholderDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade400, width: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.qr_code_2, size: 46, color: ParishColors.marianBlue),
        ),
        const SizedBox(height: 3),
        const Text('QR VERIFICATION', style: TextStyle(fontSize: 7.0, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildCanvasBorderBackground(double width, double height) {
    if (widget.template.backgroundImageUrl != null && widget.template.backgroundImageUrl!.isNotEmpty) {
      return Positioned.fill(
        child: Image.network(
          widget.template.backgroundImageUrl!,
          fit: _backgroundMode == 'Full-Page' ? BoxFit.cover : BoxFit.fill,
          errorBuilder: (_, __, ___) => _buildClassicalVectorFrame(),
        ),
      );
    }

    if (_backgroundMode == 'None') {
      return const SizedBox.shrink();
    }

    return _buildClassicalVectorFrame();
  }

  Widget _buildClassicalVectorFrame() {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
  // Desktop Bottom Palette
  // ===========================================================================
  Widget _buildDesktopBottomPalette(BuildContext context) {
    final tpl = widget.template;

    return Container(
      height: 56,
      width: double.infinity,
      color: ParishColors.cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildQuickActionChip(
            icon: Icons.text_fields,
            label: '+ Text Box',
            onTap: () => _addNewElement('textbox', 'Double-tap or edit text box content here...', 0.50, width: 0.65, height: 0.18, fontSize: 11.5),
          ),
          const SizedBox(width: 8),
          _buildQuickActionChip(
            icon: Icons.title,
            label: '+ Title Banner',
            onTap: () => _addNewElement('title', tpl.certificateTitle.toUpperCase(), 0.22, width: 0.60, fontSize: 16, fontWeight: 'bold'),
          ),
          const SizedBox(width: 8),
          _buildQuickActionChip(
            icon: Icons.person_pin,
            label: '+ Recipient ({Full Name})',
            onTap: () => _addNewElement('text', '{Full Name}', 0.34, width: 0.65, fontSize: 17, fontWeight: 'bold'),
          ),
          const SizedBox(width: 8),
          _buildQuickActionChip(
            icon: Icons.verified,
            label: '+ Parish Seal',
            onTap: () => _addNewElement('parish_seal', 'Parish Seal', 0.12, defaultX: 0.86, width: 0.14, fontSize: 14),
          ),
          const SizedBox(width: 8),
          _buildQuickActionChip(
            icon: Icons.shield,
            label: '+ Diocese Emblem',
            onTap: () => _addNewElement('diocese_seal', 'Diocese Emblem', 0.12, defaultX: 0.14, width: 0.14, fontSize: 14),
          ),
          const SizedBox(width: 8),
          _buildQuickActionChip(
            icon: Icons.horizontal_rule,
            label: '+ Signature Line',
            onTap: () => _addNewElement('signature_line', 'Signature Line', 0.82, defaultX: 0.76, width: 0.32),
          ),
          const SizedBox(width: 8),
          _buildQuickActionChip(
            icon: Icons.qr_code,
            label: '+ QR Verification',
            onTap: () => _addNewElement('qr', 'QR Verification Token', 0.86, defaultX: 0.22, width: 0.18, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: ParishColors.marianBlue),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
      backgroundColor: ParishColors.marianBlueSurface,
      side: BorderSide(color: ParishColors.marianBlue.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      onPressed: onTap,
    );
  }
}