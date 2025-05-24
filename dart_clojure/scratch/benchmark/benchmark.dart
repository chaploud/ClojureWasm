import 'dart:math';

void main() {
  comprehensiveBenchmark();
  alternativeBenchmark();
  randomCharacterBenchmark();
  realisticBenchmark();
}

void comprehensiveBenchmark() {
  final text = "1234567890abcdefghijklmnopqrstuvwxyz" * 100000;

  // ウォームアップ
  for (int i = 0; i < 3; i++) {
    _runSafeBenchmark(text);
    _runFastBenchmark(text);
  }

  // 実際の測定（複数回）
  print('=== Benchmark Results ===');
  for (int run = 1; run <= 5; run++) {
    print('Run $run:');

    final safeTime = _runSafeBenchmark(text);
    final fastTime = _runFastBenchmark(text);

    print('  Safe: $safeTimeμs');
    print('  Fast: $fastTimeμs');
    print('  Ratio: ${(fastTime / safeTime).toStringAsFixed(2)}x');
  }
}

int _runSafeBenchmark(String text) {
  final stopwatch = Stopwatch()..start();
  int count = 0;
  for (int i = 0; i < text.length; i++) {
    if (isSafeDigit(text[i])) count++;
  }
  stopwatch.stop();
  return stopwatch.elapsedMicroseconds;
}

int _runFastBenchmark(String text) {
  final stopwatch = Stopwatch()..start();
  int count = 0;
  for (int i = 0; i < text.length; i++) {
    if (isDigit(text[i])) count++;
  }
  stopwatch.stop();
  return stopwatch.elapsedMicroseconds;
}

void alternativeBenchmark() {
  final text = "1234567890abcdefghijklmnopqrstuvwxyz" * 100000;

  // String[index]アクセス
  final stopwatch1 = Stopwatch()..start();
  int count1 = 0;
  for (int i = 0; i < text.length; i++) {
    final char = text[i];
    if (char.compareTo('0') >= 0 && char.compareTo('9') <= 0) count1++;
  }
  stopwatch1.stop();

  // codeUnitAt アクセス
  final stopwatch2 = Stopwatch()..start();
  int count2 = 0;
  for (int i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    if (code >= 48 && code <= 57) count2++;
  }
  stopwatch2.stop();

  print('String[index]: ${stopwatch1.elapsedMicroseconds}μs ($count1)');
  print('codeUnitAt: ${stopwatch2.elapsedMicroseconds}μs ($count2)');
}

void realisticBenchmark() {
  // 実際のClojureコードを模擬
  final clojureCode = '''
(defn factorial [n]
  (if (<= n 1)
    1
    (* n (factorial (- n 1)))))

(defn fibonacci [n]
  (cond
    (= n 0) 0
    (= n 1) 1
    :else (+ (fibonacci (- n 1)) (fibonacci (- n 2)))))

(def numbers [1 2 3 4 5])
(def strings ["hello" "world" "123" "abc"])
(def keywords [:name :age :city])

; Comments with various characters !@#\$%^&*()
(println "Processing numbers: " numbers)
''';

  // より大きなコードベースを模擬
  final largeCode = clojureCode * 1000; // 約100KB

  print('=== Realistic Clojure Code Benchmark ===');
  print('Code size: ${largeCode.length} characters');

  // ウォームアップ
  for (int i = 0; i < 3; i++) {
    _benchmarkRealistic(largeCode, 'warmup');
  }

  // 実測定
  for (int run = 1; run <= 5; run++) {
    final times = _benchmarkRealistic(largeCode, 'Run $run');
    print(
      'Run $run: Safe=${times['safe']}μs, Fast=${times['fast']}μs, '
      'CodeUnit=${times['codeunit']}μs',
    );
  }
}

Map<String, int> _benchmarkRealistic(String code, String label) {
  // Safe version
  final sw1 = Stopwatch()..start();
  int safeCount = 0;
  for (int i = 0; i < code.length; i++) {
    if (isSafeDigit(code[i])) safeCount++;
  }
  sw1.stop();

  // Fast version
  final sw2 = Stopwatch()..start();
  int fastCount = 0;
  for (int i = 0; i < code.length; i++) {
    if (isDigit(code[i])) fastCount++;
  }
  sw2.stop();

  // Direct codeUnitAt
  final sw3 = Stopwatch()..start();
  int codeunitCount = 0;
  for (int i = 0; i < code.length; i++) {
    final code_unit = code.codeUnitAt(i);
    if (code_unit >= 48 && code_unit <= 57) codeunitCount++;
  }
  sw3.stop();

  return {
    'safe': sw1.elapsedMicroseconds,
    'fast': sw2.elapsedMicroseconds,
    'codeunit': sw3.elapsedMicroseconds,
  };
}

void randomCharacterBenchmark() {
  final random = Random(42); // 固定シード
  final chars = <String>[];

  // 様々な文字種を含むランダム文字列生成
  for (int i = 0; i < 1000000; i++) {
    final charCode = random.nextInt(128); // ASCII範囲
    chars.add(String.fromCharCode(charCode));
  }

  final randomText = chars.join();

  print('=== Random Character Benchmark ===');

  // 測定
  final sw1 = Stopwatch()..start();
  int safeCount = 0;
  for (int i = 0; i < randomText.length; i++) {
    if (isSafeDigit(randomText[i])) safeCount++;
  }
  sw1.stop();

  final sw2 = Stopwatch()..start();
  int fastCount = 0;
  for (int i = 0; i < randomText.length; i++) {
    if (isDigit(randomText[i])) fastCount++;
  }
  sw2.stop();

  print('Random Safe: ${sw1.elapsedMicroseconds}μs (found $safeCount)');
  print('Random Fast: ${sw2.elapsedMicroseconds}μs (found $fastCount)');
}

// 安全に呼び出せる(if分遅い)
bool isSafeDigit(String c) {
  if (c.isEmpty) return false;
  final code = c.codeUnitAt(0);
  return code >= 48 && code <= 57;
}

// 高速版(直接コードユニットを比較する)
bool isDigit(String c) {
  final code = c.codeUnitAt(0);
  return code >= 48 && code <= 57;
}
