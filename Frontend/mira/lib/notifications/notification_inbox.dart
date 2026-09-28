import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../widgets/word_wrap_text.dart';

class NotificationInbox extends StatefulWidget {
  const NotificationInbox({
    super.key,
    required this.userId,
    this.notifications,
    this.markRead,
  });
  final String? userId;
  final Stream<List<Map<String, dynamic>>>? notifications;
  final Future<void> Function(List<String>)? markRead;
  @override
  State<NotificationInbox> createState() => _NotificationInboxState();
}

class _NotificationInboxState extends State<NotificationInbox> {
  late Stream<List<Map<String, dynamic>>> _stream = _connect();
  bool _unreadOnly = false, _saving = false;
  Stream<List<Map<String, dynamic>>> _connect() =>
      widget.notifications ??
      (widget.userId == null
          ? Stream.value([])
          : NotificationService.instance.watchRecent(widget.userId!));

  Future<void> _read(List<String> ids) async {
    if (_saving || ids.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (widget.markRead != null) {
        await widget.markRead!(ids);
      } else if (widget.userId != null) {
        await NotificationService.instance.markManyRead(widget.userId!, ids);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('읽음 상태를 저장하지 못했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _date(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate().toLocal();
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('알림함')),
    body: widget.userId == null && widget.notifications == null
        ? const Center(child: Text('로그인 후 알림을 볼 수 있어요.'))
        : StreamBuilder<List<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('알림을 불러오지 못했어요.'),
                      TextButton(
                        onPressed: () => setState(() => _stream = _connect()),
                        child: const Text('재시도'),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snapshot.data!;
              final unread = all.where((n) => n['isRead'] != true).toList();
              final visible = _unreadOnly ? unread : all;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilterChip(
                          label: Text('안 읽은 알림 ${unread.length}'),
                          selected: _unreadOnly,
                          onSelected: (v) => setState(() => _unreadOnly = v),
                        ),
                        TextButton(
                          onPressed: _saving || unread.isEmpty
                              ? null
                              : () => _read(
                                  unread.map((n) => n['id'] as String).toList(),
                                ),
                          child: const Text('표시된 알림 모두 읽음'),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('최근 알림 100개를 보여드려요.'),
                  ),
                  if (_saving) const LinearProgressIndicator(),
                  Expanded(
                    child: visible.isEmpty
                        ? Center(
                            child: Text(
                              _unreadOnly ? '안 읽은 알림이 없어요.' : '아직 받은 알림이 없어요.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final item = visible[index];
                              final read = item['isRead'] == true;
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    read
                                        ? Icons.notifications_none
                                        : Icons.notifications_active,
                                    color: read
                                        ? null
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                  title: WordWrapText(
                                    item['title'] as String? ?? '가족 소식',
                                    style: TextStyle(
                                      fontWeight: read
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      WordWrapText(
                                        item['message'] as String? ?? '',
                                      ),
                                      const SizedBox(height: 6),
                                      Text(_date(item['createdAt'])),
                                      if (!read) const Text('탭하여 읽음으로 표시'),
                                    ],
                                  ),
                                  onTap: read || _saving
                                      ? null
                                      : () => _read([item['id'] as String]),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
  );
}
