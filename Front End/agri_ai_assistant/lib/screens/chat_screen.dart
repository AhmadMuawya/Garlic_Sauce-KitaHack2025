// chat_screen.dart

import 'dart:io';
import 'package:agri_ai_assistant/constants/app_constants.dart';
import 'package:agri_ai_assistant/models/analysis_result_model.dart';
import 'package:agri_ai_assistant/models/chat_message_model.dart';
import 'package:agri_ai_assistant/models/crop_model.dart';
import 'package:agri_ai_assistant/providers/app_provider.dart';
import 'package:agri_ai_assistant/services/firebase_service.dart';
import 'package:agri_ai_assistant/widgets/chat/ai_message_bubble.dart';
import 'package:agri_ai_assistant/widgets/chat/image_message_bubble.dart';
import 'package:agri_ai_assistant/widgets/chat/loading_indicator.dart';
import 'package:agri_ai_assistant/widgets/chat/error_display.dart';
import 'package:agri_ai_assistant/widgets/chat/message_input_area.dart';
import 'package:agri_ai_assistant/widgets/chat/user_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  AnalysisResult? _initialAnalysisResult;
  String? _errorMessage;
  String _loadingMessage = "Initializing...";
  // --- NEW STATE VARIABLES ---
  final List<ChatMessage> _messages = []; // List to hold all messages
  final TextEditingController _textController =
      TextEditingController(); // For user input
  final ScrollController _scrollController =
      ScrollController(); // To scroll list
  bool _isSending = false; // To disable send button during processing
  String? _diagnosisId; // To store the ID from initial analysis
  final String _demoUserId = "test_user01"; // Demo User ID from guide

  @override
  void initState() {
    super.initState();
    _fetchInitialAnalysis();
  }

  Future<void> _fetchInitialAnalysis() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _initialAnalysisResult = null;
      _messages.clear(); // Clear previous messages
      _diagnosisId = null;
      _loadingMessage = "Preparing analysis...";
    });

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final String? cropId = appProvider.selectedCropId;
      final File? imageFile = appProvider.imagePath;

      if (imageFile != null) {
        if (mounted) setState(() => _loadingMessage = "Uploading image...");
      } else {
        if (mounted) {
          setState(() => _loadingMessage = "Calling analysis function...");
        }
      }

      final result = await _firebaseService.getAnalysis(cropId, imageFile);

      if (!mounted) return;

      List<ChatMessage> initialMessages =
          []; // Temporary list for initial items
      if (result.isSuccess) {
        _initialAnalysisResult = result;
        _diagnosisId = result.diagnosisId;

        // --- POPULATE INITIAL MESSAGES ---
        if (imageFile != null) {
          initialMessages.add(
            ChatMessage(
              id: 'initial_image_${DateTime.now().millisecondsSinceEpoch}',
              text: '',
              sender: SenderType.user,
              timestamp: DateTime.now(),
              imageFile: imageFile,
            ),
          );
        }
        if (result.prediction != null) {
          initialMessages.add(
            ChatMessage(
              id: 'ai_pred_${DateTime.now().millisecondsSinceEpoch}',
              text: result.prediction!,
              sender: SenderType.ai,
              timestamp: DateTime.now(),
            ),
          );
        }
        if (result.confidence != null) {
          initialMessages.add(
            ChatMessage(
              id: 'ai_conf_${DateTime.now().millisecondsSinceEpoch}',
              text:
                  "Confidence: ${(result.confidence! * 100).toStringAsFixed(1)}%",
              sender: SenderType.ai,
              timestamp: DateTime.now(),
            ),
          );
        }
        if (result.advise != null && result.advise!.isNotEmpty) {
          initialMessages.add(
            ChatMessage(
              id: 'ai_advise_${DateTime.now().millisecondsSinceEpoch}',
              text: result.advise!,
              sender: SenderType.ai,
              timestamp: DateTime.now(),
            ),
          );
        }
        final selectedCropName =
            crops
                .firstWhere(
                  (c) => c.id == cropId,
                  orElse:
                      () => const Crop(
                        id: '',
                        name: 'plant',
                        imagePath: '',
                        description: '',
                      ),
                )
                .name;
        initialMessages.add(
          ChatMessage(
            id: 'ai_followup_${DateTime.now().millisecondsSinceEpoch}',
            text: "How else can I help you with your $selectedCropName?",
            sender: SenderType.ai,
            timestamp: DateTime.now(),
          ),
        );
        // --- END POPULATE ---
        print(
          "Analysis successful: prediction=${_initialAnalysisResult?.prediction}, diagnosisId=$_diagnosisId",
        );
      } else {
        _errorMessage = result.errorMessage ?? "An unknown error occurred.";
        print("Analysis failed: $_errorMessage");
      }

      // Update state with initial messages or error
      setState(() {
        _isLoading = false;
        _messages.addAll(
          initialMessages,
        ); // Add initial messages to the main list
      });

      // Scroll after messages are likely rendered
      if (initialMessages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      if (!mounted) return;
      print("Error during initial analysis fetch in ChatScreen: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "An unexpected error occurred: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final selectedCropId = appProvider.selectedCropId;
    final selectedCropName =
        crops
            .firstWhere(
              (crop) => crop.id == selectedCropId,
              orElse:
                  () => const Crop(
                    id: 'default',
                    name: 'Unknown Crop',
                    imagePath: '',
                    description: '',
                  ),
            )
            .name;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chatting about $selectedCropName'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            appProvider.clearSelection();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _buildChatAreaContent(),
            ),
          ),
          ChatInputArea(
            controller: _textController, // From _ChatScreenState
            isSending: _isSending, // From _ChatScreenState
            onSendPressed: _handleSendMessage, // From _ChatScreenState
          ),
        ],
      ),
    );
  }

  Widget _buildChatAreaContent() {
    // final appProvider = Provider.of<AppProvider>(context);
    // final userMessages = appProvider.userMessages;
    // final assistantMessages = appProvider.assistantMessages;
    // final imageFile = appProvider.imagePath;

    if (_isLoading) {
      return LoadingIndicator(message: _loadingMessage);
    } else if (_errorMessage != null) {
      return ErrorDisplay(
        errorMessage: _errorMessage!,
        onRetry: _fetchInitialAnalysis,
      );
    } else {
      // --- RENDER MESSAGES FROM LIST ---
      return ListView.builder(
        controller: _scrollController, // Attach scroll controller
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          // Decide which bubble type to use
          if (message.imageFile != null) {
            return ImageMessageBubble(imageFile: message.imageFile!);
          } else if (message.sender == SenderType.user) {
            return UserMessageBubble(text: message.text); // Use the User bubble
          } else {
            // AI or System text messages
            return AiMessageBubble(text: message.text);
          }
        },
      );
    }
  }

  // --- NEW METHOD TO HANDLE SENDING ---
  Future<void> _handleSendMessage() async {
    final String messageText = _textController.text.trim();
    if (messageText.isEmpty || _diagnosisId == null) {
      if (_diagnosisId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: Cannot send message. Initial analysis ID missing.',
            ),
          ),
        );
      }
      return;
    }

    final String currentDiagnosisId = _diagnosisId!;
    final String currentUser = _demoUserId;

    // 1. Create User message object
    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      text: messageText,
      sender: SenderType.user,
      timestamp: DateTime.now(),
    );

    // 2. Optimistic UI update for User message + Disable input
    setState(() {
      _isSending = true;
      _messages.add(userMessage); // Add user message
      _textController.clear();
    });
    _scrollToBottom(); // Scroll after adding user message

    try {
      // 3. Call the service
      final result = await _firebaseService.handleChatMessage(
        userId: currentUser,
        diagnosisId: currentDiagnosisId,
        userMessage: messageText,
      );

      if (!mounted) return;

      // 4. Handle the result - Add AI reply if successful
      if (result.isSuccess && result.aiReply != null) {
        final aiReplyMessage = ChatMessage(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
          text: result.aiReply!, // Use the received reply
          sender: SenderType.ai,
          timestamp: DateTime.now(),
        );
        setState(() {
          _messages.add(aiReplyMessage); // Add AI reply to the list
        });
        _scrollToBottom(); // Scroll after adding AI message
        print("AI Reply received and added to UI.");
      } else if (!result.isSuccess) {
        // Show error if sending failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${result.errorMessage ?? "Couldn't send message."}',
            ),
          ),
        );
        // Optional: Maybe remove the optimistic user message or mark as failed
        // setState(() { _messages.remove(userMessage); });
      }
    } catch (e) {
      // Catch errors from the service call itself
      if (!mounted) return;
      print("Error calling handleChatMessage service: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while sending the message.'),
        ),
      );
      // Optional: Remove optimistic message on general error
      // setState(() { _messages.remove(userMessage); });
    } finally {
      // 5. Re-enable input
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // --- NEW METHOD TO SCROLL LIST ---
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

//unused

// List<Widget> _buildMessages(
//   List<String> userMessages,
//   List<String> assistantMessages,
// ) {
//   final messageWidgets = <Widget>[];

//   for (int i = 0; i < userMessages.length; i++) {
//     messageWidgets.add(AiMessageBubble(text: userMessages[i]));
//     if (i < assistantMessages.length) {
//       messageWidgets.add(AiMessageBubble(text: assistantMessages[i]));
//     }
//   }

//   return messageWidgets;
// }
