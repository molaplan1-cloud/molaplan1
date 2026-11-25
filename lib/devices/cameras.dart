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
    id: 'onvif',
    name: 'ONVIF',
    keywords: ['onvif', 'ip-kamera', 'ip camera', 'axis', 'uniview', 'foscam', 'annke', 'vstarcam'],
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
  String get descFi => 'Hikvision, Dahua, Reolink, Tapo, Ezviz tai muu ONVIF-kamera. Kuva ruutuun, live-video kotona.';
  @override
  String get descEn =>
      'Hikvision, Dahua, Reolink, Tapo, Ezviz or any ONVIF camera. Picture on a tile, live video at home.';
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
  String get addressHint => '192.168.1.70';
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

    if (preset.useOnvif) {
      final d = ctx.driver(conn({...settings, 'auth': 'digest'}));
      try {
        final m = await onvifMedia(
          (path, body) async => '${await d.send({'path': path, 'body': body})}',
          devicePath: c.id.isNotEmpty ? c.id : preset.onvifPath,
          user: user,
          password: pw,
        );
        settings = {
          ...settings,
          'auth': 'digest',
          'rtsp': ?rtspTemplate(m.rtsp, host),
          'rtspSub': ?rtspTemplate(m.rtspSub, host),
        };
        snapshot = _relative(m.snapshot, host);
        if (m.model.isNotEmpty) model = m.model;
      } on OnvifAuthError {
        throw AddDeviceError(AddProblem.wrongPassword, 'ONVIF');
      } catch (e) {
        throw explain(e, havePassword: true);
      } finally {
        await d.dispose();
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
      if (url == null) throw AddDeviceError(AddProblem.nothingToAdd, 'no RTSP or snapshot');
      if (!c.viaBridge) {
        try {
          final code = await _rtspCheck(url);
          if (code == 401) throw AddDeviceError(AddProblem.wrongPassword, 'RTSP 401');
          if (code == 404) throw AddDeviceError(AddProblem.notThisBrand, 'RTSP 404');
        } catch (e) {
          throw explain(e, havePassword: true);
        }
      }
    }
    final connection = conn(settings);
    final title = c.name?.isNotEmpty == true ? c.name! : tr(ctx.lang, 'Kamera', 'Camera');
    return Connected(
      connection: connection,
      label: model.isNotEmpty ? model : preset.name,
      items: [
        AddItem(
          key: 'cam',
          name: title,
          kind: 'camera',
          subtitle: snapshot != null
              ? tr(ctx.lang, 'Kuva ruutuun, live-video kotiverkossa', 'Picture on the tile, live video at home')
              : tr(ctx.lang, 'Live-video kotiverkossa (ei kuvaa etänä)', 'Live video at home (no picture away)'),
        ),
      ],
      data: {'snapshot': ?snapshot},
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
    if (skip.contains('cam')) return const [];
    final snap = r.data['snapshot'] as String?;
    final title = names['cam']?.trim().isNotEmpty == true ? names['cam']!.trim() : r.items.first.name;
    return [
      TileConfig(
        type: TileType.camera,
        title: title,
        colSpan: 2,
        rowSpan: 2,
        connectionId: r.connection.id,
        read: snap != null ? {'mode': 'snapshot', 'path': snap, 'refreshSeconds': 2} : {'mode': 'rtsp'},
      ),
    ];
  }
}

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
