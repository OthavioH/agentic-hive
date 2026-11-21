/// Contracts shared by the Agentic Hive backend and frontend.
library;

export 'src/http/api_error.dart';
export 'src/http/health_response.dart';
export 'src/http/shutdown_request.dart';
export 'src/http/shutdown_response.dart';
export 'src/http/status_response.dart';
export 'src/json_fields.dart' show JsonMap;
export 'src/workflows/workflow.dart';
export 'src/workflows/workflow_dtos.dart';
export 'src/workflows/workflow_edge.dart';
export 'src/workflows/workflow_node.dart';
export 'src/workflows/workflow_position.dart';
export 'src/workflows/workflow_summary.dart';
export 'src/workflows/workflow_validation.dart';
export 'src/ws/server_hello_payload.dart';
export 'src/ws/ws_close_code.dart';
export 'src/ws/ws_envelope.dart';
export 'src/ws/ws_error_payload.dart';
export 'src/ws/ws_message_type.dart';
