import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI Chat Room: answers use only real recorded batch data (no forecasts).
class AiChatScreen extends StatefulWidget {
  final String batchId;
  final String batchName;
  const AiChatScreen({super.key, required this.batchId, required this.batchName});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const _endpoint =
      'https://free-pocket-companion.lovable.app/api/public/ai-advisor';
  final _supabase = Supabase.instance.client;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _msgs = [];
  bool _loading = true;
  bool _sending = false;

  static const _chips = [
    'Why is my mortality high?',
    'Is my weight OK?',
    'Am I above break-even?',
    'What should I check today?',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await _supabase
          .from('ai_chat_messages')
          .select('role, content, created_at')
          .eq('batch_id', widget.batchId)
          .order('created_at', ascending: true);
      _msgs
        ..clear()
        ..addAll(List<Map<String, dynamic>>.from(res));
    } catch (e) {
      _snack('Could not load chat history: $e');
    }
    if (mounted) setState(() => _loading = false);
    _toBottom();
  }

  Future<void> _save(String role, String content) async {
    try {
      await _supabase.from('ai_chat_messages').insert({
        'user_id': _supabase.auth.currentUser!.id,
        'batch_id': widget.batchId,
        'role': role,
        'content': content,
      });
    } catch (e) {
      _snack('Chat not saved: $e');
    }
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _sending) return;
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) {
      _snack('Please log in again.');
      return;
    }
    final history = _msgs
        .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
        .toList()
        .reversed
        .take(10)
        .toList()
        .reversed
        .map((m) => {'role': m['role'], 'content': m['content']})
        .toList();
    _input.clear();
    setState(() {
      _sending = true;
      _msgs.add({'role': 'user', 'content': q, 'created_at': DateTime.now().toIso8601String()});
      _msgs.add({'role': 'assistant', 'content': '', 'created_at': DateTime.now().toIso8601String()});
    });
    _toBottom();
    _save('user', q);

    final client = HttpClient();
    final buf = StringBuffer();
    try {
      final req = await client.postUrl(Uri.parse(_endpoint));
      req.headers.set('content-type', 'application/json');
      req.headers.set('authorization', 'Bearer $token');
      req.add(utf8.encode(jsonEncode({'batch_id': widget.batchId, 'question': q, 'history': history})));
      final res = await req.close();
      if (res.statusCode != 200) {
        final body = await res.transform(utf8.decoder).join();
        String msg = 'AI error (${res.statusCode})';
        try {
          msg = (jsonDecode(body)['error'] ?? msg).toString();
        } catch (_) {}
        buf.write('⚠️ $msg');
      } else {
        await for (final chunk in res.transform(utf8.decoder)) {
          buf.write(chunk);
          setState(() => _msgs.last['content'] = buf.toString());
          _toBottom();
        }
        if (buf.isEmpty) buf.write('⚠️ AI is busy or out of credits. Please try again later.');
      }
    } catch (e) {
      buf.write('⚠️ No internet connection or server not reachable.');
    } finally {
      client.close();
    }
    setState(() {
      _msgs.last['content'] = buf.toString();
      _sending = false;
    });
    if (!buf.toString().startsWith('⚠️')) _save('assistant', buf.toString());
    _toBottom();
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('All messages for this batch will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await _supabase.from('ai_chat_messages').delete().eq('batch_id', widget.batchId);
    setState(() => _msgs.clear());
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Widget _bubble(Map<String, dynamic> m) {
    final me = m['role'] == 'user';
    final t = DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal();
    final txt = (m['content'] ?? '').toString();
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: me ? Colors.teal.shade700 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            txt.isEmpty
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : SelectableText(txt.replaceAll('**', ''),
                    style: TextStyle(color: me ? Colors.white : Colors.black87, fontSize: 14)),
            if (t != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(DateFormat('dd MMM, hh:mm a').format(t),
                    style: TextStyle(fontSize: 10, color: me ? Colors.white70 : Colors.black45)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Chat', style: TextStyle(fontSize: 18)),
            Text('${widget.batchName} • live data', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.delete_sweep_outlined), tooltip: 'Clear chat', onPressed: _clear),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _msgs.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Ask anything about this batch.\nAnswers use your recorded data only.',
                              textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _msgs.length,
                        itemBuilder: (_, i) => _bubble(_msgs[i]),
                      ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _chips
                  .map((c) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(label: Text(c, style: const TextStyle(fontSize: 12)), onPressed: _sending ? null : () => _send(c)),
                      ))
                  .toList(),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: 'Type your question...',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _sending ? null : () => _send(_input.text),
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
