import 'package:firebase_ai/firebase_ai.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_mode.dart';
import '../firebase/firebase_config.dart';
import '../firebase/firestore_service.dart';



class StoryTellingServices{

  handleStoryPrompt(String userInput) async {
    var controller = Get.find<ChatController>();
    var pref = await SharedPreferences.getInstance();
    var userId = pref.getString('userId');


    final cfg = getConfigDefaults();

    final systemInstruction = cfg.storyValue?.storyPrompt ??
        'You are a friendly storytelling teacher. '
            'Explain any topic as if the student is 5 years old. '
            'Use simple words and a short, fun, visual story that makes the concept easy to remember. '
            'Do not use complex terms. Begin the story immediately.';

    final textModelName = cfg.storyValue?.model?.trim().isNotEmpty == true
        ? cfg.storyValue!.model!.trim()
        : 'gemini-2.5-flash';

    print("📖 Story telling | selectedMode=${controller.selectedMode.value.label}");
    print("📖 Story telling | model=$textModelName");

    final loadingIndex = controller.messages.length;
    controller.messages.add(
      FBChatItem.ai(
        mode: ChatMode.storyTelling.key,
        text: 'Crafting your story...',
      ),
    );
    controller.scrollToBottom();

    try {
      final promptText = '''
$systemInstruction

Student's topic:
$userInput
''';

      final storyModel =
      FirebaseAI.googleAI().generativeModel(model: textModelName);
      final prompt = [Content.text(promptText)];
      final response = await storyModel.generateContent(prompt);

      final output = response.text;

      if (output == null || output.trim().isEmpty) {
        print("🟡 Story: empty output from model");
        if (loadingIndex < controller.messages.length) {
          controller.messages[loadingIndex] = FBChatItem.ai(
            mode: ChatMode.storyTelling.key,
            text: "Sorry, I couldn't create a story. Please try again.",
          );
        }
        return;
      }


      if (loadingIndex < controller.messages.length) {
        /// ✅ CREATE CHAT ITEM WITH BOTH USER INPUT AND AI OUTPUT
        final chatItem = FBChatItem(
          id: '', // Will be assigned by FirestoreService
          createdAt: DateTime.now(),
          mode: ChatMode.storyTelling.key,
          isUserMessage: false,
          userInput: UserInput(prompt: userInput),
          aiOutput: AIResponse(text: output),
        );

        final firestoreService = FirestoreService();

        if (controller.isFollowUp) {
          /// 🔄 ADD TO EXISTING CONVERSATION (Follow-up)
          await firestoreService.addChatToConversation(
            conversationId: controller.currentConversationId.value!,
            latestMode: ChatMode.storyTelling.key,
            chatItem: chatItem,
          );
          print('✅ Follow-up story added to conversation');
        } else {
          /// 🆕 CREATE NEW CONVERSATION
          final conversationId = await firestoreService.createConversation(
            userId: userId ?? '',
            mode: ChatMode.storyTelling.key,
            chatItem: chatItem,
          );
          controller.currentConversationId.value = conversationId;
          print('✅ New story conversation created: $conversationId');
        }


        controller.messages[loadingIndex] = FBChatItem.ai(
          mode: ChatMode.storyTelling.key,
          text: output,
        );
      }
    } catch (e, st) {
      print("🔴 Story error: $e");
      print("$st");
      if (loadingIndex < controller.messages.length) {

        controller.messages[loadingIndex] = FBChatItem.ai(
          mode: ChatMode.storyTelling.key,
          text: "Something went wrong while creating the story. Please try again.",
        );
      }
    }

    controller.scrollToBottom();
  }


}