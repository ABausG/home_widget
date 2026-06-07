/// Exception thrown when code generation fails.
class GeneratorError implements Exception {
  /// The error message describing the failure.
  final String message;

  /// Creates a [GeneratorError] with the given [message].
  const GeneratorError(this.message);

  @override
  String toString() => 'GeneratorError: $message';
}
