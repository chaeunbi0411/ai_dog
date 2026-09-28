enum GrowthStage { baby, child, teen, adult }

extension GrowthStageDisplay on GrowthStage {
  String get label => switch (this) {
    GrowthStage.baby => '아기',
    GrowthStage.child => '어린이',
    GrowthStage.teen => '청소년',
    GrowthStage.adult => '성견',
  };

  String get assetPath => switch (this) {
    GrowthStage.baby => 'assets/dog/baby_idle.png',
    GrowthStage.child => 'assets/dog/child_idle.png',
    GrowthStage.teen => 'assets/dog/teen_idle.png',
    GrowthStage.adult => 'assets/dog/adult_idle.png',
  };

  String get levelRange => switch (this) {
    GrowthStage.baby => 'Lv.1~5',
    GrowthStage.child => 'Lv.6~15',
    GrowthStage.teen => 'Lv.16~30',
    GrowthStage.adult => 'Lv.31+',
  };
}

enum AdultReward { hat, motion, background, coupon }

extension AdultRewardDisplay on AdultReward {
  String get label => switch (this) {
    AdultReward.hat => '전용 모자',
    AdultReward.motion => '특별 모션',
    AdultReward.background => '전용 배경',
    AdultReward.coupon => '상점 쿠폰',
  };
}

class DogState {
  const DogState({
    this.hunger = 70,
    this.cleanliness = 70,
    this.happiness = 70,
    this.energy = 70,
    this.affection = 0,
    this.experience = 0,
    this.accessory = 'none',
    this.roomTheme = 'default',
    required this.lastUpdated,
  });

  final int hunger;
  final int cleanliness;
  final int happiness;
  final int energy;
  final int affection;
  final int experience;
  final String accessory;
  final String roomTheme;
  bool get wardrobeUnlocked => level >= 6;
  bool get roomThemesUnlocked => level >= 16;
  int rewardCount(AdultReward reward) {
    final firstLevel = 32 + reward.index;
    return level < firstLevel ? 0 : 1 + (level - firstLevel) ~/ 4;
  }

  String? get familyTitle => level >= 99
      ? '전설의 화목한 가문'
      : level >= 77
      ? '화목함의 끝판왕 가족'
      : level >= 50
      ? '소통의 달인 가족'
      : null;

  bool canWear(String value) =>
      value == 'none' ||
      (value == 'ribbon' && wardrobeUnlocked) ||
      (value == 'crown' && rewardCount(AdultReward.hat) > 0);
  bool canUseTheme(String value) =>
      value == 'default' ||
      (value == 'spring' && roomThemesUnlocked) ||
      (value == 'starlight' && rewardCount(AdultReward.background) > 0);
  final DateTime lastUpdated;

  GrowthStage get stage {
    if (experience >= 9001) return GrowthStage.adult;
    if (experience >= 4001) return GrowthStage.teen;
    if (experience >= 1001) return GrowthStage.child;
    return GrowthStage.baby;
  }

  /// Lv.1~30은 각 진화 구간 안에서 균등하게 성장하며, 성체부터는
  /// 500 EXP마다 제한 없이 한 레벨씩 오른다.
  int get level {
    if (experience >= 9001) return 31 + ((experience - 9001) ~/ 500);
    if (experience >= 4001) return 16 + ((experience - 4001) * 15 ~/ 5000);
    if (experience >= 1001) return 6 + ((experience - 1001) * 10 ~/ 3000);
    return 1 + (experience * 5 ~/ 1001);
  }

  int get currentLevelStartExperience {
    if (level >= 31) return 9001 + (level - 31) * 500;
    if (level >= 16) return 4001 + ((level - 16) * 5000 / 15).ceil();
    if (level >= 6) return 1001 + ((level - 6) * 3000 / 10).ceil();
    return ((level - 1) * 1001 / 5).ceil();
  }

  int get nextLevelExperience {
    if (level >= 31) return 9001 + (level - 30) * 500;
    if (level >= 16) return 4001 + ((level - 15) * 5000 / 15).ceil();
    if (level >= 6) return 1001 + ((level - 5) * 3000 / 10).ceil();
    return (level * 1001 / 5).ceil();
  }

  double get levelProgress =>
      (experience - currentLevelStartExperience) /
      (nextLevelExperience - currentLevelStartExperience);

  int get experienceToNextLevel => nextLevelExperience - experience;

  AdultReward? get nextAdultReward {
    if (level < 31) return null;
    return AdultReward.values[(level - 31) % AdultReward.values.length];
  }

  double get stageProgress => switch (stage) {
    GrowthStage.baby => experience / 1001,
    GrowthStage.child => (experience - 1001) / 3000,
    GrowthStage.teen => (experience - 4001) / 5000,
    GrowthStage.adult => 1,
  };

  String get nextStageText => switch (stage) {
    GrowthStage.baby => '어린이까지 ${1001 - experience} XP',
    GrowthStage.child => '청소년까지 ${4001 - experience} XP',
    GrowthStage.teen => '성체까지 ${9001 - experience} XP',
    GrowthStage.adult => '다음 보상까지 $experienceToNextLevel XP',
  };

  DogState copyWith({
    int? hunger,
    int? cleanliness,
    int? happiness,
    int? energy,
    int? affection,
    int? experience,
    String? accessory,
    String? roomTheme,
    DateTime? lastUpdated,
  }) => DogState(
    hunger: hunger ?? this.hunger,
    cleanliness: cleanliness ?? this.cleanliness,
    happiness: happiness ?? this.happiness,
    energy: energy ?? this.energy,
    affection: affection ?? this.affection,
    experience: experience ?? this.experience,
    accessory: accessory ?? this.accessory,
    roomTheme: roomTheme ?? this.roomTheme,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );

  Map<String, Object> toJson() => {
    'hunger': hunger,
    'cleanliness': cleanliness,
    'happiness': happiness,
    'energy': energy,
    'affection': affection,
    'experience': experience,
    'accessory': accessory,
    'roomTheme': roomTheme,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory DogState.fromJson(Map<String, dynamic> json) => DogState(
    hunger: _readStat(json, 'hunger', 70),
    cleanliness: _readStat(json, 'cleanliness', 70),
    happiness: _readStat(json, 'happiness', 70),
    energy: _readStat(json, 'energy', 70),
    affection: _readNonNegative(json, 'affection'),
    experience: _readNonNegative(json, 'experience'),
    accessory: json['accessory'] as String? ?? 'none',
    roomTheme: json['roomTheme'] as String? ?? 'default',
    lastUpdated:
        DateTime.tryParse(json['lastUpdated'] as String? ?? '') ??
        DateTime.now(),
  );

  static int _readStat(Map<String, dynamic> json, String key, int fallback) =>
      ((json[key] as num?)?.toInt() ?? fallback).clamp(0, 100);

  static int _readNonNegative(Map<String, dynamic> json, String key) {
    final value = (json[key] as num?)?.toInt() ?? 0;
    return value < 0 ? 0 : value;
  }
}
