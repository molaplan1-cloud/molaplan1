/// Security cameras: brand presets (Hikvision, Dahua/Imou, Reolink, TP-Link Tapo, Ezviz,
/// any ONVIF camera). Found with ONVIF WS-Discovery; snapshots over HTTP (Digest),
/// live video over RTSP on the home network. Away from home only snapshots travel
/// through the relay (end-to-end encrypted, size-limited).
library;

import 'dart:typed_data';

import '../drivers/camera_driver.dart';
import '../models/models.dart';
import '../l10n/l10n.dart';
import 'onvif.dart';
import 'provider.dart';
import 'rtsp_catalog.dart';
import 'rtsp_probe.dart';

class CameraPreset {
  const CameraPreset({
    required this.id,
    required this.name,
    required this.keywords,
    required this.loginHelpFi,
    required this.loginHelpEn,
    this.defaultUser = 'admin',
    this.auth = 'digest',
    this.snapshot,
    this.rtsp,
    this.rtspSub,
    this.onvifPath = '/onvif/device_service',
    this.useOnvif = false,
    this.setupFi = '',
    this.setupEn = '',
  });
  final String id;
  final String name;
  final List<String> keywords;
  final String defaultUser;
  final String auth;

  /// HTTP snapshot path (may use {{username}}/{{password}}); null = the brand has none.
  final String? snapshot;
  final String? rtsp;
  final String? rtspSub;
  final String onvifPath;

  /// Ask the camera itself (ONVIF) for the addresses.
  final bool useOnvif;
  final String loginHelpFi, loginHelpEn;

  /// Something to switch on in the brand's app first (shown before the search).
  final String setupFi, setupEn;
}

