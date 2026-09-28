import '../../widgets/word_wrap_text.dart';
import 'package:flutter/material.dart';

import '../controllers/dog_controller.dart';
import '../models/dog_state.dart';

class PetWardrobe extends StatelessWidget {
  const PetWardrobe({
    super.key,
    required this.controller,
    required this.onMotion,
  });
  final DogController controller;
  final VoidCallback onMotion;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        Widget item(String title, int level, bool selected, VoidCallback use) =>
            ListTile(
              title: WordSafeText(title),
              subtitle: WordSafeText(
                state.level >= level ? '해금 완료' : 'Lv.$level에 해금',
              ),
              leading: Icon(
                state.level >= level ? Icons.auto_awesome : Icons.lock_outline,
              ),
              trailing: selected ? const Icon(Icons.check_circle) : null,
              onTap: state.level >= level ? use : null,
            );
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            WordSafeText(
              '옷장 · 성장 선물  Lv.${state.level}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const WordSafeText('함께 돌볼수록 새로운 선물이 열려요.'),
            item(
              '기본 모습',
              1,
              state.accessory == 'none',
              () => controller.customize(accessory: 'none'),
            ),
            item(
              '옷장 · 분홍 리본',
              6,
              state.accessory == 'ribbon',
              () => controller.customize(accessory: 'ribbon'),
            ),
            item(
              '반짝 왕관',
              32,
              state.accessory == 'crown',
              () => controller.customize(accessory: 'crown'),
            ),
            const Divider(),
            item(
              '기본 방',
              1,
              state.roomTheme == 'default',
              () => controller.customize(roomTheme: 'default'),
            ),
            item(
              '방 꾸미기 · 봄빛',
              16,
              state.roomTheme == 'spring',
              () => controller.customize(roomTheme: 'spring'),
            ),
            item(
              '별빛 배경',
              34,
              state.roomTheme == 'starlight',
              () => controller.customize(roomTheme: 'starlight'),
            ),
            item('신나는 인사 모션', 33, false, () {
              Navigator.pop(context);
              onMotion();
            }),
            const Divider(),
            const WordSafeText('성체 이후에는 매 레벨 모자 → 모션 → 배경 → 쿠폰 순으로 선물을 모아요.'),
            for (final reward in AdultReward.values)
              ListTile(
                title: WordSafeText(reward.label),
                subtitle: WordSafeText(
                  reward == AdultReward.coupon
                      ? '쿠폰 사용은 상점 연결 후 제공돼요'
                      : '첫 해금 Lv.${32 + reward.index} · 이후 4레벨마다 수집',
                ),
                trailing: WordSafeText('${state.rewardCount(reward)}개'),
              ),
            const Divider(),
            for (final title in [
              (50, '소통의 달인 가족'),
              (77, '화목함의 끝판왕 가족'),
              (99, '전설의 화목한 가문'),
            ])
              ListTile(
                leading: Icon(
                  state.level >= title.$1
                      ? Icons.emoji_events
                      : Icons.lock_outline,
                ),
                title: WordSafeText(title.$2),
                subtitle: WordSafeText('Lv.${title.$1}'),
              ),
          ],
        );
      },
    ),
  );
}
