import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/key_pipeline.dart';
import '../theme.dart';

class TvTextField extends StatefulWidget {
  const TvTextField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.validator,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  final _focusNode = FocusNode(debugLabel: 'edit-${UniqueKey()}');
  final _editorFocusNode = FocusNode(debugLabel: 'text-editor');
  bool _editing = false;
  String? _error;
  String _originalValue = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !_editing) {
        KeyPipeline.instance.setMode(InputMode.editor);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  Future<void> _enterEditing() async {
    _originalValue = widget.controller.text;
    setState(() => _editing = true);
    await Future<void>.delayed(Duration.zero);
    _editorFocusNode.requestFocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    KeyPipeline.instance.setMode(InputMode.editingText);
  }

  Future<void> _finish({required bool commit}) async {
    if (!commit) widget.controller.text = _originalValue;
    final error = widget.validator?.call(widget.controller.text);
    if (commit && error != null) {
      setState(() => _error = error);
      return;
    }
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (!mounted) return;
    setState(() {
      _editing = false;
      _error = error;
    });
    KeyPipeline.instance.setMode(InputMode.editor);
    _focusNode.requestFocus();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.goBack) {
            _finish(commit: false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: widget.controller,
          autofocus: true,
          focusNode: _editorFocusNode,
          keyboardType: widget.keyboardType,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _finish(commit: true),
          onChanged: (_) => widget.onChanged(),
          decoration: InputDecoration(labelText: widget.label),
        ),
      );
    }

    final focused = _focusNode.hasFocus;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _enterEditing();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: focused ? const Color(0xFF17122A) : const Color(0xFF0E0B14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: focused ? bingeYellow : bingeDivider,
            width: focused ? 2 : 1,
          ),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _enterEditing,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.controller.text,
                      style: const TextStyle(color: Colors.white, fontSize: 21),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.edit, color: focused ? bingeYellow : Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
