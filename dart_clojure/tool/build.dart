import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Usage: dart tool/build.dart <task>');
    print('Available tasks: clean, format, analyze, test, run');
    exit(1);
  }

  final task = arguments[0];
  switch (task) {
    case 'clean':
      await _clean();
    case 'format':
      await _format();
    case 'analyze':
      await _analyze();
    case 'test':
      await _test();
    case 'run':
      await _run(arguments.sublist(1));
    default:
      print('Unknown task: $task');
      exit(1);
  }
}

Future<void> _runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  print('Running: $executable ${arguments.join(' ')}');
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  if (result.stdout.toString().isNotEmpty) {
    print(result.stdout);
  }
  if (result.stderr.toString().isNotEmpty) {
    print(result.stderr);
  }
  if (result.exitCode != 0) {
    throw Exception('Command failed with exit code ${result.exitCode}');
  }
}

Future<void> _clean() async {
  final buildDir = Directory('build');
  if (await buildDir.exists()) {
    print('Deleting build directory...');
    await buildDir.delete(recursive: true);
  }
  print('Clean task completed.');
}

Future<void> _format() async {
  await _runCommand('dart', ['format', '.']);
  print('Format task completed.');
}

Future<void> _analyze() async {
  await _runCommand('dart', ['analyze']);
  print('Analyze task completed.');
}

Future<void> _test() async {
  await _runCommand('dart', ['test']);
  print('Test task completed.');
}

Future<void> _run(List<String> args) async {
  // This will eventually run the Dartjure REPL or a script
  // For now, a placeholder
  print('Running Dartjure (placeholder)... Args: $args');
  await _runCommand('dart', ['run', 'bin/dartjure.dart', ...args]);
}
