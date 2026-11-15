// =============================================================================
// FILE: lib/features/asset_inventory/presentation/widgets/asset_loading_overlay.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

/// Full-page non-dismissible loading overlay that intercepts all interactions
/// (clicks, taps, scrolling, keyboard input, and Android system back gestures).
///
/// Can be used as a wrapper widget around a page/dialog content or triggered
/// via [showAssetLoadingBarrier].
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
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: PopScope(
              canPop: false,
              child: Container(
                color: Colors.black.withOpacity(0.58),
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                      decoration: BoxDecoration(
                        color: ParishColors.cardWhite,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: ParishColors.borderGrey.withOpacity(0.6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.22),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: ParishColors.marianBlueSurface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ParishColors.marianBlue.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3.0,
                                  color: ParishColors.marianBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: ParishColors.textDark,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please keep this screen open while the operation completes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: ParishColors.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Helper to programmatically show a non-dismissible modal loading barrier
/// over the current navigation context, driven by a [ValueNotifier<String>] status message.
class AssetLoadingBarrierController {
  final BuildContext context;
  final ValueNotifier<String> messageNotifier;
  bool _isShowing = false;

  AssetLoadingBarrierController._(this.context, String initialMessage)
      : messageNotifier = ValueNotifier<String>(initialMessage);

  static AssetLoadingBarrierController show(BuildContext context, {String initialMessage = 'Please wait...'}) {
    final controller = AssetLoadingBarrierController._(context, initialMessage);
    controller._show();
    return controller;
  }

  void updateMessage(String newMessage) {
    messageNotifier.value = newMessage;
  }

  void _show() {
    _isShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      barrierColor: Colors.black.withOpacity(0.58),
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ValueListenableBuilder<String>(
                valueListenable: messageNotifier,
                builder: (context, msg, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: ParishColors.marianBlueSurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.0,
                              color: ParishColors.marianBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        msg,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Interactions are locked to safeguard inventory data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: ParishColors.textMuted,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void dismiss() {
    if (_isShowing) {
      _isShowing = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
    messageNotifier.dispose();
  }
}