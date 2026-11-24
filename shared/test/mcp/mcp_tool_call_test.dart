import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('McpToolCallRequest', () {
    test('McpToolCallRequest round-trips arguments and cwd', () {
      const request = McpToolCallRequest(
        arguments: <String, Object?>{
          'workspace': 'global',
          'id': 'review-loop',
          'detail': 'compact',
        },
        cwd: r'C:\Users\me\app',
      );

      final decoded = McpToolCallRequest.fromJson(request.toJson());
      expect(decoded, equals(request));
    });

    test('McpToolCallRequest defaults arguments to empty', () {
      final decoded = McpToolCallRequest.fromJson(const <String, Object?>{});
      expect(decoded.arguments, isEmpty);
      expect(decoded.cwd, isNull);
    });
  });

  group('McpToolCallResponse', () {
    test('McpToolCallResponse round-trips text', () {
      const response = McpToolCallResponse(text: 'Scope: Global');

      final decoded = McpToolCallResponse.fromJson(response.toJson());
      expect(decoded, equals(response));
    });
  });
}
