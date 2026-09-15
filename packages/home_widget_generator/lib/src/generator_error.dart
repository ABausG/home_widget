/// Error thrown when widget generation fails.
class GeneratorError implements Exception {
  final String message;

  const GeneratorError(this.message);

  @override
  String toString() => 'GeneratorError: $message';
}
