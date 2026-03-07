import 'package:flutter/material.dart';

class AiFeedbackWidget extends StatefulWidget {
  final String logId;
  final Future<void> Function(String logId, int feedback)? onFeedback;

  const AiFeedbackWidget({super.key, required this.logId, this.onFeedback});

  @override
  State<AiFeedbackWidget> createState() => _AiFeedbackWidgetState();
}

class _AiFeedbackWidgetState extends State<AiFeedbackWidget> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '이 응답이 도움이 되었나요?',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        _feedbackButton(Icons.thumb_up_outlined, 1),
        const SizedBox(width: 4),
        _feedbackButton(Icons.thumb_down_outlined, -1),
      ],
    );
  }

  Widget _feedbackButton(IconData icon, int value) {
    final isSelected = _selected == value;
    return InkWell(
      onTap: () async {
        setState(() => _selected = value);
        await widget.onFeedback?.call(widget.logId, value);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.blue : Colors.grey,
        ),
      ),
    );
  }
}