const cameraPresets = <CameraPreset>[
  CameraPreset(
    id: 'hikvision',
    name: 'Hikvision',
    keywords: ['hikvision', 'hik-connect', 'hikconnect', 'ds-2cd', 'annke'],
    snapshot: '/ISAPI/Streaming/channels/101/picture',
    rtsp: 'rtsp://{{host}}:554/Streaming/Channels/101',
    rtspSub: 'rtsp://{{host}}:554/Streaming/Channels/102',
    loginHelpFi: 'Kameran käyttäjä (yleensä admin) ja salasana, jonka asetit kameran aktivoinnissa.',
    loginHelpEn: 'The camera user (usually admin) and the password you set when activating it.',
  ),
  CameraPreset(
    id: 'dahua',
    name: 'Dahua / Imou / Amcrest',
    keywords: ['dahua', 'imou', 'amcrest', 'lorex', 'ipc-h'],
    snapshot: '/cgi-bin/snapshot.cgi?channel=1',
    rtsp: 'rtsp://{{host}}:554/cam/realmonitor?channel=1&subtype=0',
    rtspSub: 'rtsp://{{host}}:554/cam/realmonitor?channel=1&subtype=1',
    loginHelpFi: 'Käyttäjä admin. Imou: salasana on kameran tarrassa oleva "Safety code" tai laitesalasana.',
    loginHelpEn: 'User admin. Imou: the password is the "Safety code" on the camera label or the device password.',
  ),
  CameraPreset(
    id: 'reolink',
    name: 'Reolink',
    keywords: ['reolink', 'rlc-', 'e1 zoom', 'argus'],
    auth: 'none',
    snapshot: '/cgi-bin/api.cgi?cmd=Snap&channel=0&rs=molaplan&user={{username}}&password={{password}}',
    rtsp: 'rtsp://{{host}}:554/h264Preview_01_main',
    rtspSub: 'rtsp://{{host}}:554/h264Preview_01_sub',
    loginHelpFi: 'Reolink-sovelluksen kameran käyttäjä (yleensä admin) ja salasana.',
    loginHelpEn: 'The camera user in the Reolink app (usually admin) and its password.',
    setupFi: 'Reolink-sovellus → kamera → Asetukset → Verkko → Lisäasetukset → Palvelinasetukset: laita HTTP ja RTSP päälle. Akkukamerat (Argus) eivät tue tätä.',
    setupEn: 'Reolink app → camera → Settings → Network → Advanced → Server settings: turn on HTTP and RTSP. Battery cameras (Argus) are not supported.',
  ),
  CameraPreset(
    id: 'tapo',
    name: 'TP-Link Tapo',
    keywords: ['tapo', 'tp-link', 'tplink', 'c200', 'c210', 'c310', 'c320'],
    defaultUser: '',
    auth: 'none',
    rtsp: 'rtsp://{{host}}:554/stream1',
    rtspSub: 'rtsp://{{host}}:554/stream2',
    onvifPath: ':2020/onvif/device_service',
    loginHelpFi: 'Tapo-sovellus → kamera → Lisäasetukset → Kameran tili. Tee sinne käyttäjä ja salasana ja kirjoita ne tähän (ei Tapo-pilvitunnuksesi).',
    loginHelpEn: 'Tapo app → camera → Advanced settings → Camera account. Create a user and password there and type them here (not your Tapo cloud login).',
    setupFi: 'Tee ensin kameran tili: Tapo-sovellus → kamera → Lisäasetukset → Kameran tili.',
    setupEn: 'First create a camera account: Tapo app → camera → Advanced settings → Camera account.',
  ),
  CameraPreset(
    id: 'ezviz',
    name: 'Ezviz',
    keywords: ['ezviz', 'cs-c', 'c3w', 'c6n'],
    snapshot: '/ISAPI/Streaming/channels/101/picture',
    rtsp: 'rtsp://{{host}}:554/h264/ch1/main/av_stream',
    rtspSub: 'rtsp://{{host}}:554/h264/ch1/sub/av_stream',
    loginHelpFi: 'Käyttäjä admin, salasana on kameran tarrassa oleva 6-kirjaiminen vahvistuskoodi (Verification code).',
    loginHelpEn: 'User admin; the password is the 6-letter verification code on the camera label.',
    setupFi: 'Ezviz-sovellus → kamera → Asetukset → LAN Live View / RTSP: laita päälle (jos valinta on).',
    setupEn: 'Ezviz app → camera → Settings → LAN Live View / RTSP: turn it on (if the option exists).',
  ),
  CameraPreset(
    id: 'sonoff_cam',
    name: 'Sonoff',
    keywords: ['sonoff cam', 'cam slim', 'cam dual', 'gk-200', 'ewelink'],
    useOnvif: true,
    rtsp: 'rtsp://{{host}}:554/av_stream/ch0',
    loginHelpFi: 'eWeLink-sovelluksessa kameralle asetettu käyttäjä ja salasana (RTSP/ONVIF). Kaksilinssisessä mallissa molemmat linssit tulevat samasta laitteesta.',
    loginHelpEn: 'The user and password set for the camera in the eWeLink app (RTSP/ONVIF). On a dual-lens model both lenses come from the same device.',
    setupFi: 'eWeLink-sovellus → kamera → Asetukset: laita RTSP/ONVIF päälle ja aseta sille käyttäjä ja salasana (jos valinta on).',
    setupEn: 'eWeLink app → camera → Settings: turn on RTSP/ONVIF and set a user and password for it (if the option exists).',
  ),
  CameraPreset(
    id: 'onvif',
    name: 'ONVIF',
    keywords: ['onvif', 'ip-kamera', 'ip camera', 'axis', 'uniview', 'foscam', 'annke', 'vstarcam', 'amcrest', 'vigi'],
    useOnvif: true,
    loginHelpFi: 'Kameran käyttäjä ja salasana (usein admin). ONVIF pitää ehkä laittaa päälle kameran asetuksista.',
    loginHelpEn: 'The camera user and password (often admin). ONVIF may need to be enabled in the camera settings.',
  ),
];

CameraPreset? cameraPresetById(String id) => cameraPresets.where((p) => p.id == id).firstOrNull;

/// The "Valvontakamera" card: tapping it asks for the brand ([CameraProvider] per preset).
class CameraChooser extends DeviceProvider {
  @override
  String get id => 'camera';
  @override
  String get fi => 'Valvontakamera';
  @override
  String get en => 'Security camera';
  @override
  String get descFi =>
      'Hikvision, Dahua, Reolink, Tapo, Ezviz, Sonoff tai muu ONVIF/RTSP-kamera. Kuva ruutuun, live-video kotona.';
  @override
  String get descEn =>
      'Hikvision, Dahua, Reolink, Tapo, Ezviz, Sonoff or any ONVIF/RTSP camera. Picture on a tile, live video at home.';
  @override
  String get category => 'camera';
  @override
  List<String> get keywords => [
    'kamera',
    'camera',
    'valvonta',
    'cctv',
    'rtsp',
    for (final p in cameraPresets) ...p.keywords,
  ];
  @override
  PairMode get pairMode => PairMode.password;
  @override
  String get addressHelpFi => '';
  @override
  String get addressHelpEn => '';
  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) =>
      throw UnsupportedError('pick a brand first');
  @override
  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  }) => const [];
}

