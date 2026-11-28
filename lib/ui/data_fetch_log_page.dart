/// R584 (t327u): built-in log of data fetches (success and failure) on this device.
library;

import 'package:material_ui/material_ui.dart';

import '../log/event_log.dart';
import '../notify/data_fetch_host.dart';
import 'alarm_log_page.dart' show alarmLogTime;
import 'app_scope.dart';

class DataFetchLogPage extends StatefulWidget {
  const DataFetchLogPage({super.key});

  @override
  State<DataFetchLogPage> createState() => _DataFetchLogPageState();
}

class _DataFetchLogPageState extends State<DataFetchLogPage> {
  List<LogEvent> _events = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final ev = await loadDataFetchLog();
    if (mounted) setState(() { _events = ev; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Tietohaut', 'Data fetches'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tx(
                    context,
                    'Onnistuneet tietohaut merkitään tänne. Ilmoitus tulee vain, jos haku epäonnistuu toistuvasti.',
                    'Successful data fetches are listed here. A notification is sent only if a fetch keeps failing.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              key: const ValueKey('data-fetch-log'),
              itemCount: _events.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = _events[i];
                final ok = e.type.startsWith('ok');
                return ListTile(
                  key: ValueKey('data-fetch-${e.key}'),
                  leading: Icon(
                    ok ? Icons.check_circle_outline : Icons.error_outline,
                    color: ok ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
                  ),
                  title: Text(e.actor ?? e.type, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      ok ? tx(context, 'Onnistui', 'Succeeded') : tx(context, 'Epäonnistui', 'Failed'),
                      if (e.label != null && e.label!.isNotEmpty) e.label!,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(alarmLogTime(e.at, now)),
                );
              },
            ),
    );
  }
}
