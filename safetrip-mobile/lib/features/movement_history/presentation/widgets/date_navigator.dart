import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final DateTime? minDate;
  final DateTime? maxDate;

  const DateNavigator({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.minDate,
    this.maxDate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _canGoBack ? () => _changeDate(-1) : null,
        ),
        GestureDetector(
          onTap: () => _showDatePicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              DateFormat('yyyy.MM.dd (E)', 'ko').format(selectedDate),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _canGoForward ? () => _changeDate(1) : null,
        ),
      ],
    );
  }

  bool get _canGoBack => minDate == null || selectedDate.isAfter(minDate!);
  bool get _canGoForward => maxDate == null || selectedDate.isBefore(maxDate!);

  void _changeDate(int days) {
    onDateChanged(selectedDate.add(Duration(days: days)));
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: minDate ?? DateTime(2024),
      lastDate: maxDate ?? DateTime.now(),
    );
    if (picked != null) onDateChanged(picked);
  }
}
