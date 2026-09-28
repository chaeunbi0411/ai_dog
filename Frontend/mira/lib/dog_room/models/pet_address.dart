/// A member's chosen address takes priority over the legacy role fallback.
String petAddress(String? role, String? gender, {String? preferredAddress}) {
  final custom = preferredAddress?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  return switch (role) {
    '아들' =>
      gender == 'male'
          ? '형'
          : gender == 'female'
          ? '오빠'
          : '가족',
    '딸' =>
      gender == 'male'
          ? '누나'
          : gender == 'female'
          ? '언니'
          : '가족',
    '엄마' => '엄마',
    '아빠' => '아빠',
    _ => '가족',
  };
}
