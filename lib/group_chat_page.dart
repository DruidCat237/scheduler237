import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;

  const GroupChatPage({Key? key, required this.groupId}) : super(key: key);

  @override
  _GroupChatPageState createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = true;
  bool _isLoading = false;
  static const int _maxMessageLength = 237;
  static const int _maxTotalMessages = 237;
  late Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _initMessagesStream();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _initMessagesStream() {
    _messagesStream = FirebaseFirestore.instance
        .collection('group_messages')
        .where('groupId', isEqualTo: widget.groupId)
        .orderBy('timestamp', descending: true)
        .limit(_maxTotalMessages)
        .snapshots();
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      setState(() {
        _isAtBottom = true;
      });
    } else {
      setState(() {
        _isAtBottom = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorSnackBar('No internet connection. Please try again later.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final messageText = _messageController.text.trim().substring(
          0, _maxMessageLength.clamp(0, _messageController.text.trim().length));
      final messagesRef =
          FirebaseFirestore.instance.collection('group_messages');

      // Check total message count
      final messageCount = await messagesRef
          .where('groupId', isEqualTo: widget.groupId)
          .count()
          .get();

      if (messageCount.count! >= _maxTotalMessages) {
        _showLimitReachedDialog();
      } else {
        await messagesRef.add({
          'groupId': widget.groupId,
          'senderId': user.uid,
          'message': messageText,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _messageController.clear();
        if (_isAtBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0.0,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error sending message: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Message Limit Reached'),
          content: Text(
              'The chat has reached the maximum limit of 237 messages. You can clear the chat and start anew.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Clear Chat'),
              onPressed: () {
                _deleteAllMessages();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAllMessages() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorSnackBar('No internet connection. Please try again later.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final messages = await FirebaseFirestore.instance
          .collection('group_messages')
          .where('groupId', isEqualTo: widget.groupId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      _showSuccessSnackBar('All messages have been deleted');
    } catch (e) {
      _showErrorSnackBar('Error deleting messages: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Chat'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep),
            onPressed: _deleteAllMessages,
            tooltip: 'Delete All Messages',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final isCurrentUser = message['senderId'] ==
                        FirebaseAuth.instance.currentUser?.uid;

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(message['senderId'])
                          .get(),
                      builder: (context, snapshot) {
                        String senderName = 'Unknown User';
                        if (snapshot.hasData && snapshot.data != null) {
                          final userData =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          senderName = userData?['nickname'] ?? 'Unknown User';
                        }

                        return Align(
                          alignment: isCurrentUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? Colors.blue[100]
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(senderName,
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text(message['message']),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      counterText:
                          '${_messageController.text.length}/$_maxMessageLength',
                    ),
                    maxLength: _maxMessageLength,
                    buildCounter: (BuildContext context,
                        {required int currentLength,
                        required bool isFocused,
                        required int? maxLength}) {
                      return Text('$currentLength/$maxLength');
                    },
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  child:
                      _isLoading ? CircularProgressIndicator() : Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
