// lib/widgets/user_message_bubble.dart
import 'package:flutter/material.dart';

/// A widget that displays a message bubble styled for user input (aligned right).
class UserMessageBubble extends StatelessWidget {
  final String text;

  const UserMessageBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_element // Keep the definition even if not used yet
    return Align(
      alignment: Alignment.centerRight, // User messages on the right
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color:
              Theme.of(
                context,
              ).primaryColor, // User message background (theme color)
          borderRadius: BorderRadius.circular(15.0).copyWith(
            bottomRight: const Radius.circular(2), // Different corner style
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
            color: Colors.white,
          ), // User message text color
        ),
      ),
    );
  }
}
