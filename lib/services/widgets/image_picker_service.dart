import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  final _picker = ImagePicker();

  Future<Uint8List?> pick(ImageSource source) async {
    final image = await _picker.pickImage(source: source);
    return image?.readAsBytes();
  }
}
