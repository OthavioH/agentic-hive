// Development tool: connects to a running backend's WebSocket over its Unix
// socket and prints every frame, plus the close code when the backend closes
// the connection.
//
//   dart run tool/ws_probe.dart                 # uses .dev-data/server.json
//   dart run tool/ws_probe.dart --data-dir DIR  # any data folder
//
// Each line typed on stdin is sent as a text frame.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  final args =
      (ArgParser()
            ..addOption('data-dir', defaultsTo: '.dev-data')
            ..addFlag('help', abbr: 'h', negatable: false))
          .parse(arguments);
  if (args.flag('help')) {
    stdout.writeln('Usage: dart run tool/ws_probe.dart [--data-dir DIR]');
    return;
  }

  final serverInfo = File(p.join(args.option('data-dir')!, 'server.json'));
  if (!serverInfo.existsSync()) {
    stderr.writeln(
      'No backend running: ${serverInfo.absolute.path} not found.',
    );
    exitCode = 1;
    return;
  }
  final info =
      jsonDecode(serverInfo.readAsStringSync()) as Map<String, Object?>;
  final address = InternetAddress(
    info['socketPath']! as String,
    type: InternetAddressType.unix,
  );

  final client = HttpClient()
    ..connectionFactory = (uri, proxyHost, proxyPort) =>
        Socket.startConnect(address, 0);
  final socket = await WebSocket.connect(
    'ws://localhost/ws',
    customClient: client,
  );
  stdout.writeln('Connected to ${address.address}. Type a line to send it.');

  final input = stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(socket.add);

  await socket.forEach((frame) => stdout.writeln('<- $frame'));
  stdout.writeln(
    'Closed by the backend: code=${socket.closeCode} '
    'reason="${socket.closeReason}"',
  );
  await input.cancel();
  client.close(force: true);
}
