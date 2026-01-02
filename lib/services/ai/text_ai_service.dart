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
      ChatMessage(
        text: 'Thinking about your question...',
        isUser: false,
        mode: mode,
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
        controller.messages[loadingIndex] = ChatMessage(
          text: output,
          isUser: false,
          mode: mode,
        );


        print('Starting firebase');
        /// ✅ SAVE TO FIRESTORE (MODEL-BASED)
        final chat = FBChatModel(
          id: '',
          userId: userId??'',
          mode: ChatMode.explainImage.name,
          createdAt: DateTime.now(),
          userInput: UserInput(
            prompt: text,
          ),
          aiOutput: AIResponse(
            text: output,
          ),
        );

        await FirestoreService().createChat(chat);



      }
    } catch (e, st) {
      print('[GEMINI ERROR] $e');
      print('[STACKTRACE] $st');

      if (loadingIndex < controller.messages.length) {
        controller.messages[loadingIndex] = ChatMessage(
          text: "Something went wrong. Please try again.",
          isUser: false,
          mode: mode,
        );
      }
    }

    controller.scrollToBottom();
  }



}
