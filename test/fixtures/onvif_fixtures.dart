/// ONVIF SOAP answers per brand (t153u), shaped after the vendors' real answers (element
/// names, namespaces, service paths, ports, faults). A [FakeOnvifCamera] serves them and
/// enforces each brand's login quirks.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

String soap(String body, {String ns = ''}) =>
    '<?xml version="1.0" encoding="UTF-8"?><env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope" '
    'xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:trt="http://www.onvif.org/ver10/media/wsdl" '
    'xmlns:tr2="http://www.onvif.org/ver20/media/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema" $ns>'
    '<env:Body>$body</env:Body></env:Envelope>';

final notAuthorized = soap(
  '<env:Fault><env:Code><env:Value>env:Sender</env:Value><env:Subcode><env:Value>ter:NotAuthorized</env:Value>'
  '</env:Subcode></env:Code><env:Reason><env:Text xml:lang="en">Sender not Authorized</env:Text></env:Reason></env:Fault>',
);

String dateTime(DateTime t) => soap(
  '<tds:GetSystemDateAndTimeResponse><tds:SystemDateAndTime><tt:DateTimeType>NTP</tt:DateTimeType>'
  '<tt:DaylightSavings>false</tt:DaylightSavings><tt:UTCDateTime><tt:Time><tt:Hour>${t.hour}</tt:Hour>'
  '<tt:Minute>${t.minute}</tt:Minute><tt:Second>${t.second}</tt:Second></tt:Time><tt:Date><tt:Year>${t.year}</tt:Year>'
  '<tt:Month>${t.month}</tt:Month><tt:Day>${t.day}</tt:Day></tt:Date></tt:UTCDateTime></tds:SystemDateAndTime>'
  '</tds:GetSystemDateAndTimeResponse>',
);

String info(String maker, String model) => soap(
  '<tds:GetDeviceInformationResponse><tds:Manufacturer>$maker</tds:Manufacturer><tds:Model>$model</tds:Model>'
  '<tds:FirmwareVersion>V1.0</tds:FirmwareVersion><tds:SerialNumber>X1</tds:SerialNumber><tds:HardwareId>88</tds:HardwareId>'
  '</tds:GetDeviceInformationResponse>',
);

String services(String device, {String? media1, String? media2}) => soap(
  '<tds:GetServicesResponse>'
  '<tds:Service><tds:Namespace>http://www.onvif.org/ver10/device/wsdl</tds:Namespace><tds:XAddr>$device</tds:XAddr>'
  '<tds:Version><tt:Major>2</tt:Major><tt:Minor>60</tt:Minor></tds:Version></tds:Service>'
  '${media1 == null ? '' : '<tds:Service><tds:Namespace>http://www.onvif.org/ver10/media/wsdl</tds:Namespace><tds:XAddr>$media1</tds:XAddr></tds:Service>'}'
  '${media2 == null ? '' : '<tds:Service><tds:Namespace>http://www.onvif.org/ver20/media/wsdl</tds:Namespace><tds:XAddr>$media2</tds:XAddr></tds:Service>'}'
  '</tds:GetServicesResponse>',
);

String capabilities(String media) => soap(
  '<tds:GetCapabilitiesResponse><tds:Capabilities><tt:Media><tt:XAddr>$media</tt:XAddr>'
  '<tt:StreamingCapabilities><tt:RTP_TCP>true</tt:RTP_TCP></tt:StreamingCapabilities></tt:Media></tds:Capabilities>'
  '</tds:GetCapabilitiesResponse>',
);

/// Media1 profiles: (token, video source token).
String profiles1(List<(String, String)> p) => soap(
  '<trt:GetProfilesResponse>${[for (final (tok, src) in p) '<trt:Profiles fixed="true" token="$tok"><tt:Name>$tok</tt:Name><tt:VideoSourceConfiguration token="vsc_$src">'
        '<tt:Name>$src</tt:Name><tt:UseCount>2</tt:UseCount><tt:SourceToken>$src</tt:SourceToken>'
        '<tt:Bounds x="0" y="0" width="1920" height="1080"/></tt:VideoSourceConfiguration></trt:Profiles>'].join()}</trt:GetProfilesResponse>',
);

