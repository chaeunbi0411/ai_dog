/// 한글 음절의 마지막 글자에 받침이 있는지에 따라 조사만 골라 반환한다.
/// (완성형 한글 유니코드 범위 0xAC00~0xD7A3에서 (code - 0xAC00) % 28 != 0 이면 받침 있음)
String particle(String word, {required String withBatchim, required String noBatchim}) {
  if (word.isEmpty) return noBatchim;
  final code = word.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return noBatchim;
  final hasBatchim = (code - 0xAC00) % 28 != 0;
  return hasBatchim ? withBatchim : noBatchim;
}

// 단어 뒤에 바로 붙일 때는 단어까지 포함해서 반환한다 (예: "엄마가").
String withIGa(String word) => '$word${particle(word, withBatchim: '이', noBatchim: '가')}';

// 이미 "$word"로 따옴표 안에 넣은 뒤라 조사만 필요할 때 쓴다 (예: "밥 주기"를).
// 단어를 다시 포함해서 반환하면 안 된다 - 그러면 문장에 단어가 두 번 들어간다.
String eulReul(String word) => particle(word, withBatchim: '을', noBatchim: '를');
