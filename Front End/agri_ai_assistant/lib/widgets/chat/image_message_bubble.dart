// lib/widgets/image_message_bubble.dart
import 'dart:io';
import 'package:flutter/material.dart';

/// A widget that displays an image within a chat bubble, styled like a user message.
class ImageMessageBubble extends StatelessWidget {
  final File imageFile;

  const ImageMessageBubble({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          Alignment
              .centerRight, // Align image to the right (like user sending it)
      child: Container(
        padding: const EdgeInsets.all(4.0), // Small padding around image
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6, // Limit width
          maxHeight: 200, // Limit height
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColorLight, // Use a theme color
          borderRadius: BorderRadius.circular(15.0).copyWith(
            bottomRight: const Radius.circular(2), // User style corner
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 1.0,
              color: Colors.black12,
            ),
          ],
        ),
        child: ClipRRect(
          // Clip the image to rounded corners
          borderRadius: BorderRadius.circular(
            11.0,
          ), // Inner radius slightly smaller
          child: Image.file(
            imageFile,
            fit: BoxFit.cover, // Cover the area
            errorBuilder: (context, error, stackTrace) {
              print(
                "Error loading image file in bubble: $error",
              ); // Log the error
              return const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              );
            },
          ),
        ),
      ),
    );
  }
}
