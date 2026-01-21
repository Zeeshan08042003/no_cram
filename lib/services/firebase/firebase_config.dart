import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

final remoteConfig = FirebaseRemoteConfig.instance;

var defaultConfigs = {
  "default_config": jsonEncode({
    "defaultValue": {
      "value": {
        "text_prompt":
            "You are a helpful study assistant for college students. Explain concepts clearly, simply, and stay focused on the question.",
        "model": "gemini-1.5-flash"
      }
    }
  })
};

setupFirebaseRemoteConfig() async {
  final remoteConfig = FirebaseRemoteConfig.instance;
  if (kDebugMode) {
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(seconds: 5),
    ));
  } else {
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(minutes: 30),
    ));
  }

  await remoteConfig.setDefaults(defaultConfigs);
  var data = await remoteConfig.activate();
  print("data is here $data");

  remoteConfig.onConfigUpdated.listen((event) async {
    var datas = await remoteConfig.activate();
    print("data 2  is here $datas");
  });
  try {
    var datae = await remoteConfig.fetchAndActivate();
    print("data 3 is here $datae");
  } catch (e) {}
}

ConfigDefaultValue getConfigDefaults() {
  var collection = jsonDecode(remoteConfig.getString("default_config"));
  return ConfigDefaultValue.fromJson(collection);
}

class ConfigDefaultValue {
  TextConfig? textValue;
  ImageConfig? imageValue;
  StoryConfig? storyValue;
  ExplainImageConfig? explainImageValue;

  ConfigDefaultValue({this.textValue, this.imageValue, this.storyValue});

  /// Expects the top-level JSON, e.g. the whole object shown above.
  ConfigDefaultValue.fromJson(Map<String, dynamic> json) {
    final defaultVal = json['defaultValue'] as Map<String, dynamic>?;

    if (defaultVal != null) {
      if (defaultVal['text_value'] != null) {
        textValue = TextConfig.fromJson(
          defaultVal['text_value'] as Map<String, dynamic>,
        );
      }

      if (defaultVal['image_value'] != null) {
        imageValue = ImageConfig.fromJson(
          defaultVal['image_value'] as Map<String, dynamic>,
        );
      }

      if (defaultVal['story_value'] != null) {
        storyValue = StoryConfig.fromJson(
          defaultVal['story_value'] as Map<String, dynamic>,
        );
      }

      if (defaultVal['image_explanation_value'] != null) {
        explainImageValue = ExplainImageConfig.fromJson(
          defaultVal['image_explanation_value'] as Map<String, dynamic>,
        );
      }
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    data['defaultValue'] = {
      if (textValue != null) 'text_value': textValue!.toJson(),
      if (imageValue != null) 'image_value': imageValue!.toJson(),
      if (storyValue != null) 'story_value': storyValue!.toJson(),
      if (explainImageValue != null) 'story_value': explainImageValue!.toJson(),
    };

    return data;
  }
}

class TextConfig {
  String? textPrompt;
  String? model;

  TextConfig({this.textPrompt, this.model});

  TextConfig.fromJson(Map<String, dynamic> json) {
    textPrompt = json['text_prompt'] as String?;
    model = json['model'] as String?;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['text_prompt'] = textPrompt;
    data['model'] = model;
    return data;
  }
}

class ImageConfig {
  String? imageValue; // your "image_value" prompt
  String? model;

  ImageConfig({this.imageValue, this.model});

  ImageConfig.fromJson(Map<String, dynamic> json) {
    imageValue = json['image_prompt'] as String?;
    model = json['model'] as String?;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['image_prompt'] = imageValue;
    data['model'] = model;
    return data;
  }
}

class StoryConfig {
  String? storyPrompt; // your "image_value" prompt
  String? model;

  StoryConfig({this.storyPrompt, this.model});

  StoryConfig.fromJson(Map<String, dynamic> json) {
    storyPrompt = json['story_prompt'] as String?;
    model = json['model'] as String?;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['story_prompt'] = storyPrompt;
    data['model'] = model;
    return data;
  }
}

class ExplainImageConfig {
  String? explainImagePrompt; // prompt for single image
  String? multiImagePrompt; // prompt for multiple images
  String? model;

  ExplainImageConfig({this.explainImagePrompt, this.multiImagePrompt, this.model});

  ExplainImageConfig.fromJson(Map<String, dynamic> json) {
    explainImagePrompt = json['image_explanation_prompt'] as String?;
    multiImagePrompt = json['multi_image_prompt'] as String?;
    model = json['model'] as String?;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['image_explanation_prompt'] = explainImagePrompt;
    data['multi_image_prompt'] = multiImagePrompt;
    data['model'] = model;
    return data;
  }
}