class CameraProvider extends DeviceProvider {
  CameraProvider(
    this.preset, {
    Future<int> Function(String url)? rtspCheck,
    Future<List<OnvifFound>> Function()? discover,
  }) : _rtspCheck = rtspCheck ?? rtspDescribe,
       _discover = discover ?? onvifDiscover;
  final CameraPreset preset;
  final Future<int> Function(String url) _rtspCheck;
  final Future<List<OnvifFound>> Function() _discover;

  @override
  String get id => 'camera_${preset.id}';
  @override
  String get fi => preset.id == 'onvif' ? 'Muu kamera (ONVIF)' : '${preset.name} -kamera';
  @override
  String get en => preset.id == 'onvif' ? 'Other camera (ONVIF)' : '${preset.name} camera';
  @override
  String get descFi => preset.setupFi.isNotEmpty ? preset.setupFi : 'Kuva ruutuun, live-video kotiverkossa.';
  @override
  String get descEn => preset.setupEn.isNotEmpty ? preset.setupEn : 'Picture on a tile, live video at home.';
  @override
  String get category => 'camera';
  @override
  List<String> get keywords => preset.keywords;
  @override
  PairMode get pairMode => PairMode.password;
  @override
  String get addressHint => '192.168.x.x';
  @override
  String get addressHelpFi => 'Kameran sovelluksesta (laitetiedot) tai reitittimen laitelistasta.';
  @override
  String get addressHelpEn => 'In the camera app (device info) or your router\'s device list.';
  @override
  String get pairHelpFi => preset.loginHelpFi;
  @override
  String get pairHelpEn => preset.loginHelpEn;
  @override
  List<CredField> get credFields => [
    CredField(
      'username',
      'Käyttäjätunnus',
      'Username',
      hint: preset.defaultUser.isEmpty ? '' : preset.defaultUser,
      optional: preset.defaultUser.isNotEmpty,
    ),
  ];

  @override
  Future<List<Candidate>> scan(List<String> locals) async => [
    for (final f in await _discover())
      if (preset.id == 'onvif' || f.brand.isEmpty || f.brand == preset.id)
        Candidate(
          provider: id,
          address: f.host,
          id: preset.useOnvif && f.port != 80 ? ':${f.port}${Uri.parse(f.xaddr).path}' : '',
          model: f.hardware,
          name: f.name.isEmpty ? null : f.name,
        ),
  ];

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    final host = hostOf(c.address);
    final user = (creds['username'] ?? '').trim().isEmpty ? preset.defaultUser : creds['username']!.trim();
    final pw = creds['password'] ?? '';
    if (pw.isEmpty || user.isEmpty) throw AddDeviceError(AddProblem.needsPassword);
    final base = httpBase(c.address.contains(':') && !preset.useOnvif ? c.address : host);
    var settings = <String, dynamic>{
      'baseUrl': base,
      'auth': preset.auth,
      'username': user,
      'brand': preset.id,
      'rtsp': ?preset.rtsp,
      'rtspSub': ?preset.rtspSub,
    };
    ConnectionConfig conn(Map<String, dynamic> s) => ConnectionConfig(
      name: c.name?.isNotEmpty == true ? c.name! : '${preset.name} ${tr(ctx.lang, 'kamera', 'camera')}',
      type: 'camera',
      settings: s,
      secrets: {'password': pw},
    );
    var snapshot = preset.snapshot;
    var model = c.model;
    var streams = <Map<String, dynamic>>[];
    final notes = <String>[];
    var notOnvif = false;