/// Media2 profiles (Profile T).
String profiles2(List<(String, String)> p) => soap(
  '<tr2:GetProfilesResponse>${[for (final (tok, src) in p) '<tr2:Profiles token="$tok" fixed="true"><tr2:Name>$tok</tr2:Name><tr2:Configurations>'
        '<tr2:VideoSource token="vsc_$src"><tt:Name>$src</tt:Name><tt:UseCount>1</tt:UseCount>'
        '<tt:SourceToken>$src</tt:SourceToken></tr2:VideoSource></tr2:Configurations></tr2:Profiles>'].join()}</tr2:GetProfilesResponse>',
);

final emptyProfiles = soap('<trt:GetProfilesResponse/>');

String streamUri1(String uri) => soap(
  '<trt:GetStreamUriResponse><trt:MediaUri><tt:Uri>$uri</tt:Uri><tt:InvalidAfterConnect>false</tt:InvalidAfterConnect>'
  '<tt:Timeout>PT60S</tt:Timeout></trt:MediaUri></trt:GetStreamUriResponse>',
);

String streamUri2(String uri) => soap('<tr2:GetStreamUriResponse><tr2:Uri>$uri</tr2:Uri></tr2:GetStreamUriResponse>');

String snapUri1(String uri) =>
    soap('<trt:GetSnapshotUriResponse><trt:MediaUri><tt:Uri>$uri</tt:Uri></trt:MediaUri></trt:GetSnapshotUriResponse>');

final actionNotSupported = soap(
  '<env:Fault><env:Code><env:Value>env:Receiver</env:Value><env:Subcode><env:Value>ter:ActionNotSupported</env:Value>'
  '</env:Subcode></env:Code><env:Reason><env:Text xml:lang="en">Optional Action Not Implemented</env:Text></env:Reason></env:Fault>',
);

/// How a brand treats the login.
enum Login {
  /// WS-UsernameToken digest required; Created must be within 5 s of the camera clock.
  wsSecurity,

  /// WS-Security rejected; the HTTP Digest layer (done by the camera driver) is enough.
  httpDigestOnly,

  /// Answers everything, but GetProfiles is EMPTY unless the request carries WS-Security.
  emptyWithoutWs,
}

class FakeOnvifCamera {
  FakeOnvifCamera({
    required this.login,
    required this.handlers,
    this.user = 'admin',
    this.password = 'Kamera123',
    Duration clockOffset = Duration.zero,
  }) : _offset = clockOffset;
  final Login login;
  final String user, password;
  final Duration _offset;

  /// Operation name (e.g. 'GetProfiles', 'tr2:GetProfiles') → answer for the request path/body.
  final Map<String, String? Function(String path, String body)> handlers;
  final calls = <String>[];

  DateTime get now => DateTime.now().toUtc().add(_offset);

  bool _wsOk(String body) {
    final nonce = RegExp(r'<Nonce[^>]*>([^<]+)</Nonce>').firstMatch(body)?.group(1);
    final created = RegExp(r'<Created[^>]*>([^<]+)</Created>').firstMatch(body)?.group(1);
    final pw = RegExp(r'<Password[^>]*>([^<]+)</Password>').firstMatch(body)?.group(1);
    final u = RegExp(r'<Username>([^<]+)</Username>').firstMatch(body)?.group(1);
    if (nonce == null || created == null || pw == null || u != user) return false;
    final want = base64Encode(
      sha1.convert([...base64Decode(nonce), ...utf8.encode(created), ...utf8.encode(password)]).bytes,
    );
    if (pw != want) return false;
    final t = DateTime.tryParse(created);
    return t != null && t.difference(now).inSeconds.abs() <= 5;
  }

  String op(String body) {
    final m = RegExp(r'<s:Body><(\w+):(\w+)').firstMatch(body);
    if (m == null) return '';
    return m.group(1) == 'tr2' ? 'tr2:${m.group(2)}' : m.group(2)!;
  }

