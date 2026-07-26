import 'package:flutter/material.dart';

class AppAnimationButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final Color? colorBg;
  final Color? colorPressed;
  final Color? colorHover;
  final double vertical;
  final double horizontal;
  final double borderSide;
  final double borderSideActive;
  final double borderRadius;

  const AppAnimationButton({
    super.key,
    required this.child,
    this.onPressed,
    required this.color,
    this.colorBg,
    this.colorPressed,
    this.colorHover,
    this.vertical = 13,
    this.horizontal = 5,
    this.borderSide = 1,
    this.borderSideActive = 2,
    this.borderRadius = 10,
  });

  @override
  State<AppAnimationButton> createState() => _AppAnimationButtonState();
}

class _AppAnimationButtonState extends State<AppAnimationButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  // состояние для hover + сброс если ушел
  void _setHovered(bool value) {
    if (widget.onPressed == null) return;

    setState(() {
      _isHovered = value;
      if (!value) {
        _isPressed = false;
      }
    });
  }

  // состояние для pressed
  void _setPressed(bool value) {
    if (widget.onPressed == null) return;

    setState(() {
      _isPressed = value;
    });
  }

  // проверка на наличие кнопки + смена состояния
  void _resetPressed() {
    if (!mounted) return;

    setState(() {
      _isPressed = false;
    });
  }

  // сброс состояние после нажатия (доп функция)
  void _handleTap() {
    if (widget.onPressed == null) return;
    _resetPressed();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = _isPressed
        ? widget.colorPressed ?? widget.color.withValues(alpha: 0.4)
        : _isHovered
        ? widget.colorHover ?? widget.color.withValues(alpha: 0.2)
        : widget.colorBg ?? widget.color.withValues(alpha: 0.07);

    final double currentBorderSide = _isHovered || _isPressed
        ? widget.borderSideActive
        : widget.borderSide;

    return MouseRegion(
      cursor: widget.onPressed == null
          ? SystemMouseCursors.disappearing
          : SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _resetPressed(),
        onTapCancel: _resetPressed,
        child: AnimatedScale(
          scale: _isPressed
              ? 0.999
              : _isHovered
              ? 1.009
              : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.symmetric(
              vertical: widget.vertical,
              horizontal: widget.horizontal,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: widget.color, width: currentBorderSide),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
