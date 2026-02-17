/// Error thrown when widget generation fails.
class GeneratorError extends Error {
  final String message;

  GeneratorError(this.message);

  @override
  String toString() => 'GeneratorError: $message';
}
