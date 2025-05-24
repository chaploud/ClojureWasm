import 'dart:math';

void main() {
  randomCharacterBenchmark();
}

void randomCharacterBenchmark() {
  final random = Random(42); // 固定シードで再現性を確保
  // String.fromCharCodes に渡す前に、各要素を String に変換する必要はありません。
  // random.nextInt(128) は int を返すので、そのまま List<int> として使用します。
  final charCodes = List.generate(1000000, (_) => random.nextInt(128)); // ASCII範囲の文字コード
  final randomText = String.fromCharCodes(charCodes);

  print('=== Random Character Benchmark (String Length: ${randomText.length}) ===');

  final stopwatch1 = Stopwatch()..start();
  for (var i = 0; i < randomText.length; i++) {
    isDigit(randomText[i]);
  }
  stopwatch1.stop();
  print('${stopwatch1.elapsedMicroseconds}μs: isDigit');

  final stopwatch2 = Stopwatch()..start();
  for (var i = 0; i < randomText.length; i++) {
    isSafeDigit(randomText[i]);
  }
  stopwatch2.stop();
  print('${stopwatch2.elapsedMicroseconds}μs: isSafeDigit');

  final stopwatch3 = Stopwatch()..start();
  for (var i = 0; i < randomText.length; i++) {
    isDigitWithString(randomText[i]);
  }
  stopwatch3.stop();
  print('${stopwatch3.elapsedMicroseconds}μs: isDigitWithString');

  final stopwatch4 = Stopwatch()..start();
  for (var i = 0; i < randomText.length; i++) {
    isDigitWithRegex(randomText[i]);
  }
  stopwatch4.stop();
  print('${stopwatch4.elapsedMicroseconds}μs: isDigitWithRegex');

  final stopwatch5 = Stopwatch()..start();
  for (var i = 0; i < randomText.length; i++) {
    isDigitWithList(randomText[i]);
  }
  stopwatch5.stop();
  print('${stopwatch5.elapsedMicroseconds}μs: isDigitWithList');

  print('=== Benchmark Completed ===');
}

bool isDigit(String c) {
  // 前提: c は常に1文字の文字列として渡される。
  final code = c.codeUnitAt(0);
  return code >= 48 && code <= 57; // ASCII '0' to '9'
}

bool isSafeDigit(String c) {
  if (c.isEmpty) return false; // 空文字チェック
  final code = c.codeUnitAt(0);
  return code >= 48 && code <= 57; // ASCII '0' to '9'
}

// 単なる文字列比較
bool isDigitWithString(String c) {
  return c == '0' ||
      c == '1' ||
      c == '2' ||
      c == '3' ||
      c == '4' ||
      c == '5' ||
      c == '6' ||
      c == '7' ||
      c == '8' ||
      c == '9';
}

// 含まれるかどうかをリストでチェック
bool isDigitWithList(String c) {
  const digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  return digits.contains(c);
}

// 正規表現によるチェック
bool isDigitWithRegex(String c) {
  return RegExp(r'^[0-9]$').hasMatch(c);
}
