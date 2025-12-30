import 'dart:io';

/// Simple indirection for CLI output so tests can assert stdout/stderr messages
/// deterministically.
///
/// Production uses [CliIO.system]. Tests can set [cliIO] to capture output.
final class CliIO {
  CliIO({required this.out, required this.err});

  factory CliIO.system() => CliIO(
        out: (s) => stdout.write(s),
        err: (s) => stderr.write(s),
      );

  final void Function(String) out;
  final void Function(String) err;

  void writeOut(String s) => out(s);
  void writelnOut([String s = '']) => out('$s\n');

  void writeErr(String s) => err(s);
  void writelnErr([String s = '']) => err('$s\n');
}

CliIO _cliIO = CliIO.system();

/// Current CLI IO instance used throughout the CLI implementation.
CliIO get cliIO => _cliIO;
set cliIO(CliIO value) => _cliIO = value;

void resetCliIO() {
  _cliIO = CliIO.system();
}