  Future<String> post(String path, String body) async {
    final o = op(body);
    calls.add('$path $o${body.contains('<Security') ? ' +ws' : ''}');
    if (o == 'GetSystemDateAndTime') return dateTime(now);
    final hasWs = body.contains('<Security');
    switch (login) {
      case Login.wsSecurity:
        if (!_wsOk(body)) return notAuthorized;
      case Login.httpDigestOnly:
        if (hasWs) return notAuthorized;
      case Login.emptyWithoutWs:
        if (hasWs && !_wsOk(body)) return notAuthorized;
        if (!hasWs && (o == 'GetProfiles' || o == 'tr2:GetProfiles')) return emptyProfiles;
    }
    final h = handlers[o];
    return h?.call(path, body) ?? actionNotSupported;
  }
}

String token(String body) => RegExp(r'ProfileToken>([^<]+)<').firstMatch(body)?.group(1) ?? '';

/// Hikvision DS-2CD2143G2: media on /onvif/Media, profiles Profile_1 (main) / Profile_2 (sub),
/// WS-Security required, camera clock 2 h off (no NTP).
FakeOnvifCamera hikvision() => FakeOnvifCamera(
  login: Login.wsSecurity,
  clockOffset: const Duration(hours: 2, minutes: 3),
  handlers: {
    'GetDeviceInformation': (_, _) => info('HIKVISION', 'DS-2CD2143G2-I'),
    'GetServices': (_, _) => services(
      'http://192.168.1.64/onvif/device_service',
      media1: 'http://192.168.1.64/onvif/Media',
      media2: 'http://192.168.1.64/onvif/Media2',
    ),
    'GetProfiles': (p, _) =>
        p.endsWith('/onvif/Media') ? profiles1([('Profile_1', 'VideoSource_1'), ('Profile_2', 'VideoSource_1')]) : null,
    'GetStreamUri': (_, b) => streamUri1(
      'rtsp://192.168.1.64:554/Streaming/Channels/${token(b) == 'Profile_1' ? 101 : 102}?transportmode=unicast&amp;profile=${token(b)}',
    ),
    'GetSnapshotUri': (_, _) => snapUri1('http://192.168.1.64/onvif-http/snapshot?Profile_1'),
  },
);

/// Dahua IPC-HDW2431T: GetServices not implemented (GetCapabilities only), profiles EMPTY
/// unless the request has WS-Security.
FakeOnvifCamera dahua() => FakeOnvifCamera(
  login: Login.emptyWithoutWs,
  handlers: {
    'GetDeviceInformation': (_, _) => info('Dahua', 'IPC-HDW2431T-AS-S2'),
    'GetCapabilities': (_, _) => capabilities('http://192.168.1.108/onvif/media_service'),
    'GetProfiles': (p, _) => p.endsWith('/onvif/media_service')
        ? profiles1([('MediaProfile00000', '000'), ('MediaProfile00001', '000')])
        : null,
    'GetStreamUri': (_, b) => streamUri1(
      'rtsp://192.168.1.108:554/cam/realmonitor?channel=1&amp;subtype=${token(b).endsWith('1') ? 1 : 0}&amp;unicast=true&amp;proto=Onvif',
    ),
    'GetSnapshotUri': (_, _) => snapUri1('http://192.168.1.108/onvif/snapshot/1'),
  },
);

/// Reolink RLC-510A: ONVIF on port 8000; tells an XAddr with another address (NAT/2nd NIC).
FakeOnvifCamera reolink() => FakeOnvifCamera(
  login: Login.wsSecurity,
  handlers: {
    'GetDeviceInformation': (_, _) => info('Reolink', 'RLC-510A'),
    'GetServices': (_, _) =>
        services('http://10.0.0.5:8000/onvif/device_service', media1: 'http://10.0.0.5:8000/onvif/Media'),
    'GetProfiles': (p, _) => p == ':8000/onvif/Media' ? profiles1([('000', '000'), ('001', '000')]) : null,
    'GetStreamUri': (_, b) =>
        streamUri1('rtsp://10.0.0.5:554/${token(b) == '000' ? 'h264Preview_01_main' : 'h264Preview_01_sub'}'),
    'GetSnapshotUri': (_, _) => snapUri1('http://10.0.0.5:80/cgi-bin/api.cgi?cmd=Snap&amp;channel=0'),
  },
);

