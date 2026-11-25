/// v0.7.0 (t126u): the virtual connection behind group, scene and script tiles.
///
/// Group tile:  toggle, read {'kind': 'group', 'members': [tileIds]} → number of members on;
///              on/off commands {'kind': 'group', 'members': [...], 'op': 'on'|'off'}.
/// Scene tile:  button, command {'kind': 'scene', 'sceneId': id}.
/// Script tile: button, command {'kind': 'script', 'scriptId': id}.
library;

import '../core/template.dart';
import '../drivers/driver.dart';
import '../models/models.dart';
import 'app_state.dart';

const autoConnId = '_auto';

class AutoDriver extends Driver {
  AutoDriver(this.app) : super(ConnectionConfig(id: autoConnId, name: 'Molaplan', type: 'auto'));
  final AppState app;

  TileConfig? _tile(String id) {
    for (final d in app.config.dashboards) {
      for (final t in d.tiles) {
        if (t.id == id) return t;
      }
    }
    return null;
  }

  List<String> _members(Map<String, dynamic> spec) => [for (final m in (spec['members'] as List? ?? const [])) '$m'];

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    if (spec['kind'] != 'group') return null;
    var on = 0, ok = 0;
    for (final id in _members(spec)) {
      final t = _tile(id);
      final d = t == null ? null : app.driverFor(t.connectionId);
      if (t == null || d == null || t.read.isEmpty) continue;
      try {
        final v = await d.read(t.read);
        ok++;
        if (t.type == TileType.slider
            ? ((v is num ? v : num.tryParse('$v') ?? 0) > 0)
            : isTruthy(v, onValue: t.onValue)) {
          on++;
        }
      } catch (_) {}
    }
    if (ok == 0 && _members(spec).isNotEmpty) {
      throw DriverException(dtx('Ryhmän laitteet eivät vastaa', 'The group\'s devices are not answering'));
    }
    return on;
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    switch (spec['kind']) {
      case 'group':
        final on = '${spec['op'] ?? 'on'}' == 'on';
        final errors = <String>[];
        final ids = _members(spec);
        await Future.wait([
          for (final id in ids)
            () async {
              final t = _tile(id);
              if (t == null) return;
              final step = on ? t.onCommand : t.offCommand;
              try {
                if (step != null) {
                  await app.runStep(step, value: on ? 1 : 0);
                } else if (t.type == TileType.slider && t.commands.isNotEmpty) {
                  await app.runSequence(t.commands, value: on ? t.max : t.min);
                }
              } catch (e) {
                errors.add('${t.title}: $e');
              }
            }(),
        ]);
        if (errors.isNotEmpty && errors.length >= ids.length) throw DriverException(errors.join('; '));
        return null;
      case 'scene':
        await app.automations.runScene('${spec['sceneId']}');
        return null;
      case 'script':
        return app.automations.runScript('${spec['scriptId']}');
      case 'automation':
        return app.automations.runAutomation('${spec['automationId']}');
    }
    return null;
  }

  @override
  Future<String> test() async => 'ok';
}

/// A group tile switching [members] together ("Kaikki olohuoneen valot").
TileConfig groupTile(String title, List<String> members, {String icon = 'group'}) => TileConfig(
  type: TileType.toggle,
  title: title,
  icon: icon,
  connectionId: autoConnId,
  read: {'kind': 'group', 'members': members},
  pollSeconds: 10,
  onCommand: CommandStep(connectionId: autoConnId, spec: {'kind': 'group', 'members': members, 'op': 'on'}),
  offCommand: CommandStep(connectionId: autoConnId, spec: {'kind': 'group', 'members': members, 'op': 'off'}),
);

/// A button tile that runs a scene or a script.
TileConfig runTile(String title, String kind, String id, {String icon = 'scene'}) => TileConfig(
  type: TileType.button,
  title: title,
  icon: icon,
  pollSeconds: 0,
  read: {'kind': kind, '${kind}Id': id},
  commands: [
    CommandStep(connectionId: autoConnId, spec: {'kind': kind, '${kind}Id': id}),
  ],
);
