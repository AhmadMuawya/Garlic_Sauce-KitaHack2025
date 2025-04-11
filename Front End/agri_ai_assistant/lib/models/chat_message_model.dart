// lib/models/chat_message_model.dart

// Enum to identify sender type
import 'dart:io';

enum SenderType { user, ai, system } // Added system for images/info

class ChatMessage {
  final String id; // Unique ID for the message (e.g., timestamp)
  final String text;
  final SenderType sender;
  final DateTime timestamp;
  final File? imageFile; // Optional: For displaying the initial image

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.imageFile, // Image is optional
  });
}
