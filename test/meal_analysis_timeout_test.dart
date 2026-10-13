import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:naazza/features/meal_analysis/data/supabase_meal_analysis_repository.dart';

void main() {
  test('업로드가 응답하지 않으면 지정된 시간 안에 오류를 반환한다', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      try {
        request.response.statusCode = 200;
        request.response.write('{"Key":"meals/test"}');
        await request.response.close();
      } catch (_) {}
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
    );
    final repo = SupabaseMealAnalysisRepository(
      client,
      uploadTimeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      repo.analyze(
        userId: 'tester',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        filename: 'test.png',
      ),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains('시간')),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 170));
    await client.dispose();
    await server.close(force: true);
  });
  test('AI 시간 초과와 실패 사진 삭제 지연이 오류 반환을 막지 않는다', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var cleaned = false;
    server.listen((request) async {
      if (request.method == 'DELETE') {
        cleaned = true;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (request.uri.path.startsWith('/functions/')) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      try {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            request.uri.path.startsWith('/functions/')
                ? {'foods': []}
                : {'Key': 'meals/test'},
          ),
        );
        await request.response.close();
      } catch (_) {}
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
    );
    final repo = SupabaseMealAnalysisRepository(
      client,
      analysisTimeout: const Duration(milliseconds: 30),
      cleanupTimeout: const Duration(milliseconds: 30),
    );
    await expectLater(
      repo.analyze(
        userId: 'tester',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        filename: 'test.png',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('분석 시간이 초과'),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 240));
    expect(cleaned, true);
    await client.dispose();
    await server.close(force: true);
  });
  test('서버 AI 시간 초과 응답은 사용자 안내로 변환한다', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.startsWith('/functions/')) {
        request.response.statusCode = 504;
        request.response.write('{"error":"ai_timeout"}');
      } else {
        request.response.write('{"Key":"meals/test"}');
      }
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
    );
    final repo = SupabaseMealAnalysisRepository(client);
    await expectLater(
      repo.analyze(
        userId: 'tester',
        imageBytes: Uint8List.fromList([1]),
        filename: 'test.png',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('분석 시간이 초과'),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await client.dispose();
    await server.close(force: true);
  });
}
