/// Thrown by [ChatController.raceWithCancel] when the user presses Stop.
/// AI services catch this to exit silently without showing an error message.
class AICancelledException implements Exception {
  const AICancelledException();
}
