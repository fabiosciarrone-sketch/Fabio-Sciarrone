import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _chats = [
    {
      'name': 'Marco R.',
      'lastMessage': 'Ciao! Sei ancora in zona bar?',
      'time': '10:45',
      'unread': 1,
      'avatar': 'M',
      'messages': [
        {'text': 'Ciao Giuseppe! Come va?', 'isMe': false, 'time': '10:40'},
        {'text': 'Tutto bene, tu?', 'isMe': true, 'time': '10:42'},
        {
          'text': 'Ciao! Sei ancora in zona bar?',
          'isMe': false,
          'time': '10:45',
        },
      ],
    },
    {
      'name': 'Sara B.',
      'lastMessage': 'Perfetto, ci aggiorniamo dopo!',
      'time': 'Ieri',
      'unread': 0,
      'avatar': 'S',
      'messages': [
        {'text': 'Ci vediamo al workshop?', 'isMe': true, 'time': '16:15'},
        {
          'text': 'Perfetto, ci aggiorniamo dopo!',
          'isMe': false,
          'time': '16:20',
        },
      ],
    },
    {
      'name': 'Alex V.',
      'lastMessage': 'Ho visto che ti occupi di Flutter!',
      'time': '2 gg fa',
      'unread': 0,
      'avatar': 'A',
      'messages': [
        {
          'text': 'Ho visto che ti occupi di Flutter!',
          'isMe': false,
          'time': '14:00',
        },
      ],
    },
  ];

  void _openChatDetail(Map<String, dynamic> chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          chat: chat,
          onMessageSent: (newMessage) {
            setState(() {
              chat['lastMessage'] = newMessage;
              chat['time'] = 'Ora';
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaggi & Chat'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                child: Text(
                  chat['avatar'],
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                chat['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                chat['lastMessage'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    chat['time'],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (chat['unread'] > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${chat['unread']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              onTap: () {
                setState(() {
                  chat['unread'] = 0;
                });
                _openChatDetail(chat);
              },
            ),
          );
        },
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> chat;
  final Function(String) onMessageSent;

  const ChatDetailScreen({
    super.key,
    required this.chat,
    required this.onMessageSent,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        (widget.chat['messages'] as List).add({
          'text': text,
          'isMe': true,
          'time': 'Ora',
        });
      });
      widget.onMessageSent(text);
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List messages = widget.chat['messages'];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chat['name']),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['isMe'] ?? false;
                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.deepPurple : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isMe ? const Radius.circular(0) : null,
                        bottomLeft: !isMe ? const Radius.circular(0) : null,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['text'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          msg['time'],
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Scrivi un messaggio...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
