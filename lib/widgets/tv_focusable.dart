import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.builder,
    this.focusNode,
    this.autofocus = false,
    this.onSelected,
    this.onFocusChange,
    this.scaleOnFocus = true,
    this.scaleValue = 1.08,
    this.borderRadius = 16,
    this.focusedBorderColor = bingeYellow,
    this.unfocusedBorderColor = bingeDeepPurple,
    this.borderWidth = 3,
    this.padding,
    this.backgroundColor = bingeDarkBg,
    this.focusedBackgroundColor,
  });

  final Widget Function(BuildContext context, bool focused) builder;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onSelected;
  final ValueChanged<bool>? onFocusChange;
  final bool scaleOnFocus;
  final double scaleValue;
  final double borderRadius;
  final Color focusedBorderColor;
  final Color unfocusedBorderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final Color backgroundColor;
  final Color? focusedBackgroundColor;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _isFocused = false;

  static final Map<ShortcutActivator, Intent> _tvShortcuts = {
    const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter):
        const ActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonA):
        const ActivateIntent(),
  };

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _tvShortcuts,
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onSelected?.call();
              return null;
            },
          ),
        },
        child: FocusableActionDetector(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onFocusChange: (focused) {
            setState(() => _isFocused = focused);
            widget.onFocusChange?.call(focused);
          },
          mouseCursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onSelected,
            child: AnimatedScale(
              scale: (widget.scaleOnFocus && _isFocused)
                  ? widget.scaleValue
                  : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: _isFocused
                      ? (widget.focusedBackgroundColor ??
                            widget.backgroundColor)
                      : widget.backgroundColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: _isFocused
                        ? widget.focusedBorderColor
                        : widget.unfocusedBorderColor,
                    width: _isFocused
                        ? widget.borderWidth + 1
                        : widget.borderWidth,
                  ),
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(
                            color: bingePurple.withValues(alpha: 0.8),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: widget.builder(context, _isFocused),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
