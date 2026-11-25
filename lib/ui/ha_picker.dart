import 'package:material_ui/material_ui.dart';

import '../drivers/ha_catalog.dart';
import '../models/models.dart';
import '../templates/device_templates.dart';
import 'app_scope.dart';

String haDomainLabel(BuildContext context, String d) => switch (d) {
  'light' => tx(context, 'Valot', 'Lights'),
  'switch' => tx(context, 'Kytkimet', 'Switches'),
  'climate' => tx(context, 'Lämpöpumput ja ilmastointi', 'Heat pumps and AC'),
  'sensor' => tx(context, 'Anturit', 'Sensors'),
  'binary_sensor' => tx(context, 'Tila-anturit', 'Binary sensors'),
  'cover' => tx(context, 'Verhot ja ovet', 'Covers and doors'),
  'lock' => tx(context, 'Lukot', 'Locks'),
  'alarm_control_panel' => tx(context, 'Hälytys', 'Alarm'),
  'camera' => tx(context, 'Kamerat', 'Cameras'),
  'fan' => tx(context, 'Puhaltimet', 'Fans'),
  'scene' => tx(context, 'Tilannekuvat', 'Scenes'),
  'script' => tx(context, 'Skriptit', 'Scripts'),
  'button' => tx(context, 'Painikkeet', 'Buttons'),
  'number' || 'input_number' => tx(context, 'Säätimet', 'Number inputs'),
  'input_boolean' => tx(context, 'Apukytkimet', 'Helper toggles'),
  'automation' => tx(context, 'Automaatiot', 'Automations'),
  'media_player' => tx(context, 'Mediasoittimet', 'Media players'),
  _ => d,
};

/// Pick Home Assistant entities -> tiles. Searchable, filter by room and type, suggestions first.
/// Never imports everything; can be reopened later (Settings → Home Assistant).
class HaEntityPickerPage extends StatefulWidget {
  const HaEntityPickerPage({super.key, required this.connection, this.dashboard, this.loader});
  final ConnectionConfig connection;
  final Dashboard? dashboard;
  final Future<HaCatalog> Function()? loader;

  @override
  State<HaEntityPickerPage> createState() => _HaEntityPickerPageState();
}

