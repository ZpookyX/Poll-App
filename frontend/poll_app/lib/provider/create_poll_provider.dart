import 'package:flutter/material.dart';

// This provider is used for the create_poll_screen. Originally we used setstate
// for some local changes which maybe would have been okay but just in case we
// now have a provider for that screen as well.

class CreatePollProvider extends ChangeNotifier {
  final TextEditingController q = TextEditingController();
  final List<TextEditingController> optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  void addOptionField() {
    if (optionControllers.length >= 8) return;
    optionControllers.add(TextEditingController());
    notifyListeners();
  }

  void removeOptionField(int index) {
    if (optionControllers.length <= 2) return;
    optionControllers[index].dispose();
    optionControllers.removeAt(index);
    notifyListeners();
  }

  // Flutter needs a dispose function
  @override
  void dispose() {
    q.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
    super.dispose();
  }
}


