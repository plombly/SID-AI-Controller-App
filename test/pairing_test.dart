import 'package:flutter_test/flutter_test.dart';
import 'package:sid_app/services/pairing.dart';

void main() {
  const sample =
      '{"v":1,"name":"Home SID","url":"http://10.0.0.59:8000",'
      '"key":"sidk_AbC123-_xyz"}';

  test('parses a pairing code', () {
    final server = parsePairingCode(sample, id: 'one');
    expect(server.name, 'Home SID');
    expect(server.url, 'http://10.0.0.59:8000');
  });

  test('removes one trailing slash and defaults the name', () {
    final server = parsePairingCode(
      '{"v":1,"url":"https://sid.example///",'
      '"key":"sidk_key"}',
      id: 'one',
    );
    expect(server.url, 'https://sid.example//');
    expect(server.name, 'SID');
  });

  test('rejects invalid pairing codes', () {
    expect(
      () => parsePairingCode('{"v":2}', id: 'one'),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        'Unsupported pairing code version',
      )),
    );
    expect(
      () => parsePairingCode('{"v":1,"url":"ftp://x",'
          '"key":"sidk_key"}', id: 'one'),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        'Invalid server address',
      )),
    );
    expect(
      () => parsePairingCode('{"v":1,"url":"http://x",'
          '"key":"key"}', id: 'one'),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        'Invalid device key',
      )),
    );
    expect(
      () => parsePairingCode('hello', id: 'one'),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        'Not a SID pairing code',
      )),
    );
  });
}
