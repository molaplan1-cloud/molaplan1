/// R471 (t311u): "Loki" for a security status tile – armed / disarmed (who) and alarms
/// (start, end, duration), newest first. Backfilled from the server's history on open.
library;

import 'package:material_ui/material_ui.dart';

import '../core/security_state.dart';
import '../log/event_log.dart';
import '../models/models.dart';
import '../security/alarm_log.dart';
import 'app_scope.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String alarmLogTime(DateTime t, DateTime now) {
  final hm = '${_two(t.hour)}:${_two(t.minute)}';
  final same = t.year == now.year && t.month == now.month && t.day == now.day;
  return same ? hm : '${t.day}.${t.month}. $hm';
}

String alarmLogDuration(Duration d) {
  if (d.inMinutes < 1) return '${d.inSeconds} s';
  if (d.inHours < 1) return '${d.inMinutes} min';
  return '${d.inHours} h ${d.inMinutes % 60} min';
}

class AlarmLogPage extends StatefulWidget {
  const AlarmLogPage({super.key, required this.tile});
  final TileConfig tile;

  @override
  State<AlarmLogPage> createState() => _AlarmLogPageState();
}

class _AlarmLogPageState extends State<AlarmLogPage> {
  List<LogEvent>? _log;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final st = AppScope.read(context);
    final c = st.connection(widget.tile.connectionId);
    if (c == null) {
      setState(() {
        _log = const [];
        _loading = false;
      });
      return;
    }
    final first = await AlarmLogStore.load(c.id);
    if (!mounted) return;
    setState(() => _log = first);
    final fresh = await refreshAlarmLog(c);
    if (!mounted) return;
    setState(() {
      _log = fresh;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final log = _log;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tile.title} – ${tx(context, 'Loki', 'Log')}'),
        actions: [
          IconButton(
            tooltip: tx(context, 'Päivitä', 'Refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _loading
                ? null
                : () {
                    setState(() => _loading = true);
                    _load();
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: log == null
                ? const SizedBox.shrink()
                : log.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        tx(
                          context,
                          'Ei tapahtumia vielä. Loki kerää valvonnan kytkennät ja hälytykset.',
                          'No events yet. The log collects arming, disarming and alarms.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    key: const ValueKey('alarm-log'),
                    itemCount: log.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = log[i];
                      final (icon, color, title) = switch (e.type) {
                        AlarmLogKind.armed => (
                          Icons.shield,
                          Color(securityColor(SecurityState.armed)),
                          tx(context, 'Valvonta päälle', 'Monitoring on'),
                        ),
                        AlarmLogKind.disarmed => (
                          Icons.shield_outlined,
                          Color(securityColor(SecurityState.disarmed)),
                          tx(context, 'Valvonta pois', 'Monitoring off'),
                        ),
                        _ => (
                          Icons.warning_rounded,
                          Color(securityColor(SecurityState.triggered)),
                          tx(context, 'HÄLYTYS', 'ALARM'),
                        ),
                      };
                      final parts = <String>[
                        if (e.type == AlarmLogKind.alarm && e.until != null)
                          '${tx(context, 'Päättyi', 'Ended')} ${alarmLogTime(e.until!, now)} (${alarmLogDuration(e.until!.difference(e.at))})',
                        if (e.type == AlarmLogKind.alarm && e.until == null)
                          tx(
                            context,
                            'Käynnissä tai päättymisaika ei tiedossa',
                            'Ongoing or end time unknown',
                          ),
                        if (e.label != null)
                          '${tx(context, 'Syy', 'Cause')}: ${e.label}',
                        if (e.actor != null)
                          '${tx(context, 'Kuka', 'Who')}: ${e.actor}',
                      ];
                      return ListTile(
                        key: ValueKey('alarm-log-${e.key}'),
                        leading: Icon(icon, color: color),
                        title: Text(
                          title,
                          style: TextStyle(
                            color: e.type == AlarmLogKind.alarm ? color : null,
                            fontWeight: e.type == AlarmLogKind.alarm
                                ? FontWeight.w700
                                : null,
                          ),
                        ),
                        subtitle: parts.isEmpty
                            ? null
                            : Text(parts.join(' · ')),
                        trailing: Text(alarmLogTime(e.at, now)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
