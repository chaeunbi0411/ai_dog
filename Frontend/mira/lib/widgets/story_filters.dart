import 'package:flutter/material.dart';

enum StoryFilter { all, mine, liked }

bool matchesStory(
  Map<String, dynamic> story,
  String query,
  StoryFilter filter,
  String uid,
) {
  if (filter == StoryFilter.mine && story['authorUid'] != uid) return false;
  if (filter == StoryFilter.liked &&
      !(story['likedBy'] as List? ?? const []).contains(uid)) {
    return false;
  }
  final text = [
    story['authorName'],
    story['mood'],
    story['body'],
  ].whereType<String>().join(' ').toLowerCase();
  return query.trim().toLowerCase().split(RegExp(r'\s+')).every(text.contains);
}

class StoryFilters extends StatefulWidget {
  const StoryFilters({super.key, required this.onChanged});
  final void Function(String, StoryFilter) onChanged;
  @override
  State<StoryFilters> createState() => _StoryFiltersState();
}

class _StoryFiltersState extends State<StoryFilters> {
  final _query = TextEditingController();
  StoryFilter _filter = StoryFilter.all;
  void _notify() {
    setState(() {});
    widget.onChanged(_query.text, _filter);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _query,
        onChanged: (_) => _notify(),
        decoration: InputDecoration(
          labelText: '가족 이야기 검색',
          hintText: '이름, 기분, 내용으로 찾기',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '검색어 지우기',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _query.clear();
                    _notify();
                  },
                ),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final option in StoryFilter.values)
            ChoiceChip(
              label: Text(switch (option) {
                StoryFilter.all => '전체',
                StoryFilter.mine => '내 이야기',
                StoryFilter.liked => '좋아요 한 이야기',
              }),
              selected: _filter == option,
              onSelected: (_) {
                _filter = option;
                _notify();
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
    ],
  );
}
