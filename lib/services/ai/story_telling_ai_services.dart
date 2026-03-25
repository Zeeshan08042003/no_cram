import 'package:firebase_ai/firebase_ai.dart';
import 'package:get/get.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/credit_controller.dart';
import '../../models/chat_mode.dart';
import '../firebase/firebase_config.dart';
import '../firebase/firestore_service.dart';

class StoryTellingServices {
  /// Cached model instance — created once per session
  GenerativeModel? _cachedModel;

  GenerativeModel _getModel(String modelName) {
    _cachedModel ??= FirebaseAI.googleAI().generativeModel(
      model: modelName,
      systemInstruction: Content.system(
        'You are a friendly storytelling teacher who explains school topics through short, imaginative stories.\n'
        'Rules:\n'
        '- Use only very simple, everyday words — as if explaining to a 6-year-old.\n'
        '- Write a short story of 5–8 sentences featuring one or two fun characters (animals, kids, or objects that can talk).\n'
        '- The story must teach exactly ONE concept through what the characters do and experience — not through narration.\n'
        '- End with a single plain-English lesson sentence (e.g. "And that is why plants need sunlight!").\n'
        '- Do NOT use technical terms. Do NOT write essays or explanations outside the story. Begin the story immediately on the first line.',
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

    context.writeln('=== FOLLOW-UP STORY CONTEXT ===');
    context.writeln('This is a follow-up. Continue the story. Do NOT start a new story from scratch and do NOT repeat story elements already told.');
    context.writeln('=== PREVIOUS STORY/CONVERSATION ===');

    for (int i = 0; i < previousMessages.length; i++) {
      final msg = previousMessages[i];
      if (msg.isUserMessage) {
        context.writeln('USER ASKED: ${msg.userInput.prompt}');
      } else {
        final aiText = msg.aiOutput?.text ?? '';
        final truncatedText = aiText.length > 500
            ? '${aiText.substring(0, 500)}...[story continues...]'
            : aiText;
        context.writeln('STORY: $truncatedText');
      }
      context.writeln('');
    }

    context.writeln('=== NEW FOLLOW-UP REQUEST ===');
    context.writeln('USER NOW ASKS: $currentQuestion');
    context.writeln('Continue the story building on what was already told:');

    return context.toString();
  }

  handleStoryPrompt(String userInput, {required String aiChatId, required String generationId}) async {
    final controller = Get.find<ChatController>();
    final userId = ChatController.cachedUserId ?? '';

    final cfg = getConfigDefaults();

    final textModelName = cfg.storyValue?.model?.trim().isNotEmpty == true
        ? cfg.storyValue!.model!.trim()
        : 'gemini-2.5-flash';

    print('📖 Story telling | model=$textModelName isFollowUp=${controller.isFollowUp}');

    final loadingIndex = controller.messages.indexWhere((m) => m.id == aiChatId);
    if (loadingIndex == -1) return;
    
    final conversationId = controller.currentConversationId.value;
    if (conversationId == null) return;

    try {
      // System instruction is at model level — just send user content
      final String promptText = controller.isFollowUp
          ? _buildFollowUpContext(controller, userInput)
          : userInput;

      if (controller.isFollowUp) {
        print('📖 Using follow-up context (${controller.messages.length} msgs)');
      }

      final storyModel = _getModel(textModelName);
      final response = await storyModel.generateContent([Content.text(promptText)]);

      // Check if generation was stopped by user or a NEW generation started
      if (!controller.isGenerating.value || controller.currentGenerationId != generationId) {
        print('[STORY] Generation stopped or stale, discarding result.');
        return;
      }

      final output = response.text;

      if (output == null || output.trim().isEmpty) {
        print('🟡 Story: empty output from model');
        if (loadingIndex != -1 && loadingIndex < controller.messages.length) {
          controller.messages[loadingIndex] = FBChatItem.ai(
            mode: ChatMode.storyTelling.key,
            text: "Sorry, I couldn't create a story. Please try again.",
          );
        }
        return;
      }

      if (loadingIndex != -1 && controller.currentConversationId.value == conversationId) {
        final localIndex = controller.messages.indexWhere((m) => m.id == aiChatId);
        if (localIndex != -1) {
          controller.messages[localIndex] = FBChatItem.ai(
            mode: ChatMode.storyTelling.key,
            text: output,
          );
        }
      }

      // ✅ CONSUME CREDIT ONLY AFTER SUCCESSFUL RESPONSE
      try {
        await Get.find<CreditController>().checkAndConsumeCredit();
      } catch (_) {}

      final firestoreService = FirestoreService();
      await firestoreService.updateAiResponseInConversation(
        conversationId: conversationId,
        chatId: aiChatId,
        outputText: output,
      );
      print('✅ AI response updated in Firestore');
    } catch (e, st) {
      print('🔴 Story error: $e');
      print('$st');
      if (loadingIndex < controller.messages.length) {
        controller.messages[loadingIndex] = FBChatItem.ai(
          mode: ChatMode.storyTelling.key,
          text: 'Something went wrong while creating the story. Please try again.',
        );
      }
    }

    controller.scrollToBottom();
  }
}