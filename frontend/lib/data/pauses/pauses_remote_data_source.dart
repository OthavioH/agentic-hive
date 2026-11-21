import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Remote data source communicating with `/api/v1/pauses` via [BackendClient].
final class PausesRemoteDataSource {
  /// Creates a [PausesRemoteDataSource].
  const new(this._client);

  static const String _basePath = '/api/v1/pauses';
  static const int _pageSize = 50;

  final BackendClient _client;

  /// Fetches all pending pauses by paging through `GET /api/v1/pauses`.
  Future<Result<List<Pause>>> listPendingPauses() async {
    final allItems = <Pause>[];
    var offset = 0;

    while (true) {
      final result = await _client.getJson(
        '$_basePath?status=pending&limit=$_pageSize&offset=$offset',
      );
      switch (result) {
        case FailureResult<JsonMap>(:final failure):
          return FailureResult(failure);
        case Success<JsonMap>(:final value):
          final pageResult = _decodePage(value);
          switch (pageResult) {
            case FailureResult<PausesListResponse>(:final failure):
              return FailureResult(failure);
            case Success<PausesListResponse>(value: final page):
              allItems.addAll(page.items);
              offset += page.items.length;
              if (page.items.isEmpty || allItems.length >= page.total) {
                return Success(allItems);
              }
          }
      }
    }
  }

  /// Submits an answer or decision (`POST /api/v1/pauses/<id>/answer`).
  Future<Result<Pause>> answerPause(
    String id,
    AnswerPauseRequest request,
  ) async {
    final result = await _client.postJson(
      '$_basePath/${Uri.encodeComponent(id)}/answer',
      body: request.toJson(),
    );
    return switch (result) {
      Success<JsonMap>(:final value) => _decodePause(value),
      FailureResult<JsonMap>(:final failure) => FailureResult(
        _mapConflictIfNeeded(failure),
      ),
    };
  }

  Result<PausesListResponse> _decodePage(JsonMap json) {
    try {
      return Success(PausesListResponse.fromJson(json));
    } on FormatException catch (error) {
      return FailureResult(
        BackendFailure('Invalid pauses list response: ${error.message}'),
      );
    }
  }

  Result<Pause> _decodePause(JsonMap json) {
    try {
      return Success(Pause.fromJson(json));
    } on FormatException catch (error) {
      return FailureResult(
        BackendFailure('Invalid pause response: ${error.message}'),
      );
    }
  }

  Failure _mapConflictIfNeeded(Failure failure) {
    if (failure
        case BackendFailure(:final message, :final code, :final statusCode)
        when statusCode == HttpStatus.conflict ||
            code == ApiErrorCode.conflict) {
      return ConflictFailure(message);
    }
    return failure;
  }
}
