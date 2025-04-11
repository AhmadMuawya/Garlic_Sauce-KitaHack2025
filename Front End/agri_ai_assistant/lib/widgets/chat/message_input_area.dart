// lib/widgets/chat/chat_input_area.dart
import 'package:flutter/material.dart';

class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending; // To disable input/button while sending
  final VoidCallback onSendPressed;

  const ChatInputArea({
    required this.controller,
    required this.isSending,
    required this.onSendPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, -1),
            blurRadius: 2.0,
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isSending, // Disable when sending
              decoration: const InputDecoration(
                hintText: "Type your message...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
              textInputAction:
                  TextInputAction.send, // Show send key on keyboard
              onSubmitted:
                  (_) =>
                      isSending
                          ? null
                          : onSendPressed(), // Allow sending via keyboard
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send,
              color:
                  isSending
                      ? Theme.of(context).disabledColor
                      : Theme.of(context).primaryColor,
            ),
            // Disable button visually and functionally when sending
            onPressed: isSending ? null : onSendPressed,
          ),
        ],
      ),
    );
  }
}
