import 'package:flutter/material.dart';

class RecordPagination extends StatelessWidget {
  const RecordPagination({
    super.key,
    required this.page,
    required this.pages,
    required this.onChanged,
  });
  final int page;
  final int pages;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton(
        onPressed: page > 1 ? () => onChanged(page - 1) : null,
        child: const Text('Previous'),
      ),
      Semantics(liveRegion: true, child: Text('Page $page of $pages')),
      OutlinedButton(
        onPressed: page < pages ? () => onChanged(page + 1) : null,
        child: const Text('Next'),
      ),
    ],
  );
}
