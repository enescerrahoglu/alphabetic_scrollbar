import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlphabeticScrollbar extends StatefulWidget {
  final ScrollController? scrollController;
  final ValueChanged<String>? onLetterSelected;
  final ScrollbarOrientation? scrollbarOrientation;

  const AlphabeticScrollbar({
    super.key,
    this.scrollController,
    this.onLetterSelected,
    this.scrollbarOrientation = ScrollbarOrientation.right,
  });

  @override
  State<AlphabeticScrollbar> createState() => _AlphabeticScrollbarState();
}

class _AlphabeticScrollbarState extends State<AlphabeticScrollbar> with SingleTickerProviderStateMixin {
  final List<String> _alphabets = [
    'A',
    'B',
    'C',
    'Ç',
    'D',
    'E',
    'F',
    'G',
    'Ğ',
    'H',
    'I',
    'İ',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'Ö',
    'P',
    'Q',
    'R',
    'S',
    'Ş',
    'T',
    'U',
    'Ü',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  final GlobalKey _barKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;
  Timer? _hideTimer;
  final ValueNotifier<String?> _hoveredLetter = ValueNotifier(null);

  late final AnimationController _visibilityController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  bool get _alwaysVisible => widget.scrollController == null;

  bool get _isRightOriented =>
      widget.scrollbarOrientation == ScrollbarOrientation.right || widget.scrollbarOrientation == null;

  @override
  void initState() {
    super.initState();
    _visibilityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _alwaysVisible ? 1.0 : 0.0,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _visibilityController, curve: Curves.easeInOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _visibilityController, curve: Curves.easeInOut));

    if (!_alwaysVisible) {
      widget.scrollController!.addListener(_onScroll);
    }
  }

  void _onScroll() {
    _visibilityController.forward();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _visibilityController.reverse();
      }
    });
  }

  String? _getLetterFromOffset(Offset globalPosition) {
    final RenderBox? box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;

    final localPos = box.globalToLocal(globalPosition);
    final totalHeight = box.size.height;
    final index = (localPos.dy / totalHeight * _alphabets.length).floor().clamp(0, _alphabets.length - 1);
    return _alphabets[index];
  }

  void _handleLetterSelection(String letter) {
    if (_hoveredLetter.value == letter) return;
    _hoveredLetter.value = letter;
    widget.onLetterSelected?.call(letter);
    _showLetterOverlay(letter);
    HapticFeedback.mediumImpact();
  }

  void _showLetterOverlay(String letter) {
    _overlayTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Center(
        child: IgnorePointer(child: AnimatedLetterBubble(letter: letter)),
      ),
    );

    overlay.insert(_overlayEntry!);

    _overlayTimer = Timer(const Duration(milliseconds: 500), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _hoveredLetter.value = null;
    });
  }

  @override
  void dispose() {
    if (!_alwaysVisible) {
      widget.scrollController?.removeListener(_onScroll);
    }
    _hideTimer?.cancel();
    _overlayTimer?.cancel();
    _overlayEntry?.remove();
    _visibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget bar = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final letter = _getLetterFromOffset(details.globalPosition);
        if (letter != null) _handleLetterSelection(letter);
      },
      onVerticalDragUpdate: (details) {
        final letter = _getLetterFromOffset(details.globalPosition);
        if (letter != null) _handleLetterSelection(letter);
      },
      onVerticalDragEnd: (_) => _hoveredLetter.value = null,
      child: Padding(
        padding: EdgeInsets.only(left: 4.0, right: 4.0, top: MediaQuery.of(context).padding.top + kToolbarHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 1,
          key: _barKey,
          mainAxisSize: MainAxisSize.min,
          children: _alphabets
              .map(
                (letter) => Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ValueListenableBuilder(
                      valueListenable: _hoveredLetter,
                      builder: (context, hovered, child) {
                        final isHovered = hovered == letter;
                        return Text(
                          letter,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
                            color: isHovered ? colorScheme.primaryFixed : colorScheme.outlineVariant,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (_alwaysVisible) return bar;
    return SafeArea(
      child: AnimatedBuilder(
        animation: _visibilityController,
        builder: (context, child) {
          final slideOffset = _isRightOriented ? Offset(_slideAnimation.value, 0) : Offset(-_slideAnimation.value, 0);

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(position: AlwaysStoppedAnimation(slideOffset), child: child),
          );
        },
        child: bar,
      ),
    );
  }
}

class AnimatedLetterBubble extends StatefulWidget {
  final String letter;
  const AnimatedLetterBubble({super.key, required this.letter});

  @override
  State<AnimatedLetterBubble> createState() => _AnimatedLetterBubbleState();
}

class _AnimatedLetterBubbleState extends State<AnimatedLetterBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _opacityAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _opacityAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 80, maxHeight: 80),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryFixed,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: const Offset(0, 0))],
            ),
            child: Text(
              widget.letter,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                height: 1,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
