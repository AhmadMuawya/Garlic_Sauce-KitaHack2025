// lib/widgets/ai_message_bubble.dart
import 'package:flutter/material.dart';

/// A widget that displays a message bubble styled for AI responses (aligned left).
class AiMessageBubble extends StatelessWidget {
  final String text;

  const AiMessageBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft, // AI messages on the left
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey[200], // AI message background
          borderRadius: BorderRadius.circular(15.0).copyWith(
            bottomLeft: const Radius.circular(2), // Slight style variation
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 1.0,
              color: Colors.black12,
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black87,
          ), // AI message text style
        ),
      ),
    );
  }
}