/// TP-Link Tapo C210: ONVIF on :2020, rejects WS-Security (HTTP Digest only), no snapshot.
FakeOnvifCamera tapo() => FakeOnvifCamera(
  login: Login.httpDigestOnly,
  handlers: {
    'GetDeviceInformation': (_, _) => info('tp-link', 'C210'),
    'GetServices': (_, _) =>
        services('http://192.168.1.20:2020/onvif/device_service', media1: 'http://192.168.1.20:2020/onvif/service'),
    'GetProfiles': (p, _) => p == 'http://192.168.1.20:2020/onvif/service' || p == ':2020/onvif/service'
        ? profiles1([('profile_1', 'vsconf'), ('profile_2', 'vsconf')])
        : null,
    'GetStreamUri': (_, b) => streamUri1('rtsp://192.168.1.20:554/${token(b) == 'profile_1' ? 'stream1' : 'stream2'}'),
  },
);

/// Axis M3106-L Mk II (Profile T firmware): Media1 lists nothing, Media2 on /onvif/services.
FakeOnvifCamera axis() => FakeOnvifCamera(
  login: Login.wsSecurity,
  handlers: {
    'GetDeviceInformation': (_, _) => info('AXIS', 'M3106-L Mk II'),
    'GetServices': (_, _) => services(
      'http://192.168.1.90/onvif/device_service',
      media1: 'http://192.168.1.90/onvif/services',
      media2: 'http://192.168.1.90/onvif/services',
    ),
    'GetProfiles': (_, _) => emptyProfiles,
    'tr2:GetProfiles': (_, _) => profiles2([('profile_1_h264', '0'), ('profile_1_jpeg', '0')]),
    'tr2:GetStreamUri': (_, b) =>
        streamUri2('rtsp://192.168.1.90/onvif-media/media.amp?profile=${token(b)}&amp;sessiontimeout=60'),
    'tr2:GetSnapshotUri': (_, _) => soap(
      '<tr2:GetSnapshotUriResponse><tr2:Uri>http://192.168.1.90/onvif-cgi/jpg/image.cgi?resolution=1280x720</tr2:Uri></tr2:GetSnapshotUriResponse>',
    ),
  },
);

/// Sonoff CAM Dual (GK-200MP2-B): two lenses = two video sources, main + sub each.
FakeOnvifCamera sonoffDual() => FakeOnvifCamera(
  login: Login.wsSecurity,
  handlers: {
    'GetDeviceInformation': (_, _) => info('SONOFF', 'GK-200MP2-B'),
    'GetCapabilities': (_, _) => capabilities('http://192.168.1.77:8899/onvif/device_service'),
    'GetProfiles': (_, _) => profiles1([
      ('PROFILE_000', 'VIDEOSOURCE_000'),
      ('PROFILE_001', 'VIDEOSOURCE_000'),
      ('PROFILE_010', 'VIDEOSOURCE_001'),
      ('PROFILE_011', 'VIDEOSOURCE_001'),
    ]),
    'GetStreamUri': (_, b) => streamUri1(switch (token(b)) {
      'PROFILE_000' => 'rtsp://192.168.1.77:554/av_stream/ch0',
      'PROFILE_001' => 'rtsp://192.168.1.77:554/av_stream/ch0_sub',
      'PROFILE_010' => 'rtsp://192.168.1.77:554/av_stream/ch1',
      _ => 'rtsp://192.168.1.77:554/av_stream/ch1_sub',
    }),
  },
);

/// Sonoff firmware that answers ONVIF but lists no profiles at all (the t153u case).
FakeOnvifCamera sonoffNoProfiles() => FakeOnvifCamera(
  login: Login.wsSecurity,
  handlers: {
    'GetDeviceInformation': (_, _) => info('SONOFF', 'GK-200MP2-B'),
    'GetProfiles': (_, _) => emptyProfiles,
    'tr2:GetProfiles': (_, _) => actionNotSupported,
  },
);
