/// Contracts shared by the Agentic Hive backend and frontend.
library;

export 'src/agents/agent_detail.dart';
export 'src/agents/agent_list_response.dart';
export 'src/agents/agent_summary.dart';
export 'src/agents/create_agent_request.dart';
export 'src/agents/update_agent_request.dart';
export 'src/http/api_error.dart';
export 'src/http/health_response.dart';
export 'src/http/status_response.dart';
export 'src/json_fields.dart' show JsonMap;
export 'src/ws/agents_changed_payload.dart';
export 'src/ws/server_hello_payload.dart';
export 'src/ws/ws_close_code.dart';
export 'src/ws/ws_envelope.dart';
export 'src/ws/ws_error_payload.dart';
export 'src/ws/ws_message_type.dart';