class _HaEntityPickerPageState extends State<HaEntityPickerPage> {
  HaCatalog? cat;
  String? error;
  String query = '';
  String? area; // null = all rooms, '' = no room
  String? domain;
  bool showAll = false;
  bool byRoom = true;
  final selected = <String>{};
  bool adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      error = null;
      cat = null;
    });
    final c = widget.connection;
    try {
      final r =
          await (widget.loader?.call() ??
              fetchHaCatalog(
                '${c.settings['baseUrl'] ?? ''}',
                c.secrets['token'] ?? '',
                allowSelfSigned: c.settings['allowSelfSigned'] == true,
              ));
      if (mounted) setState(() => cat = r);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = '$e' == '401'
            ? tx(
                context,
                'Tunnus (token) ei kelpaa. Luo uusi Home Assistantissa.',
                'The token is not accepted. Create a new one in Home Assistant.',
              )
            : tx(
                context,
                'Home Assistantiin ei saatu yhteyttä. Tarkista osoite.',
                'Could not reach Home Assistant. Check the address.',
              ),
      );
    }
  }

  Set<String> _existing() {
    final st = AppScope.read(context);
    return {
      for (final d in st.config.dashboards)
        for (final t in d.tiles)
          if (t.connectionId == widget.connection.id && t.read['entityId'] != null) '${t.read['entityId']}',
    };
  }

  Future<void> _add() async {
    final st = AppScope.read(context);
    final c = cat!;
    final lang = st.lang;
    setState(() => adding = true);
    final picked = c.entities.where((e) => selected.contains(e.entityId)).toList();
    final cam = picked.any((e) => e.domain == 'camera')
        ? ConnectionConfig(
            name: 'Home Assistant – ${tx(context, 'kamerat', 'cameras')}',
            type: 'camera',
            settings: {'baseUrl': widget.connection.settings['baseUrl'], 'auth': 'bearer'},
            secrets: {'token': widget.connection.secrets['token'] ?? ''},
          )
        : null;
    final groups = <String?, List<HaEntity>>{};
    for (final e in picked) {
      groups.putIfAbsent(byRoom ? e.areaName : null, () => []).add(e);
    }
    var count = 0;
    for (final g in groups.entries) {
      Dashboard? d = widget.dashboard;
      if (g.key != null) {
        d = st.config.dashboards.where((x) => x.name.toLowerCase() == g.key!.toLowerCase()).firstOrNull;
        if (d == null) {
          final only = st.config.dashboards.length == 1 && st.config.dashboards.first.tiles.isEmpty;
          if (only) {
            // The empty default view becomes the first room.
            d = st.config.dashboards.first;
            await st.renameDashboard(d, g.key!);
          } else {
            d = await st.addDashboard(g.key!);
          }
        }
      }
      final tiles = [for (final e in g.value) ...haTilesFor(e, widget.connection.id, lang, cameraConnId: cam?.id)];
      count += tiles.length;
      await st.applyTemplate(TemplateResult([?cam], tiles), into: d);
    }
    if (!mounted) return;
    showSnack(context, tx(context, '$count ruutua lisätty', '$count tiles added'));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = cat;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Valitse Home Assistantin laitteet', 'Pick Home Assistant devices'))),
      body: error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: Text(tx(context, 'Yritä uudelleen', 'Try again'))),
                  ],
                ),
              ),
            )
          : c == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(tx(context, 'Haetaan laitteita…', 'Loading devices…')),
                ],
              ),
            )
          : _list(context, c, text),
      bottomNavigationBar: c == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (c.areas.isNotEmpty)
                      Flexible(
                        child: CheckboxListTile(
                          key: const ValueKey('ha-by-room'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          value: byRoom,
                          onChanged: (v) => setState(() => byRoom = v == true),
                          title: Text(tx(context, 'Huoneittain omiin näkymiin', 'One view per room')),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const ValueKey('ha-add'),
                      onPressed: selected.isEmpty || adding ? null : _add,
                      icon: const Icon(Icons.add),
                      label: Text(tx(context, 'Lisää ${selected.length}', 'Add ${selected.length}')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _list(BuildContext context, HaCatalog c, TextTheme text) {
    final existing = _existing();
    final items = c.filter(query: query, area: area, domain: domain, showAll: showAll);
    final hiddenCount = showAll ? 0 : c.entities.where((e) => e.technical).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            key: const ValueKey('ha-search'),
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tx(context, 'Hae nimellä tai tunnuksella', 'Search by name or id'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              if (c.areas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: DropdownButton<String?>(
                    key: const ValueKey('ha-area'),
                    value: area,
                    hint: Text(tx(context, 'Kaikki huoneet', 'All rooms')),
                    items: [
                      DropdownMenuItem(value: null, child: Text(tx(context, 'Kaikki huoneet', 'All rooms'))),
                      for (final a in c.areas) DropdownMenuItem(value: a.id, child: Text(a.name)),
                      DropdownMenuItem(value: '', child: Text(tx(context, 'Ei huonetta', 'No room'))),
                    ],
                    onChanged: (v) => setState(() => area = v),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(tx(context, 'Kaikki', 'All')),
                  selected: domain == null,
                  onSelected: (_) => setState(() => domain = null),
                ),
              ),
              for (final d in c.domains)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    key: ValueKey('ha-domain-$d'),
                    label: Text(haDomainLabel(context, d)),
                    selected: domain == d,
                    onSelected: (_) => setState(() => domain = domain == d ? null : d),
                  ),
                ),
            ],
          ),
        ),
        SwitchListTile(
          key: const ValueKey('ha-show-all'),
          dense: true,
          value: showAll,
          onChanged: (v) => setState(() => showAll = v),
          title: Text(tx(context, 'Näytä kaikki', 'Show all')),
          subtitle: hiddenCount == 0
              ? null
              : Text(
                  tx(
                    context,
                    '$hiddenCount teknistä kohdetta piilotettu (diagnostiikka, asetukset, päivitykset)',
                    '$hiddenCount technical items hidden (diagnostics, configuration, updates)',
                  ),
                ),
        ),
        if (!c.registryOk)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              tx(
                context,
                'Huoneita ei saatu luettua – näytetään laitteet ilman huoneita.',
                'Rooms could not be read – showing devices without rooms.',
              ),
              style: text.bodySmall,
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(tx(context, 'Ei osumia', 'No matches')))
              : ListView.builder(
                  key: const ValueKey('ha-list'),
                  itemCount: items.length,
                  itemExtent: 64,
                  itemBuilder: (context, i) {
                    final e = items[i];
                    final added = existing.contains(e.entityId);
                    final state = e.state.isEmpty ? '' : ' · ${e.state}${e.unit.isEmpty ? '' : ' ${e.unit}'}';
                    return CheckboxListTile(
                      key: ValueKey('ha-${e.entityId}'),
                      value: added || selected.contains(e.entityId),
                      onChanged: added
                          ? null
                          : (v) => setState(() => v == true ? selected.add(e.entityId) : selected.remove(e.entityId)),
                      title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        added
                            ? '${e.entityId} · ${tx(context, 'jo lisätty', 'already added')}'
                            : '${e.entityId}${e.areaName == null ? '' : ' · ${e.areaName}'}$state',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
