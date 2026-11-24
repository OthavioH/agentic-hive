import 'package:agentic_hive_backend/src/domain/skills/skill_auto_install_service.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

/// HTTP handlers for `/api/v1/skills/auto-install`.
final class SkillAutoInstallHandler {
  /// Creates a [SkillAutoInstallHandler].
  const new(this._service);

  final SkillAutoInstallService _service;

  /// `GET /api/v1/skills/auto-install/notice` → 200
  /// [SkillAutoInstallNoticeResponse] (`{"notice": null}` when none).
  Future<Response> getNotice(Request request) async => jsonResponse(
    200,
    SkillAutoInstallNoticeResponse(notice: _service.pendingNotice).toJson(),
  );

  /// `DELETE /api/v1/skills/auto-install/notice` → 204, idempotent.
  Future<Response> dismissNotice(Request request) async {
    _service.dismissNotice(noticeId: request.url.queryParameters['id']);
    return Response(204);
  }
}