    /// Address typed by hand (offered when nothing else worked): used as is.
    final manual = (creds['rtsp'] ?? '').trim();
    if (manual.isNotEmpty) {
      final u = Uri.tryParse(manual.contains('://') ? manual : 'rtsp://$host$manual');
      if (u == null || u.scheme != 'rtsp') throw AddDeviceError(AddProblem.cameraNoStream, 'bad RTSP address: $manual');
      settings = {...settings, 'rtsp': rtspTemplate(u.toString(), host)}..remove('rtspSub');
      snapshot = null;
    } else if (preset.useOnvif) {
      final d = ctx.driver(conn({...settings, 'auth': 'digest'}));
      try {
        final m = await onvifMedia(
          (path, body) async => '${await d.send({'path': path, 'body': body})}',
          devicePath: c.id.isNotEmpty ? c.id : preset.onvifPath,
          user: user,
          password: pw,
          host: host,
        );
        settings = {
          ...settings,
          'auth': 'digest',
          'rtsp': ?rtspTemplate(m.rtsp, host),
          'rtspSub': ?rtspTemplate(m.rtspSub, host),
        };
        streams = [
          for (final st in m.streams)
            {
              'rtsp': ?rtspTemplate(st.rtsp, host),
              'rtspSub': ?rtspTemplate(st.rtspSub, host),
              'snapshot': ?_relative(st.snapshot, host),
            },
        ];
        snapshot = _relative(m.snapshot, host);
        if (m.model.isNotEmpty) model = m.model;
      } on OnvifAuthError {
        throw AddDeviceError(AddProblem.wrongPassword, 'ONVIF: login refused (WS-Security and HTTP Digest)');
      } on OnvifNeedsLogin {
        throw AddDeviceError(AddProblem.needsPassword, 'ONVIF: login required');
      } on OnvifNoProfiles catch (e) {
        if (e.model.isNotEmpty) model = e.model;
        notes.add('$e');
      } on OnvifNotFound catch (e) {
        notOnvif = true;
        notes.add('$e');
      } catch (e) {
        final p = explain(e, havePassword: true);
        if (p.problem == AddProblem.unreachable ||
            p.problem == AddProblem.bridgeOffline ||
            p.problem == AddProblem.wrongPassword) {
          throw p;
        }
        notes.add('ONVIF: $e');
      } finally {
        await d.dispose();
      }
      if (streams.isEmpty) {
        // t153u: ONVIF said nothing useful – look for the stream like a person would, with the
        // usual addresses of every big brand (Sonoff first for a Sonoff, and so on).
        final found = await _probe(c, host, user, pw, '$model ${c.model} ${c.name ?? ''}', notes, notOnvif: notOnvif);
        settings = {...settings, ...found.$1};
        streams = found.$2;
        snapshot = null;
      }
    }

