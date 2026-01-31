import 'package:firebase_ai/firebase_ai.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_mode.dart';
import '../firebase/firebase_config.dart';
import '../firebase/firestore_service.dart';

class TextAIService {

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

    print('[GEMINI] textGeneration mode=${mode.label} model=$textModelName');

    final loadingIndex = controller.messages.length;

    controller.messages.add(
      FBChatItem.ai(
        mode: mode.key,
        text: 'Thinking about your question...',
      ),
    );
    controller.scrollToBottom();

    try {
      final promptText = '''
${cfg.textValue?.textPrompt ?? systemInstruction}

User input:
$text
''';

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

