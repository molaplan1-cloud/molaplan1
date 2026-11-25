import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/account/supabase_api.dart';

void main() {
  test('account deletion helpers list and remove only the own <uid>/ images', () async {
    final files = {'u1/a.jpg', 'u1/b.jpg', 'u2/c.jpg'};
    final api = AccountApi(
      url: 'https://x.supabase.co',
      key: 'k',
      client: MockClient((r) async {
        if (r.url.path == '/storage/v1/object/list/tile-images') {
          final prefix = (jsonDecode(r.body) as Map)['prefix'] as String;
          expect(r.headers['Authorization'], 'Bearer a');
          return http.Response(
            jsonEncode([
              for (final f in files.where((f) => f.startsWith(prefix))) {'name': f.substring(prefix.length)},
            ]),
            200,
          );
        }
        if (r.method == 'DELETE' && r.url.path == '/storage/v1/object/tile-images') {
          files.removeAll(((jsonDecode(r.body) as Map)['prefixes'] as List).cast<String>());
          return http.Response('[]', 200);
        }
        return http.Response('no', 404);
      }),
    );
    final s = Session(access: 'a', refresh: 'r', expiresAt: DateTime(2100), userId: 'u1', email: 'e@x.fi');
    final names = await api.listImages(s);
    expect(names, unorderedEquals(['a.jpg', 'b.jpg']));
    await api.deleteImages(s, names);
    expect(files, {'u2/c.jpg'});
  });

  test('listImages returns [] when storage is unavailable', () async {
    final api = AccountApi(client: MockClient((r) async => http.Response('{"error":"Bucket not found"}', 400)));
    final s = Session(access: 'a', refresh: 'r', expiresAt: DateTime(2100), userId: 'u1', email: 'e@x.fi');
    expect(await api.listImages(s), isEmpty);
  });
}