    // Check the login: a snapshot when the brand has one, else one RTSP DESCRIBE (on the LAN).
    if (snapshot != null) {
      final d = ctx.driver(conn(settings));
      try {
        final img = await (d as CameraDriver).snapshot(snapshot);
        if (!_isJpeg(img)) {
          final t = String.fromCharCodes(img.take(400));
          if (t.contains('login') || t.contains('-6') || t.toLowerCase().contains('unauthorized')) {
            throw AddDeviceError(AddProblem.wrongPassword, t);
          }
          snapshot = null; // answered but not a picture: live video only
        }
      } catch (e) {
        if (e is AddDeviceError) rethrow;
        final p = explain(e, havePassword: true);
        if (p.problem == AddProblem.wrongPassword ||
            p.problem == AddProblem.unreachable ||
            p.problem == AddProblem.bridgeOffline) {
          throw p;
        }
        snapshot = null; // e.g. ISAPI off on an Ezviz: RTSP still works
      } finally {
        await d.dispose();
      }
    }
    if (snapshot == null) {
      final url = cameraRtspUrl({...settings, 'password': pw});
      if (url == null) throw AddDeviceError(AddProblem.cameraNoStream, 'no RTSP or snapshot');
      if (!c.viaBridge) {
        int code;
        try {
          code = await _rtspCheck(url);
        } catch (e) {
          throw explain(e, havePassword: true);
        }
        if (code == 401) throw AddDeviceError(AddProblem.wrongPassword, 'RTSP 401');
        if (code != 200 && manual.isNotEmpty) {
          throw AddDeviceError(AddProblem.cameraNoStream, 'RTSP $code: ${rtspTemplate(url, host)}');
        }
        if (code == 404) {
          // The brand's usual address is not it: try the other brands' addresses before giving up.
          final found = await _probe(c, host, user, pw, '${preset.id} $model', [
            'RTSP 404: ${preset.rtsp}',
          ], notOnvif: false);
          settings = {...settings, ...found.$1};
          streams = found.$2;
        }
      }
    }
    if (streams.length > 1) settings = {...settings, 'streams': streams};
    final connection = conn(settings);
    final title = c.name?.isNotEmpty == true ? c.name! : tr(ctx.lang, 'Kamera', 'Camera');
    final n = streams.length > 1 ? streams.length : 1;
    return Connected(
      connection: connection,
      label: model.isNotEmpty ? model : preset.name,
      items: [
        for (var i = 0; i < n; i++)
          AddItem(
            key: i == 0 ? 'cam' : 'cam${i + 1}',
            name: n == 1 ? title : '$title ${i + 1}',
            kind: 'camera',
            subtitle: [
              if (n > 1)
                tr(
                  ctx.lang,
                  'Kuvavirta ${i + 1}/$n (oma linssi tai kanava)',
                  'Stream ${i + 1}/$n (own lens or channel)',
                ),
              (i == 0 ? snapshot : streams.elementAtOrNull(i)?['snapshot']) != null
                  ? tr(ctx.lang, 'Kuva ruutuun, live-video kotiverkossa', 'Picture on the tile, live video at home')
                  : tr(ctx.lang, 'Live-video kotiverkossa (ei kuvaa etänä)', 'Live video at home (no picture away)'),
            ].join(' · '),
          ),
      ],
      data: {'snapshot': ?snapshot, 'streams': n},
    );
  }

  /// RTSP search over [rtspPatterns]; returns the settings to merge and the stream list.
  Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> _probe(
    Candidate c,
    String host,
    String user,
    String pw,
    String hintText,
    List<String> notes, {
    required bool notOnvif,
  }) async {
    if (c.viaBridge) {
      // DESCRIBE runs on this device; via the bridge only the typed address can be used.
      throw AddDeviceError(AddProblem.cameraNoStream, [...notes, 'RTSP search needs the home network'].join('\n'));
    }
    final brand = rtspBrandHint(hintText).isNotEmpty ? rtspBrandHint(hintText) : _presetBrand(preset.id);
    final r = await probeRtsp(host, user: user, password: pw, check: _rtspCheck, brand: brand);
    final detail = [...notes, ...r.tried].join('\n');
    if (r.streams.isEmpty) {
      if (r.authFailed) throw AddDeviceError(AddProblem.wrongPassword, detail);
      // Not ONVIF and no RTSP port at all: really something else at this address.
      final noRtsp = r.tried.isNotEmpty && r.tried.every((t) => !t.contains('RTSP '));
      if (notOnvif && noRtsp) throw AddDeviceError(AddProblem.notThisBrand, detail);
      throw AddDeviceError(AddProblem.cameraNoStream, detail);
    }
    final f = r.streams.first;
    return (
      <String, dynamic>{'rtsp': f.rtsp, 'rtspSub': f.rtspSub, 'rtspFound': ?r.pattern?.name},
      [
        for (final st in r.streams) {'rtsp': st.rtsp, 'rtspSub': ?st.rtspSub},
      ],
    );
  }

  @override
  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  }) {
    final snap = r.data['snapshot'] as String?;
    final n = (r.data['streams'] as int?) ?? 1;
    final streams = (r.connection.settings['streams'] as List?) ?? const [];
    return [
      for (var i = 0; i < n; i++)
        if (!skip.contains(i == 0 ? 'cam' : 'cam${i + 1}'))
          _tile(r, i, names[i == 0 ? 'cam' : 'cam${i + 1}'], i == 0 ? snap : _snapOf(streams, i)),
    ];
  }

  static String? _snapOf(List streams, int i) {
    final e = streams.elementAtOrNull(i);
    return e is Map ? e['snapshot'] as String? : null;
  }

  TileConfig _tile(Connected r, int i, String? name, String? snap) {
    final key = i == 0 ? 'cam' : 'cam${i + 1}';
    final item = r.items.where((x) => x.key == key).firstOrNull;
    final title = name?.trim().isNotEmpty == true ? name!.trim() : (item?.name ?? r.items.first.name);
    return TileConfig(
      type: TileType.camera,
      title: title,
      colSpan: 2,
      rowSpan: 2,
      connectionId: r.connection.id,
      read: {
        if (snap != null) ...{'mode': 'snapshot', 'path': snap, 'refreshSeconds': 2} else 'mode': 'rtsp',
        if (i > 0) 'stream': i,
      },
    );
  }
}

/// Preset id → [rtspPatterns] brand.
String _presetBrand(String id) => switch (id) {
  'sonoff_cam' => 'sonoff',
  'onvif' => '',
  _ => id,
};

bool _isJpeg(Uint8List b) => b.length > 3 && b[0] == 0xFF && b[1] == 0xD8;

/// http://192.168.1.70:8080/snap.jpg -> :8080/snap.jpg (keeps working when the IP changes).
String? _relative(String? url, String host) {
  if (url == null) return null;
  final u = Uri.tryParse(url);
  if (u == null || u.host != host) return url;
  final q = u.hasQuery ? '?${u.query}' : '';
  return u.hasPort && u.port != 80 ? ':${u.port}${u.path}$q' : '${u.path}$q';
}

/// All camera providers (one per brand), used by the chooser and the bridge's discovery.
final cameraProviders = [for (final p in cameraPresets) CameraProvider(p)];
