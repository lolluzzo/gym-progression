/// Logs link to an exercise by name. Two names are the same exercise when
/// their keys are equal: case and extra spaces don't count, so
/// "bench  Press" matches "Bench press".
String exerciseKey(String name) {
  return name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
