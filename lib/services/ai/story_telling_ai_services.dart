import 'package:firebase_ai/firebase_ai.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_mode.dart';
import '../firebase/firebase_config.dart';
import '../firebase/firestore_service.dart';



class StoryTellingServices{

  /// Build conversation context for follow-up questions
  String _buildFollowUpContext(ChatController controller, String currentQuestion) {
    final previousMessages = controller.messages;
    
    if (previousMessages.isEmpty) {
      return currentQuestion;
    }

    final StringBuffer context = StringBuffer();
    
    context.writeln('''
=== FOLLOW-UP STORY CONTEXT ===
This is a follow-up question about a story you previously told.
IMPORTANT INSTRUCTIONS:
1. Continue the story or explanation - do not start a new story from scratch
2. Do NOT repeat the story elements already told
3. Expand on the existing story or add new chapters/elements
4. Keep the same characters and setting if applicable
5. Make the continuation feel natural and connected
6. If asked about a new topic, creatively connect it to the previous story

=== PREVIOUS STORY/CONVERSATION ===
''');

    for (int i = 0; i < previousMessages.length; i++) {
      final msg = previousMessages[i];
      if (msg.isUserMessage) {
        context.writeln('USER ASKED: ${msg.userInput.prompt}');
      } else {
        final aiText = msg.aiOutput?.text ?? '';
        final truncatedText = aiText.length > 600 
            ? '${aiText.substring(0, 600)}...[story continues...]' 
            : aiText;
        context.writeln('STORY: $truncatedText');
      }
      context.writeln('');
    }

    context.writeln('=== NEW FOLLOW-UP REQUEST ===');
    context.writeln('USER NOW ASKS: $currentQuestion');
    context.writeln('');
    context.writeln('Continue the story or explanation building on what was already told:');

    return context.toString();
  }

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

    print("📖 Story telling | selectedMode=${controller.selectedMode.value.label} isFollowUp=${controller.isFollowUp}");
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
      // Build prompt with context for follow-ups
      final String promptText;
      if (controller.isFollowUp) {
        final followUpContext = _buildFollowUpContext(controller, userInput);
        promptText = '''
$systemInstruction

$followUpContext
''';
        print('📖 Using follow-up context with ${controller.messages.length} previous messages');
      } else {
        promptText = '''
$systemInstruction

Student's topic:
$userInput
''';
      }

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