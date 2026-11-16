// =============================================================================
// FILE: lib/features/sacramental_records/presentation/widgets/sacramental_loading_overlay.dart
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

/// Full-page, non-dismissible loading overlay for Sacramental Records Management.
///
/// Blocks pointer interaction, keyboard input, scrolling, and back navigation
/// while a CRUD operation or background process is running.
class SacramentalLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final Color? accentColor;
  final IconData icon;
  final Widget child;

  const SacramentalLoadingOverlay({
    super.key,
    required this.isLoading,
    this.message = 'Processing...',
    this.accentColor,
    this.icon = Icons.menu_book_rounded,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: _BlockingLoadingLayer(
              message: message,
              accentColor: accentColor ?? ParishColors.marianBlue,
              icon: icon,
            ),
          ),
      ],
    );
  }
}

/// Shared blocking layer used by the page overlay.
class _BlockingLoadingLayer extends StatelessWidget {
  final String message;
  final Color accentColor;
  final IconData icon;

  const _BlockingLoadingLayer({
    required this.message,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) => KeyEventResult.handled,
        child: AbsorbPointer(
          absorbing: true,
          child: Material(
            color: Colors.transparent,
            child: Container(
              color: Colors.black.withOpacity(0.48),
              alignment: Alignment.center,
              child: _LoadingCard(
                message: message,
                accentColor: accentColor,
                icon: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared loading card for consistent appearance across all sacramental screens.
class _LoadingCard extends StatelessWidget {
  final String message;
  final Color accentColor;
  final IconData icon;

  const _LoadingCard({
    required this.message,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 380,
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: ParishColors.borderGrey.withOpacity(0.65),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 40,
                      spreadRadius: 2,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sacramental theme and gold accent bar.
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor,
                              const Color(0xFFD4A63A),
                            ],
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          28,
                          32,
                          28,
                          28,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animated loading emblem.
                            _LoadingEmblem(
                              accentColor: accentColor,
                              icon: icon,
                            ),

                            const SizedBox(height: 26),

                            // Processing label.
                            Text(
                              'PLEASE WAIT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                                color: accentColor,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Dynamic operation message.
                            AnimatedSwitcher(
                              duration: const Duration(
                                milliseconds: 250,
                              ),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.12),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                message,
                                key: ValueKey(message),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ParishColors.textDark,
                                  height: 1.4,
                                ),
                              ),
                            ),

                            const SizedBox(height: 9),

                            Text(
                              'Your request is being processed. '
                                  'Please do not close this screen.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: ParishColors.textMuted,
                              ),
                            ),

                            const SizedBox(height: 25),

                            // Indeterminate progress indicator.
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                backgroundColor: const Color(0xFFE8EDF4),
                                color: accentColor,
                              ),
                            ),

                            const SizedBox(height: 19),

                            // Locked interaction indicator.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 13,
                                  color: ParishColors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'INTERACTIONS TEMPORARILY DISABLED',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.7,
                                      color: ParishColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated loading emblem with a rotating progress ring.
class _LoadingEmblem extends StatefulWidget {
  final Color accentColor;
  final IconData icon;

  const _LoadingEmblem({
    required this.accentColor,
    required this.icon,
  });

  @override
  State<_LoadingEmblem> createState() => _LoadingEmblemState();
}

class _LoadingEmblemState extends State<_LoadingEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 94,
          height: 94,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating outer progress ring.
              Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(94, 94),
                  painter: _LoadingRingPainter(accentColor: widget.accentColor),
                ),
              ),

              // Static inner emblem.
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.accentColor.withOpacity(0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.10),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: widget.accentColor,
                  size: 29,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom painter for the rotating loading ring.
class _LoadingRingPainter extends CustomPainter {
  final Color accentColor;

  const _LoadingRingPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    const strokeWidth = 3.5;
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = accentColor.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
      center,
      radius,
      trackPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(
        center: center,
        radius: radius,
      ),
      -math.pi / 2,
      math.pi * 1.25,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoadingRingPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

// =============================================================================
// PROGRAMMATIC LOADING BARRIER
// =============================================================================

/// Displays the same loading interface as SacramentalLoadingOverlay,
/// but through a non-dismissible modal barrier.
///
/// Example:
///
/// final loading = SacramentalLoadingBarrierController.show(
///   context,
///   initialMessage: 'Saving record...',
/// );
///
/// loading.updateMessage('Syncing ledger...');
///
/// loading.dismiss();
class SacramentalLoadingBarrierController {
  final BuildContext context;
  final Color accentColor;
  final IconData icon;
  final ValueNotifier<String> messageNotifier;

  bool _isShowing = false;
  BuildContext? _dialogContext;

  SacramentalLoadingBarrierController._(
      this.context,
      String initialMessage,
      this.accentColor,
      this.icon,
      ) : messageNotifier = ValueNotifier<String>(initialMessage);

  static SacramentalLoadingBarrierController show(
      BuildContext context, {
        String initialMessage = 'Please wait...',
        Color? accentColor,
        IconData icon = Icons.menu_book_rounded,
      }) {
    final controller = SacramentalLoadingBarrierController._(
      context,
      initialMessage,
      accentColor ?? ParishColors.marianBlue,
      icon,
    );

    controller._show();

    return controller;
  }

  void updateMessage(String newMessage) {
    if (_isShowing) {
      messageNotifier.value = newMessage;
    }
  }

  void _show() {
    _isShowing = true;

    final dialogFuture = showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      useSafeArea: false,
      barrierColor: Colors.black.withOpacity(0.48),
      builder: (dialogContext) {
        _dialogContext = dialogContext;

        return PopScope(
          canPop: false,
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) => KeyEventResult.handled,
            child: AbsorbPointer(
              absorbing: true,
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: ValueListenableBuilder<String>(
                    valueListenable: messageNotifier,
                    builder: (context, message, child) {
                      return _LoadingCard(
                        message: message,
                        accentColor: accentColor,
                        icon: icon,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    dialogFuture.whenComplete(() {
      _isShowing = false;
      _dialogContext = null;
      messageNotifier.dispose();
    });
  }

  void dismiss() {
    if (!_isShowing) return;

    _isShowing = false;

    final dialogContext = _dialogContext;

    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(
        dialogContext,
        rootNavigator: true,
      ).pop();
    } else if (context.mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();
    }
  }
}