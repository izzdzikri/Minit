import 'package:material_ui/material_ui.dart';

/// Displays an AlertDialog with a single text input whose [TextEditingController]
/// stays alive until the dialog route finishes animating closed.
Future<String?> showTextPromptDialog({
  required BuildContext context,
  required String title,
  String initialValue = '',
  String? labelText,
  String? hintText,
  String confirmLabel = 'Save',
  bool allowEmpty = false,
  String emptyFallback = '',
  int maxLines = 1,
  int minLines = 1,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _TextPromptDialog(
      title: title,
      initialValue: initialValue,
      labelText: labelText,
      hintText: hintText,
      confirmLabel: confirmLabel,
      allowEmpty: allowEmpty,
      emptyFallback: emptyFallback,
      maxLines: maxLines,
      minLines: minLines,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initialValue,
    this.labelText,
    this.hintText,
    required this.confirmLabel,
    required this.allowEmpty,
    required this.emptyFallback,
    required this.maxLines,
    required this.minLines,
  });

  final String title;
  final String initialValue;
  final String? labelText;
  final String? hintText;
  final String confirmLabel;
  final bool allowEmpty;
  final String emptyFallback;
  final int maxLines;
  final int minLines;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) {
              Navigator.of(context).pop(
                widget.allowEmpty ? widget.emptyFallback : null,
              );
            } else {
              Navigator.of(context).pop(text);
            }
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
