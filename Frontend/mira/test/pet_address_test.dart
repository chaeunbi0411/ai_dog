import 'package:flutter_test/flutter_test.dart';
import 'package:mira/dog_room/models/pet_address.dart';

void main() {
  test('chosen address overrides role and gender and trims whitespace', () {
    for (final gender in ['male', 'female', null]) {
      expect(petAddress('딸', gender, preferredAddress: '  유진이  '), '유진이');
      expect(petAddress('아빠', gender, preferredAddress: '형아'), '형아');
    }
    expect(petAddress('엄마', 'female', preferredAddress: '  '), '엄마');
  });
  test('pet gender determines sibling addresses, parents keep their roles', () {
    expect(petAddress('아들', 'male'), '형');
    expect(petAddress('딸', 'male'), '누나');
    expect(petAddress('아들', 'female'), '오빠');
    expect(petAddress('딸', 'female'), '언니');
    for (final gender in ['male', 'female', null]) {
      expect(petAddress('엄마', gender), '엄마');
      expect(petAddress('아빠', gender), '아빠');
    }
  });
  test('missing identity or gender does not invent an address', () {
    expect(petAddress(null, 'male'), '가족');
    expect(petAddress('딸', null), '가족');
    expect(petAddress('아들', 'unknown'), '가족');
  });
}
