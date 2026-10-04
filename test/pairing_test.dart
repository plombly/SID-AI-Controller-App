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

  test('parses alt_urls', () {
    final server = parsePairingCode(
      '{"v":1,"name":"Home LAIka","url":"http://192.168.1.20:8080",'
      '"key":"laika_abc","alt_urls":["http://laika.tail1.ts.net:8080",'
      '"http://100.64.0.5:8080"]}',
      id: 'one',
    );
    expect(server.altUrls, [
      'http://laika.tail1.ts.net:8080',
      'http://100.64.0.5:8080',
    ]);
  });

  test('alt_urls drops invalid, duplicate and main entries', () {
    final server = parsePairingCode(
      '{"v":1,"url":"http://a:1","key":"laika_abc","alt_urls":['
      '"ftp://x","http://b:2/","http://b:2","http://a:1/",5,"https://c"]}',
      id: 'one',
    );
    expect(server.altUrls, ['http://b:2', 'https://c']);
  });

  test('missing or invalid alt_urls gives an empty list', () {
    expect(parsePairingCode(sample, id: 'one').altUrls, isEmpty);
    final server = parsePairingCode(
      '{"v":1,"url":"http://a:1","key":"laika_abc","alt_urls":"nope"}',
      id: 'one',
    );
    expect(server.altUrls, isEmpty);
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
