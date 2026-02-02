import 'package:firebase_ai/firebase_ai.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_mode.dart';
import '../firebase/firebase_config.dart';
import '../firebase/firestore_service.dart';

class TextAIService {

  /// Build conversation context for follow-up questions
  /// Returns a formatted string with previous Q&A pairs and follow-up instructions
  String _buildFollowUpContext(ChatController controller, String currentQuestion) {
    final previousMessages = controller.messages;
    
    if (previousMessages.isEmpty) {
      return currentQuestion;
    }

    final StringBuffer context = StringBuffer();
    
    // Add follow-up instructions
    context.writeln('''
=== FOLLOW-UP CONTEXT ===
This is a follow-up question in an ongoing conversation.
IMPORTANT INSTRUCTIONS:
1. Continue from your previous answer - do not start from scratch
2. Do NOT repeat basic explanations already given
3. Go deeper into the topic or move in the direction implied by the user's question
4. Build upon what was already explained
5. If the user asks about a new aspect, connect it to the previous context
6. Be concise but thorough - avoid redundancy

=== CONVERSATION HISTORY ===
''');

    // Add previous Q&A pairs
    for (int i = 0; i < previousMessages.length; i++) {
      final msg = previousMessages[i];
      if (msg.isUserMessage) {
        context.writeln('USER: ${msg.userInput.prompt}');
      } else {
        // Truncate long AI responses to avoid token limits
        final aiText = msg.aiOutput?.text ?? '';
        final truncatedText = aiText.length > 500 
            ? '${aiText.substring(0, 500)}...[truncated]' 
            : aiText;
        context.writeln('ASSISTANT: $truncatedText');
      }
      context.writeln('');
    }

    context.writeln('=== NEW FOLLOW-UP QUESTION ===');
    context.writeln('USER: $currentQuestion');
    context.writeln('');
    context.writeln('Now provide a response that builds on the previous context without repeating what was already explained:');

    return context.toString();
  }

  handleTextGeneration(String text, ChatMode mode) async {
    final controller = Get.find<ChatController>();
    final cfg = getConfigDefaults();
    var pref = await SharedPreferences.getInstance();
    var userId = pref.getString('userId');

    const systemInstruction =
        "You are a helpful study assistant for college students. "
        "Explain concepts clearly, simply, and stay focused on the question.";

    final textModelName =
    cfg.textValue?.model?.trim().isNotEmpty == true
        ? cfg.textValue!.model!.trim()
        : 'gemini-2.5-flash';

    print('[GEMINI] textGeneration mode=${mode.label} model=$textModelName isFollowUp=${controller.isFollowUp}');

    final loadingIndex = controller.messages.length;

    controller.messages.add(
      FBChatItem.ai(
        mode: mode.key,
        text: 'Thinking about your question...',
      ),
    );
    controller.scrollToBottom();

    try {
      // Build prompt with context for follow-ups
      final String promptText;
      if (controller.isFollowUp) {
        // For follow-up: include conversation history with special instructions
        final followUpContext = _buildFollowUpContext(controller, text);
        promptText = '''
${cfg.textValue?.textPrompt ?? systemInstruction}

$followUpContext
''';
        print('[GEMINI] Using follow-up context with ${controller.messages.length} previous messages');
      } else {
        // For new conversation: simple prompt
        promptText = '''
${cfg.textValue?.textPrompt ?? systemInstruction}

User input:
$text
''';
      }

      final textModel =
      FirebaseAI.googleAI().generativeModel(model: textModelName);

      final response =
      await textModel.generateContent([Content.text(promptText)]);

      final output = response.text?.trim();

      if (output == null || output.isEmpty) {
        throw Exception("Empty Gemini output");
      }

      /// ✅ UPDATE UI
      if (loadingIndex < controller.messages.length) {
        controller.messages[loadingIndex] = FBChatItem.ai(
          mode: mode.key,
          text: output,
        );


        print('Starting firebase - Conversation based saving');
        
        /// ✅ CREATE CHAT ITEM WITH BOTH USER INPUT AND AI OUTPUT
        final chatItem = FBChatItem(
          id: '', // Will be assigned by FirestoreService
          createdAt: DateTime.now(),
          mode: mode.key,
          isUserMessage: false,
          userInput: UserInput(prompt: text),
          aiOutput: AIResponse(text: output),
        );

        final firestoreService = FirestoreService();

        if (controller.isFollowUp) {
          /// 🔄 ADD TO EXISTING CONVERSATION (Follow-up)
          await firestoreService.addChatToConversation(
            conversationId: controller.currentConversationId.value!,
            chatItem: chatItem,
          );
          print('✅ Follow-up chat added to conversation');
        } else {
          /// 🆕 CREATE NEW CONVERSATION
          final conversationId = await firestoreService.createConversation(
            userId: userId ?? '',
            mode: mode.key,
            chatItem: chatItem,
          );
          controller.currentConversationId.value = conversationId;
          print('✅ New conversation created: $conversationId');
        }
      }
    } catch (e, st) {
      print('[GEMINI ERROR] $e');
      print('[STACKTRACE] $st');

      if (loadingIndex < controller.messages.length) {
        controller.messages[loadingIndex] = FBChatItem.ai(
          mode: mode.key,
          text: "Something went wrong. Please try again.",
        );
      }
    }

    controller.scrollToBottom();
  }



}

