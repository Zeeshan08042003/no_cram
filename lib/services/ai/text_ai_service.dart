import 'package:firebase_ai/firebase_ai.dart';
import 'package:get/get.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/credit_controller.dart';
import '../../models/chat_mode.dart';
import '../firebase/firebase_config.dart';
import '../firebase/firestore_service.dart';
import 'ai_cancellation.dart';

class TextAIService {
  /// Cached model instance — created once per session
  GenerativeModel? _cachedModel;

  GenerativeModel _getModel(String modelName) {
    _cachedModel ??= FirebaseAI.googleAI().generativeModel(
      model: modelName,
      systemInstruction: Content.system(
        'You are an expert study assistant for high school and college students.\n'
        'When answering a question:\n'
        '1. Open with one clear sentence summarising the answer.\n'
        '2. Use simple English — define any technical term immediately after using it.\n'
        '3. For multi-part topics, use a short numbered list or 2–3 bullet points.\n'
        '4. Give one concrete real-world example or analogy to make the idea stick.\n'
        '5. Keep your total answer under 200 words unless the student asks for more detail.\n'
        'Do not repeat the student\'s question. Do not add filler phrases like "Great question!".',
      ),
    );
    return _cachedModel!;
  }

  /// Build conversation context for follow-up questions
  String _buildFollowUpContext(ChatController controller, String currentQuestion) {
    final previousMessages = controller.messages;

    if (previousMessages.isEmpty) {
      return currentQuestion;
    }

    final StringBuffer context = StringBuffer();

    context.writeln('=== FOLLOW-UP CONTEXT ===');
    context.writeln('This is a follow-up question in an ongoing conversation.');
    context.writeln('IMPORTANT: Continue from your previous answer. Do NOT repeat what was already explained.');
    context.writeln('=== CONVERSATION HISTORY ===');

    for (int i = 0; i < previousMessages.length; i++) {
      final msg = previousMessages[i];
      if (msg.isUserMessage) {
        context.writeln('USER: ${msg.userInput.prompt}');
      } else {
        // Truncate long AI responses to avoid token limits
        final aiText = msg.aiOutput?.text ?? '';
        final truncatedText = aiText.length > 400
            ? '${aiText.substring(0, 400)}...[truncated]'
            : aiText;
        context.writeln('ASSISTANT: $truncatedText');
      }
      context.writeln('');
    }

    context.writeln('=== NEW FOLLOW-UP QUESTION ===');
    context.writeln('USER: $currentQuestion');
    context.writeln('Build on the previous context. Do not repeat what was already explained:');

    return context.toString();
  }

  handleTextGeneration(String text, ChatMode mode, {required String aiChatId, required String generationId}) async {
    final controller = Get.find<ChatController>();
    final cfg = getConfigDefaults();

    // Use cached userId — avoids async SharedPreferences read on every call
    final userId = ChatController.cachedUserId ?? '';

    final textModelName =
        cfg.textValue?.model?.trim().isNotEmpty == true
            ? cfg.textValue!.model!.trim()
            : 'gemini-2.5-flash';

    print('[GEMINI] textGeneration mode=${mode.label} model=$textModelName isFollowUp=${controller.isFollowUp}');

    final loadingIndex = controller.messages.indexWhere((m) => m.id == aiChatId);
    if (loadingIndex == -1) return;
    
    final conversationId = controller.currentConversationId.value;
    if (conversationId == null) return;

    try {
      // Build prompt — system instruction is now at model level, so only send user content
      final String promptText;
      if (controller.isFollowUp) {
        promptText = _buildFollowUpContext(controller, text);
        print('[GEMINI] Using follow-up context (${controller.messages.length} msgs)');
      } else {
        promptText = text;
      }

      final textModel = _getModel(textModelName);
      final response = await controller.raceWithCancel(
        textModel.generateContent([Content.text(promptText)]),
      );

      // Check if generation was stopped by user or a NEW generation started
      if (!controller.isGenerating.value || controller.currentGenerationId != generationId) {
        print('[GEMINI] Generation stopped or stale, discarding result.');
        return;
      }

      final output = response.text?.trim();

      if (output == null || output.isEmpty) {
        throw Exception('Empty Gemini output');
      }

      // ✅ UPDATE UI (Only if still on this conversation)
      if (controller.currentConversationId.value == conversationId) {
        final localIndex = controller.messages.indexWhere((m) => m.id == aiChatId);
        if (localIndex != -1) {
          controller.messages[localIndex] = FBChatItem.ai(
            mode: mode.key,
            text: output,
          );
        }
      }

      // ✅ CONSUME CREDIT ONLY AFTER SUCCESSFUL RESPONSE
      try {
        await Get.find<CreditController>().checkAndConsumeCredit();
      } catch (_) {}

      print('Updating firebase - Conversation based saving');

      final firestoreService = FirestoreService();
      await firestoreService.updateAiResponseInConversation(
        conversationId: conversationId,
        chatId: aiChatId,
        outputText: output,
      );
      print('✅ AI response updated in Firestore');
    } catch (e, st) {
      // Silently exit if user pressed Stop
      if (e is AICancelledException) {
        print('[TEXT AI] Cancelled by user.');
        return;
      }

      print('[GEMINI ERROR] $e');
      print('[STACKTRACE] $st');

      if (loadingIndex < controller.messages.length) {
        controller.messages[loadingIndex] = FBChatItem.ai(
          mode: mode.key,
          text: 'Something went wrong. Please try again.',
        );
      }
    }

    controller.scrollToBottom();
  }
}
