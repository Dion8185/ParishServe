
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

/// Full-page, non-dismissible loading overlay.
///
/// Blocks pointer interaction, keyboard input, scrolling, and back navigation
/// while an operation is running.
class AssetLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final Widget child;

  const AssetLoadingOverlay({
    super.key,
    required this.isLoading,
    this.message = 'Processing...',
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
            ),
          ),
      ],
    );
  }
}

/// Shared blocking layer used by the page overlay.
class _BlockingLoadingLayer extends StatelessWidget {
  final String message;

  const _BlockingLoadingLayer({
    required this.message,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared loading card for consistent appearance.
class _LoadingCard extends StatelessWidget {
  final String message;

  const _LoadingCard({
    required this.message,
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
                      // Marian Blue and gold accent.
                      Container(
                        height: 4,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ParishColors.marianBlue,
                              Color(0xFFD4A63A),
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
                            const _LoadingEmblem(),

                            const SizedBox(height: 26),

                            // Processing label.
                            const Text(
                              'PLEASE WAIT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                                color: ParishColors.marianBlue,
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
                              child: const LinearProgressIndicator(
                                minHeight: 3,
                                backgroundColor: Color(0xFFE8EDF4),
                                color: ParishColors.marianBlue,
                              ),
                            ),

                            const SizedBox(height: 19),

                            // Locked interaction indicator.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 13,
                                  color: ParishColors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'INTERACTIONS TEMPORARILY DISABLED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7,
                                    color: ParishColors.textMuted,
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

/// Animated Marian Blue loading emblem with a rotating progress ring.
class _LoadingEmblem extends StatefulWidget {
  const _LoadingEmblem();

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
                  painter: _LoadingRingPainter(),
                ),
              ),

              // Static inner emblem.
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ParishColors.marianBlue.withOpacity(0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ParishColors.marianBlue.withOpacity(0.10),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: ParishColors.marianBlue,
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
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    const strokeWidth = 3.5;
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = ParishColors.marianBlue.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = ParishColors.marianBlue
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// PROGRAMMATIC LOADING BARRIER
// =============================================================================

/// Displays the same loading interface as AssetLoadingOverlay,
/// but through a modal barrier.
///
/// Example:
///
/// final loading = AssetLoadingBarrierController.show(
///   context,
///   initialMessage: 'Saving asset...',
/// );
///
/// loading.updateMessage('Processing image...');
///
/// loading.dismiss();
class AssetLoadingBarrierController {
  final BuildContext context;

  final ValueNotifier<String> messageNotifier;

  bool _isShowing = false;
  BuildContext? _dialogContext;

  AssetLoadingBarrierController._(
      this.context,
      String initialMessage,
      ) : messageNotifier = ValueNotifier<String>(initialMessage);

  static AssetLoadingBarrierController show(
      BuildContext context, {
        String initialMessage = 'Please wait...',
      }) {
    final controller = AssetLoadingBarrierController._(
      context,
      initialMessage,
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
