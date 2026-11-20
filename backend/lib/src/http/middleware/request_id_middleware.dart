import 'package:agentic_hive_backend/src/http/request_context.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:shelf/shelf.dart';

/// Gives every request a fresh id (in `Request.context`) and returns it in the
/// `X-Request-Id` header. Ids sent by the client are ignored.
Middleware requestIdMiddleware({String Function() generateId = randomId}) =>
    (inner) => (request) async {
      final id = generateId();
      final response = await inner(
        request.change(context: {requestIdContextKey: id}),
      );
      return response.change(headers: {requestIdHeader: id});
    };
