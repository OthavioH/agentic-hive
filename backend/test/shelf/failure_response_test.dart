import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/request_context.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('mapFailureToHttp', () {
    test('maps NotFoundFailure to 404 not_found with message', () {
      final mapped = mapFailureToHttp(
        const NotFoundFailure('Workflow not found.'),
        requestId: 'req-1',
      );

      expect(mapped.statusCode, 404);
      expect(
        mapped.error,
        const ApiError(
          code: ApiErrorCode.notFound,
          message: 'Workflow not found.',
          requestId: 'req-1',
        ),
      );
    });

    test('maps ValidationFailure to 400 bad_request with message', () {
      final mapped = mapFailureToHttp(
        const ValidationFailure('Name must not be empty.'),
        requestId: 'req-2',
      );

      expect(mapped.statusCode, 400);
      expect(
        mapped.error,
        const ApiError(
          code: ApiErrorCode.badRequest,
          message: 'Name must not be empty.',
          requestId: 'req-2',
        ),
      );
    });

    test('maps PauseRequestedFailure to 409 conflict', () {
      final mapped = mapFailureToHttp(
        const PauseRequestedFailure(
          'Run paused.',
          kind: PauseKind.approval,
          runId: 'run-1',
          nodeId: 'gate',
        ),
      );

      expect(mapped.statusCode, 409);
      expect(mapped.error.code, ApiErrorCode.conflict);
    });

    test('maps ConflictFailure to 409 conflict with message', () {
      final mapped = mapFailureToHttp(
        const ConflictFailure('Run is already active.'),
      );

      expect(mapped.statusCode, 409);
      expect(
        mapped.error,
        const ApiError(
          code: ApiErrorCode.conflict,
          message: 'Run is already active.',
        ),
      );
    });

    test('maps PersistenceFailure to 500 internal_error without leaking '
        'details', () {
      final mapped = mapFailureToHttp(
        const PersistenceFailure('SQLITE_BUSY: database is locked'),
        requestId: 'req-3',
      );

      expect(mapped.statusCode, 500);
      expect(
        mapped.error,
        const ApiError(
          code: ApiErrorCode.internalError,
          message: 'Internal server error.',
          requestId: 'req-3',
        ),
      );
    });

    test('maps UnexpectedFailure to 500 internal_error without leaking '
        'details', () {
      final mapped = mapFailureToHttp(
        UnexpectedFailure(
          'Null check operator used on null',
          cause: StateError('x'),
        ),
        requestId: 'req-4',
      );

      expect(mapped.statusCode, 500);
      expect(
        mapped.error,
        const ApiError(
          code: ApiErrorCode.internalError,
          message: 'Internal server error.',
          requestId: 'req-4',
        ),
      );
    });
  });

  group('failureResponse', () {
    test('writes status code, ApiError JSON body, and requestId from '
        'context', () async {
      final request = buildRequest('/api/v1/workflows/missing')
          .change(context: {requestIdContextKey: 'req-ctx-1'});

      final response = failureResponse(
        request,
        const NotFoundFailure('Workflow not found.'),
      );

      expect(response.statusCode, 404);
      final body = await readJson(response);
      expect(
        ApiError.fromJson(body),
        const ApiError(
          code: ApiErrorCode.notFound,
          message: 'Workflow not found.',
          requestId: 'req-ctx-1',
        ),
      );
    });
  });
}
