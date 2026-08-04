import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/chat.dart';
import '../../providers/chat_provider.dart';

/// Live chat between the driver and the customer (bridged to WhatsApp by the
/// message-service). The room is active from trip-accept until completion.
class ChatScreen extends StatefulWidget {
  final String tripId;
  final String driverRefId;
  final String customerRefId;
  final String orderId;
  final bool history; // read-only view of a past conversation

  const ChatScreen({
    super.key,
    required this.tripId,
    this.driverRefId = '',
    this.customerRefId = '',
    this.orderId = '',
    this.history = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chat = context.read<ChatProvider>();
      if (widget.history) {
        await chat.openHistory(widget.tripId);
      } else {
        await chat.open(
          widget.tripId,
          driverRefId: widget.driverRefId,
          customerRefId: widget.customerRefId,
          orderId: widget.orderId,
        );
      }
      chat.markRead();
      _jumpToEnd();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final ok = await context.read<ChatProvider>().send(text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat sudah ditutup')),
      );
    }
    _jumpToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    chat.messages.isNotEmpty ? _jumpToEnd() : null;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppTheme.surface,
        shape: const Border(bottom: BorderSide(color: AppTheme.surfaceBorder)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.brandCyan.withValues(alpha: 0.15),
              child: const Icon(Icons.person, color: AppTheme.brandCyanDark, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Customer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Row(
                  children: [
                    Icon(Icons.circle,
                        size: 8,
                        color: chat.active
                            ? AppTheme.success
                            : (chat.sessionExpired ? AppTheme.danger : AppTheme.textMuted)),
                    const SizedBox(width: 4),
                    Text(
                      chat.active
                          ? 'via WhatsApp • aktif'
                          : chat.sessionExpired
                              ? 'sesi berakhir — masuk lagi'
                              : (widget.history ? 'riwayat chat' : 'chat ditutup'),
                      style: TextStyle(
                          fontSize: 11,
                          color: chat.sessionExpired
                              ? AppTheme.danger
                              : AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.loading
                ? const Center(child: CircularProgressIndicator())
                : chat.messages.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: chat.messages.length,
                        itemBuilder: (_, i) => _bubble(chat.messages[i]),
                      ),
          ),
          _composer(chat.active),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          const Text('Belum ada pesan',
              style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          const Text('Sapa customer untuk memulai',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final isDriver = m.isDriver;
    return Align(
      alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isDriver ? AppTheme.brandCyanDark : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isDriver ? 18 : 5),
            bottomRight: Radius.circular(isDriver ? 5 : 18),
          ),
          border: isDriver ? null : Border.all(color: AppTheme.surfaceBorder),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Column(
          crossAxisAlignment:
              isDriver ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              m.text,
              style: TextStyle(
                color: isDriver ? Colors.white : AppTheme.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _time(m.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isDriver ? Colors.white70 : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _composer(bool active) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: active,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: active ? 'Ketik pesan…' : 'Chat sudah ditutup',
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: active ? AppTheme.brandCyanDark : AppTheme.textMuted,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: active ? _send : null,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
