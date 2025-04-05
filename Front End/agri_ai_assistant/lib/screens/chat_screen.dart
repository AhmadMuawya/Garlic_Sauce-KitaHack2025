// lib/screens/chat_screen.dart

import 'dart:io'; // For File type
import 'package:agri_ai_assistant/constants/app_constants.dart'; // Make sure 'crops' is defined here or accessible
import 'package:agri_ai_assistant/models/analysis_result_model.dart'; // Your result model
import 'package:agri_ai_assistant/models/crop_model.dart'; // For getting crop name
import 'package:agri_ai_assistant/providers/app_provider.dart'; // To get cropId/imageFile
import 'package:agri_ai_assistant/services/firebase_service.dart'; // Your Firebase service
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Instantiate the Firebase service
  final FirebaseService _firebaseService = FirebaseService();

  // State variables
  bool _isLoading = true; // Start loading initially
  AnalysisResult? _initialAnalysisResult; // Store the first result
  String? _errorMessage; // Store any error message
  String _loadingMessage = "Initializing..."; // More specific loading status

  // --- Lifecycle and Data Fetching ---

  @override
  void initState() {
    super.initState();
    // Fetch the analysis as soon as the screen loads
    _fetchInitialAnalysis();
  }

  // Function to call the service and update state
  Future<void> _fetchInitialAnalysis() async {
    // Ensure the widget is still mounted before updating state
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _initialAnalysisResult = null;
      _loadingMessage = "Preparing analysis..."; // Initial status
    });

    try {
      // Get required data from provider
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final String? cropId = appProvider.selectedCropId;
      final File? imageFile =
          appProvider.imagePath; // Recommended rename: imageFile

      // Update loading message based on whether an image needs uploading
      if (imageFile != null) {
        if (mounted) setState(() => _loadingMessage = "Uploading image...");
      } else {
        if (mounted) {
          setState(() => _loadingMessage = "Calling analysis function...");
        }
      }

      // --- Call the main service method ---
      // This handles internal upload (if needed) and then the function call
      final result = await _firebaseService.getAnalysis(cropId, imageFile);

      if (!mounted) return; // Check mount status again after async operations

      setState(() {
        _isLoading = false;
        if (result.isSuccess) {
          _initialAnalysisResult = result;
          // In a real chat, add these messages to a list here
          print("Analysis successful: ${_initialAnalysisResult?.prediction}");
        } else {
          _errorMessage = result.errorMessage ??
              "An unknown error occurred during analysis.";
          print("Analysis failed: $_errorMessage");
        }
      });
    } catch (e) {
      // Catch errors *outside* the service call (less likely but possible)
      if (!mounted) return;
      print("Error during initial analysis fetch in ChatScreen: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "An unexpected error occurred: $e";
      });
    }
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    // Access provider data for AppBar title and initial image
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final selectedCropId = appProvider.selectedCropId;
    final File? initialImageFile = appProvider.imagePath; // Get initial image

    // Get crop name for AppBar title
    // Ensure `crops` list is accessible (e.g., imported from constants)
    final selectedCropName = crops
        .firstWhere((crop) => crop.id == selectedCropId,
            orElse: () => const Crop(
                  id: 'default',
                  name: 'Unknown Crop', // Better fallback
                  imagePath: '',
                  description: '',
                ))
        .name;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chatting about $selectedCropName'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back. Clear selection if desired.
            Provider.of<AppProvider>(context, listen: false).clearSelection();
            Navigator.of(context).pop();
          },
        ),
      ),
      // Main layout: Chat area + Input area
      body: Column(
        children: [
          // Chat messages area (takes available space)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              // Pass necessary data to the chat area builder
              child: _buildChatArea(selectedCropName, initialImageFile),
            ),
          ),
          // Message input area (placeholder for now)
          _buildMessageInputArea(),
        ],
      ),
    );
  }

  // --- UI Helper Methods ---

  // Builds the main content area based on loading/error/success state
  Widget _buildChatArea(String selectedCropName, File? initialImage) {
    if (_isLoading) {
      // --- Loading State ---
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_loadingMessage), // Display current loading status
          ],
        ),
      );
    } else if (_errorMessage != null) {
      // --- Error State ---
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 50),
              const SizedBox(height: 16),
              Text(
                "Analysis Failed:",
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!, // Display the specific error
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700]),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _fetchInitialAnalysis, // Allow retry
              )
            ],
          ),
        ),
      );
    } else if (_initialAnalysisResult != null &&
        _initialAnalysisResult!.isSuccess) {
      // --- Success State: Display initial analysis as AI messages ---
      // Use a ListView to prepare for adding more messages later
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        // In a real chat, this list would contain message objects (user/AI)
        children: [
          // Display initial image if it exists
          if (initialImage != null) _buildImageMessageBubble(initialImage),

          // Display prediction if available
          if (_initialAnalysisResult!.prediction != null)
            _buildAiMessageBubble(_initialAnalysisResult!.prediction!),

          // Display confidence if available
          if (_initialAnalysisResult!.confidence != null)
            _buildAiMessageBubble(
                "Confidence: ${(_initialAnalysisResult!.confidence! * 100).toStringAsFixed(1)}%"),

          // Display advice if available
          if (_initialAnalysisResult!.advise != null &&
              _initialAnalysisResult!.advise!.isNotEmpty)
            _buildAiMessageBubble(_initialAnalysisResult!.advise!),

          // Optional confirmation message
          _buildAiMessageBubble(
              "How else can I help you with your $selectedCropName?"),
        ],
      );
    } else {
      // --- Fallback State (e.g., service returned success:false but no error message) ---
      return const Center(
        child: Text("Could not retrieve analysis details."),
      );
    }
  }

  // Helper to build the initial image bubble
  Widget _buildImageMessageBubble(File imageFile) {
    return Align(
      alignment: Alignment
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
              )
            ]),
        child: ClipRRect(
          // Clip the image to rounded corners
          borderRadius:
              BorderRadius.circular(11.0), // Inner radius slightly smaller
          child: Image.file(
            // Using Image.file constructor
            imageFile,
            fit: BoxFit.cover, // Cover the area

            // --- REMOVED loadingBuilder ---
            // loadingBuilder is not a direct parameter of Image.file

            // errorBuilder IS a direct parameter of Image.file
            errorBuilder: (context, error, stackTrace) {
              print("Error loading image file: $error"); // Log the error
              return const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey));
            },
          ),
        ),
      ),
    );
  }

  // Helper to build a styled AI message bubble
  Widget _buildAiMessageBubble(String text) {
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
            )
          ],
        ),
        child: Text(
          text,
          style:
              const TextStyle(color: Colors.black87), // AI message text style
        ),
      ),
    );
  }

  // Helper to build a styled User message bubble
  // (Not actively used yet, but defined for future use)
  // ignore: unused_element
  Widget _buildUserMessageBubble(String text) {
    return Align(
      alignment: Alignment.centerRight, // User messages on the right
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .primaryColor, // User message background (theme color)
          borderRadius: BorderRadius.circular(15.0).copyWith(
            bottomRight: const Radius.circular(2), // Different corner style
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 1.0,
              color: Colors.black12,
            )
          ],
        ),
        child: Text(
          text,
          style:
              const TextStyle(color: Colors.white), // User message text color
        ),
      ),
    );
  }

  // Placeholder for the message input field and send button
  Widget _buildMessageInputArea() {
    // This will be replaced with a functional input later
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // Use theme card color
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, -1), // Shadow above input
            blurRadius: 2.0,
            color: Colors.black12,
          )
        ],
      ),
      child: Row(
        children: [
          // Input Field (disabled for now)
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Type your message...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
              enabled: false, // Will be enabled later
            ),
          ),
          // Send Button (disabled for now)
          IconButton(
            icon: Icon(Icons.send,
                color: Theme.of(context).disabledColor), // Use disabled color
            onPressed: null, // Will be implemented later
          ),
        ],
      ),
    );
  }
}
// This is a placeholder for the message input area. It will be replaced with a functional input field and send button later.
