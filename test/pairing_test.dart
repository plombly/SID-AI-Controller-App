import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/services/pairing.dart';

void main() {
  const sample =
      '{"v":1,"name":"Home LAIka","url":"http://10.0.0.59:8000",'
      '"key":"laika_AbC123-_xyz"}';

  test('parses a pairing code', () {
    final server = parsePairingCode(sample, id: 'one');
    expect(server.name, 'Home LAIka');
    expect(server.url, 'http://10.0.0.59:8000');
  });

  test('removes one trailing slash and defaults the name', () {
    final server = parsePairingCode(
      '{"v":1,"url":"https://laika.example///",'
      '"key":"laika_key"}',
      id: 'one',
    );
    expect(server.url, 'https://laika.example//');
    expect(server.name, 'LAIka');
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
          '"key":"laika_key"}', id: 'one'),
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
        'Not a LAIka pairing code',
      )),
    );
  });
}
