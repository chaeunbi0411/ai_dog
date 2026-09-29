import 'dart:typed_data';
import 'dart:convert';
import '../dog_room/models/character_animation_set.dart';

import 'package:http/http.dart' as http;

// Backend/character-server(Stable Diffusion, GPU 필요)의 주소.
// 로컬에 GPU가 없다면 Colab에서 띄우고 ngrok 주소로 바꿔주세요.
// 자세한 실행 방법은 Backend/character-server/README.md 참고.
// TODO: Colab 세션이 끊기면 ngrok 주소가 바뀌니 그때마다 여기 업데이트 필요.
const _characterServerBaseUrl = String.fromEnvironment('CHARACTER_SERVER_URL',
  defaultValue: 'https://contents-revenue-opossum.ngrok-free.dev');

class CharacterServerException implements Exception {
  CharacterServerException(this.message);
  final String message;
}

class CharacterServerService {
  CharacterServerService._();
  static final instance = CharacterServerService._();

  /// Prepare hidden clips using the exact preview, rather than a new character.
  Future<CharacterAnimationSet> generateMotions({required Uint8List preview,
    required String breed, required String color, required String personality,
    required int seed, bool Function()? isCancelled}) async {
    final client = http.Client();
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_characterServerBaseUrl/motion-jobs'))
        ..headers['ngrok-skip-browser-warning'] = 'true'
        ..fields.addAll({'breed': breed, 'color': color, 'personality': personality, 'seed': '$seed'})
        ..files.add(http.MultipartFile.fromBytes('image', preview, filename: 'character.png'));
      final started = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 30)));
      if (started.statusCode != 202) {
        throw CharacterServerException(started.statusCode == 404
          ? '캐릭터 서버 업데이트가 필요해요. 동작 생성 기능이 있는 서버를 연결해주세요.'
          : '강아지 동작을 준비하지 못했어요. 잠시 후 다시 시도해주세요.');
      }
      final id = (jsonDecode(started.body) as Map<String, dynamic>)['id'] as String;
      final deadline = DateTime.now().add(const Duration(minutes: 15));
      while (DateTime.now().isBefore(deadline)) {
        if (isCancelled?.call() ?? false) throw CharacterServerException('생성을 취소했어요.');
        final response = await client.get(Uri.parse('$_characterServerBaseUrl/motion-jobs/$id'),
          headers: const {'ngrok-skip-browser-warning': 'true'})
          .timeout(const Duration(seconds: 60));
        if (response.statusCode != 200) throw CharacterServerException('동작 준비 상태를 확인하지 못했어요. 다시 시도해주세요.');
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        if (result['status'] == 'ready') {
          final character = CharacterAnimationSet.fromJson(result['character'] as Map<String, dynamic>);
          // Keep the exact preview originally shown to the user.
          return CharacterAnimationSet(preview: preview, clips: character.clips);
        }
        if (result['status'] == 'failed') throw CharacterServerException('강아지 동작을 만들지 못했어요. 다시 시도해주세요.');
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      throw CharacterServerException('강아지 동작 준비가 오래 걸리고 있어요. 다시 시도해주세요.');
    } on CharacterServerException {
      rethrow;
    } catch (_) {
      throw CharacterServerException('강아지 동작을 받지 못했어요. 서버 연결을 확인해주세요.');
    } finally {
      client.close();
    }
  }

  /// 견종/색상/성격(한국어)으로 강아지 마스코트 캐릭터 이미지를 생성한다.
  /// 업로드한 사진 자체는 반영하지 않는다 — SD1.5 img2img로 시도해봤지만 사진마다
  /// 결과가 너무 들쭉날쭉해서(형태가 깨지거나 스타일 변환이 거의 안 되거나) 포기했다.
  /// 항상 서버 쪽 기준 이미지(baby_idle.png)에서 시작해 텍스트로만 반영한다.
  /// 같은 [seed]를 넘기면 같은 이미지가 다시 나온다.
  Future<Uint8List> generate({
    required String breed,
    required String color,
    required String personality,
    int seed = 42,
  }) async {
    final uri = Uri.parse('$_characterServerBaseUrl/generate');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            // ngrok 무료 플랜은 브라우저발 요청에 API 응답 대신 경고 페이지(HTML)를
            // 먼저 보여준다 — 이 헤더로 건너뛴다. (curl 등에서는 안 붙어도 되지만
            // Flutter web처럼 브라우저에서 직접 fetch할 때는 꼭 필요하다.)
            headers: const {'ngrok-skip-browser-warning': 'true'},
            body: {
              'breed': breed,
              'color': color,
              'personality': personality,
              'seed': '$seed',
            },
          )
          // Colab을 막 재시작한 직후 첫 요청은 모델을 새로 내려받고 GPU에 올리느라
          // 오래 걸릴 수 있어서(수십 초~수 분) 넉넉하게 잡는다.
          .timeout(const Duration(seconds: 180));
    } catch (_) {
      throw CharacterServerException(
        '캐릭터 생성 서버에 연결하지 못했어요. character-server가 실행 중인지 확인해주세요.',
      );
    }

    if (response.statusCode != 200) {
      throw CharacterServerException('캐릭터를 만들지 못했어요. (${response.statusCode})');
    }
    return response.bodyBytes;
  }
}
