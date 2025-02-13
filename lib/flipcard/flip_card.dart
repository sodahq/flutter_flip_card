import 'package:flutter/material.dart';
import '../modal/flip_side.dart';
import '../controllers/flip_card_controllers.dart';
import 'dart:math';

enum CardSide { front, back }

class AnimationListenerResult {
  final Matrix4 transform;
  final Matrix4 transformBack;
  final bool isFront;

  const AnimationListenerResult(
    this.transform,
    this.transformBack,
    this.isFront,
  );
}

/// [FlipCard] A component that provides a flip card animation

class FlipCard extends StatefulWidget {
  /// [controller] used to ccontrol the flip
  final FlipCardController? controller;

  ///[frontWidget] The Front side widget of the card
  final Widget frontWidget;

  ///[backWidget] The Back side widget of the card
  final Widget backWidget;

  /// [onTapFlipping]  When enabled, the card will flip automatically when touched.
  final bool onTapFlipping;

  /// [axis] The flip axis [Horizontal] and [Vertical]
  final FlipAxis axis;

  /// [animationDuration] The amount of milliseconds a turn animation will take.
  final Duration animationDuration;

  /// [disableSplashEffect] The option for disable Inkwell widget's splash effect.
  final bool disableSplashEffect;

  /// [splashColor] The option for Inkwell widget's splashColor.
  final Color? splashColor;

  /// [focusColor] The option for Inkwell widget's focusColor.
  final Color? focusColor;

  /// [initialSide] Default is front
  final CardSide initialSide;

  /// [timeForFirstPart] The percentage of the total animation time that will be used for the first part of the flip.
  /// This value should be between 0 and 1. For example, a value of 0.3 means the first 30% of the animation time will
  /// be used to complete 70% of the flip process. You can adjust this to control the speed distribution of the flip.
  final double timeForFirstPart;

  /// [processForFirstPart] The percentage of the total flip process that will be completed in the first part of the animation.
  /// This value should be between 0 and 1. For example, a value of 0.7 means that 70% of the flip process will occur in the
  /// first part of the animation, which lasts for [timeForFirstPart] of the total animation time.
  final double processForFirstPart;

  const FlipCard({
    Key? key,
    this.focusColor,
    this.splashColor,
    this.onTapFlipping = false,
    this.disableSplashEffect = false,
    required this.frontWidget,
    required this.backWidget,
    this.controller,
    this.axis = FlipAxis.vertical,
    this.initialSide = CardSide.front,
    this.timeForFirstPart = 0.2,
    this.processForFirstPart = 0.75,
    this.animationDuration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  FlipCardState createState() => FlipCardState();
}

class FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final _flipCardController = FlipCardController();
  late final ValueNotifier<Matrix4> _transformNotifier;
  late final ValueNotifier<Matrix4> _transformBackNotifier;
  late final ValueNotifier<bool> _shouldDisplayFrontCard;
  late bool _isFront;
  double _anglePlus = 0;

  @override
  void initState() {
    super.initState();
    _isFront = widget.initialSide == CardSide.front;

    if (!_isFront) {
      _anglePlus = pi;
    }

    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    widget.controller?.state = this;
    _flipCardController.state = this;

    if (!_isFront) _animationController.animateTo(1.0);

    final res = _calculateTransforms();

    _transformNotifier = ValueNotifier(res.transform);
    _transformBackNotifier = ValueNotifier(res.transformBack);
    _shouldDisplayFrontCard = ValueNotifier(res.isFront);

    _animationController.addListener(_handleAnimationListener);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  ///Flip the card
  Future flipCard() async {
    if (_animationController.isAnimating) return;
    _isFront = !_isFront;
    await _animationController
        .forward(from: 0)
        .then((value) => _anglePlus = pi);
  }

  void _handleAnimationListener() {
    final res = _calculateTransforms();

    if (res.transform != _transformNotifier.value) {
      _transformNotifier.value = res.transform;
    }
    if (res.transformBack != _transformBackNotifier.value) {
      _transformBackNotifier.value = res.transformBack;
    }
    if (res.isFront != _shouldDisplayFrontCard.value) {
      _shouldDisplayFrontCard.value = res.isFront;
    }
  }

  AnimationListenerResult _calculateTransforms() {
    double piValue = 0.0;

    if (_isFront) {
      piValue = -pi;
    } else {
      piValue = pi;
    }

    final double adjustedValue = _animationController.value;

    final double timeFactor;

    if (adjustedValue < widget.timeForFirstPart) {
      timeFactor =
          adjustedValue / widget.timeForFirstPart * widget.processForFirstPart;
    } else {
      final double remainingTime = adjustedValue - widget.timeForFirstPart;
      final double secondPartTime = 1 - widget.timeForFirstPart;
      final double remainingProcess = 1 - widget.processForFirstPart;

      timeFactor = widget.processForFirstPart +
          (remainingTime / secondPartTime) * remainingProcess;
    }

    double angle = timeFactor * piValue;

    // Make sure the angle stays within 0 to pi or -pi
    // angle = angle.clamp(-pi, pi);

    late Matrix4 transform;
    late Matrix4 transformForBack;

    if (_isFront) angle += _anglePlus;

    if (widget.axis == FlipAxis.horizontal) {
      transform = Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(angle);
      transformForBack = Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(angle + pi); // nếu là horizontal
    } else {
      transform = Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(angle);
      transformForBack = Matrix4.identity()..rotateY(pi);
    }

    final bool shouldDisplayFrontCard = _isFrontWidget(angle.abs());

    return AnimationListenerResult(
      transform,
      transformForBack,
      shouldDisplayFrontCard,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTapFlipping == false
            ? null
            : () {
                _flipCardController.state!.flipCard();
              },
        child: ValueListenableBuilder<bool>(
          valueListenable: _shouldDisplayFrontCard,
          builder: (context, isFront, child) {
            return IndexedStack(
              clipBehavior: Clip.none,
              index: isFront ? 0 : 1,
              children: [
                ValueListenableBuilder(
                  valueListenable: _transformNotifier,
                  builder: (context, Matrix4 transform, child) {
                    return Transform(
                      alignment: Alignment.center,
                      transform: transform,
                      child: child,
                    );
                  },
                  child: widget.frontWidget,
                ),
                ValueListenableBuilder(
                  valueListenable: _transformNotifier,
                  builder: (context, Matrix4 transform, child) {
                    return Transform(
                      alignment: Alignment.center,
                      transform: transform,
                      child: child,
                    );
                  },
                  child: ValueListenableBuilder(
                    valueListenable: _transformBackNotifier,
                    builder: (context, Matrix4 transform, child) {
                      return Transform(
                        transform: transform,
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                    child: widget.backWidget,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _isFrontWidget(double angle) {
    const degrees90 = pi / 2;
    const degrees270 = 3 * pi / 2;
    return angle <= degrees90 || angle >= degrees270;
  }
}
