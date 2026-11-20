import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

/// `GET /health`: the process is up. Checks nothing else, exposes nothing.
Response healthHandler(Request request) =>
    jsonResponse(200, const HealthResponse());
