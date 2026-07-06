import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/logging/log_entry.dart';
import '../../../services/logging/log_level.dart';

class LogListTile extends StatelessWidget {
  const LogListTile({super.key, required this.entry, required this.onTap});

  final LogEntry entry;
  final VoidCallback onTap;

  static final _fmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  Color _colorFor(LogLevel l) => switch (l) {
        LogLevel.debug => Colors.grey,
        LogLevel.info => Colors.blue,
        LogLevel.warning => Colors.orange,
        LogLevel.error => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(entry.level);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(entry.level.label,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(entry.tag,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(_fmt.format(entry.timestamp.toLocal())),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
