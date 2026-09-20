import 'package:flutter_test/flutter_test.dart';
import 'package:mira/utils/korean_particles.dart';

void main() {
  test('withIGa picks 이/가 by batchim and includes the word once', () {
    expect(withIGa('엄마'), '엄마가');
    expect(withIGa('아들'), '아들이');
  });

  test('eulReul returns only the particle, not the word', () {
    expect(eulReul('🍚 밥 주기'), '를');
    expect(eulReul('🛁 목욕'), '을');
  });

  test('quoting an action then appending eulReul does not repeat the word', () {
    const action = '🍚 밥 주기';
    final message = '${withIGa('엄마')} "$action"${eulReul(action)} 완료했어요.';
    expect(message, '엄마가 "🍚 밥 주기"를 완료했어요.');
    expect(action.allMatches(message).length, 1);
  });
}
