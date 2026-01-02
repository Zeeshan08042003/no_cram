import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/chat_mode.dart';
import '../controllers/chat_controller.dart';
import 'message_bubble.dart';

class ResultScreen extends StatefulWidget {
  ResultScreen({super.key, this.chatModel});
  final FBChatModel? chatModel;
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ChatController controller = Get.find<ChatController>();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
   init();
  }

  init() async {
    if (widget.chatModel != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.callHistory(widget.chatModel!);
      });
    }
  }


  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
      controller.clearMessage();
  }
  // find the single controller instance placed in main()

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: (){
        controller.selectedMode.value = ChatMode.defaultMode;
        return Future.value(true);
      },
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        body: SafeArea(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12))),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                          onTap: () {
                            Get.back();
                          },
                          child: Icon(Icons.arrow_back_ios, color: Colors.black)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Obx(
                            () => Text(
                              controller.selectedMode.value.label.capitalizeFirst
                                      .toString() +
                                  " Mode",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black),
                            ),
                          ),
                          SizedBox(
                            height: 2,
                          ),
                          Obx(
                            () => Text(
                              controller.isGenerating.isTrue
                                  ? "Generating..."
                                  : "Generated",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.more_vert, color: Colors.black),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Obx(() {
                  final messages = controller.messages;
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'No messages yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: controller.scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final m = messages[index];
                      // animate latest AI message only
                      print("Image list is : ${m.imageUrlList?.first}");
                      final isLast = index == messages.length - 1;
                      final animate = isLast && !m.isUser;
                      return MessageBubble(
                        text: m.text,
                        isUser: m.isUser,
                        mode: m.mode,
                        imageUrl: m.imageUrl,
                        imageBytes: m.imageBytes,
                        imageBytesList: m.imageBytesList,
                        imageUrlList: m.imageUrlList,
                        animate: animate,
                        explainText: m.imageText,
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
