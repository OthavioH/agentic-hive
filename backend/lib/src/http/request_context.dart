import 'package:shelf/shelf.dart';

/// Key of the request id in `Request.context`.
const requestIdContextKey = 'agentic_hive.request_id';

/// Header that carries the request id back to the client.
const requestIdHeader = 'x-request-id';

/// The id assigned by the request id middleware, if it ran.
String? requestIdOf(Request request) =>
    request.context[requestIdContextKey] as String?;
