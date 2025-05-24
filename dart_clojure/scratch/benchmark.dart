import 'dart:math';

// インライン化を推奨するプラグマ
const preferInline = pragma('vm:prefer-inline');

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

  int count1 = 0;
  final stopwatch1 = Stopwatch()..start();
  for (var i = 0; i < randomText.length; i++) {
    if (isDigitWithInline(randomText[i])) {
      count1++;
    }
  }
  stopwatch1.stop();
  print('${stopwatch1.elapsedMicroseconds}μs: isDigitWithInline');

  int count2 = 0;
  final stopwatch2 = Stopwatch()..start();
  for (var i = 0; i < randomText.length; i++) {
    if (isDigitWithoutInline(randomText[i])) {
      count2++;
    }
  }
  stopwatch2.stop();
  print('${stopwatch2.elapsedMicroseconds}μs: isDigitWithoutInline');

  int count3 = 0;
  final stopwatch3 = Stopwatch()..start();
  for (var i = 0; i < randomText.length; i++) {
    if (isSafeDigitWithInline(randomText[i])) {
      count3++;
    }
  }
  stopwatch3.stop();
  print('${stopwatch3.elapsedMicroseconds}μs: isSafeDigitWithInline');

  int count4 = 0;
  final stopwatch4 = Stopwatch()..start();
  for (var i = 0; i < randomText.length; i++) {
    if (isSafeDigitWithoutInline(randomText[i])) {
      count4++;
    }
  }
  stopwatch4.stop();
  print('${stopwatch4.elapsedMicroseconds}μs: isSafeDigitWithoutInline');

  // 結果の整合性チェック
  if (count1 == count2 && count1 == count3 && count1 == count4) {
    print('All methods found the same number of digits.');
  } else {
    print('Warning: Different number of digits found by methods.');
    print('Counts: $count1, $count2, $count3, $count4');
  }
}

@preferInline
bool isDigitWithInline(String c) {
  // 前提: c は常に1文字の文字列として渡される。
  final code = c.codeUnitAt(0);
  return code >= 48 && code <= 57; // ASCII '0' to '9'
}

bool isDigitWithoutInline(String c) {
  // 前提: c は常に1文字の文字列として渡される。
  final code = c.codeUnitAt(0);
  return code >= 48 && code <= 57; // ASCII '0' to '9'
}

@preferInline
bool isSafeDigitWithInline(String c) {
  if (c.isEmpty) return false; // 空文字チェック
  final code = c.codeUnitAt(0);
  return code >= 48 && code <= 57; // ASCII '0' to '9'
}

bool isSafeDigitWithoutInline(String c) {
  if (c.isEmpty) return false; // 空文字チェック
  final code = c.codeUnitAt(0);
  return code >= 48 && code <= 57; // ASCII '0' to '9'
}
