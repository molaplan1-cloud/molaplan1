/// Basics and advanced fields for a domestic-hot-water (Käyttövesi) program.
library;

import 'package:material_ui/material_ui.dart';

import '../energy/smart_heating.dart';
import 'app_scope.dart';
import 'smart_heating_pages.dart';

String _weekdayName(BuildContext context, int d) => switch (d) {
  1 => tx(context, 'maanantai', 'Monday'),
  2 => tx(context, 'tiistai', 'Tuesday'),
  3 => tx(context, 'keskiviikko', 'Wednesday'),
  4 => tx(context, 'torstai', 'Thursday'),
  5 => tx(context, 'perjantai', 'Friday'),
  6 => tx(context, 'lauantai', 'Saturday'),
  _ => tx(context, 'sunnuntai', 'Sunday'),
};

String _clock(int h) => '${h.toString().padLeft(2, '0')}:00';

/// Target, minimum, heating window and ready-by – the settings everyone sees.
class HeatDhwBasics extends StatelessWidget {
  const HeatDhwBasics({super.key, required this.load, required this.onChanged});
  final HeatLoad load;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = load;
    final text = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('dhw-basics'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(tx(context, 'Käyttövesi', 'Domestic hot water'), style: text.titleSmall),
        HeatNumRow(
          key: const ValueKey('dhw-target'),
          label: tx(context, 'Tavoitelämpötila', 'Target temperature'),
          value: l.dhwTargetOr,
          min: 40,
          max: 80,
          step: 1,
          unit: '°C',
          onChanged: (v) {
            l.waterTarget = v;
            onChanged();
          },
        ),
        HeatNumRow(
          key: const ValueKey('dhw-min'),
          label: tx(context, 'Vähimmäislämpötila', 'Minimum temperature'),
          value: l.dhwMinOr,
          min: 30,
          max: 70,
          step: 1,
          unit: '°C',
          onChanged: (v) {
            l.waterMin = v;
            onChanged();
          },
        ),
        SwitchListTile(
          key: const ValueKey('dhw-window'),
          contentPadding: EdgeInsets.zero,
          title: Text(tx(context, 'Lämmitä vain aikaikkunassa', 'Heat only in a time window')),
          subtitle: Text(
            l.windowStart == null
                ? tx(
                    context,
                    'Esimerkiksi 22–07. Muuten koko vuorokausi.',
                    'For example 22–07. Otherwise the whole day.',
                  )
                : tx(
                    context,
                    'Ikkuna ${_clock(l.windowStart!)}–${_clock(l.windowEnd ?? 7)}',
                    'Window ${_clock(l.windowStart!)}–${_clock(l.windowEnd ?? 7)}',
                  ),
          ),
          value: l.windowStart != null,
          onChanged: (v) {
            if (v) {
              l.windowStart = 22;
              l.windowEnd = 7;
            } else {
              l.windowStart = null;
              l.windowEnd = null;
            }
            onChanged();
          },
        ),
        if (l.windowStart != null) ...[
          HeatNumRow(
            key: const ValueKey('dhw-window-start'),
            label: tx(context, 'Ikkuna alkaa klo', 'Window starts at'),
            value: l.windowStart!.toDouble(),
            min: 0,
            max: 23,
            step: 1,
            unit: '',
            onChanged: (v) {
              l.windowStart = v.round();
              onChanged();
            },
          ),
          HeatNumRow(
            key: const ValueKey('dhw-window-end'),
            label: tx(context, 'Ikkuna päättyy klo', 'Window ends at'),
            value: (l.windowEnd ?? 7).toDouble(),
            min: 0,
            max: 23,
            step: 1,
            unit: '',
            onChanged: (v) {
              l.windowEnd = v.round();
              onChanged();
            },
          ),
        ],
        SwitchListTile(
          key: const ValueKey('dhw-ready'),
          contentPadding: EdgeInsets.zero,
          title: Text(tx(context, 'Valmis tähän kelloon', 'Ready by this time')),
          subtitle: Text(
            l.readyByHour == null
                ? tx(
                    context,
                    'Ei käytössä – halvimmat tunnit vuorokauden ympäri.',
                    'Off – cheapest hours around the clock.',
                  )
                : tx(context, 'Valmis klo ${_clock(l.readyByHour!)}', 'Ready at ${_clock(l.readyByHour!)}'),
          ),
          value: l.readyByHour != null,
          onChanged: (v) {
            l.readyByHour = v ? 7 : null;
            onChanged();
          },
        ),
        if (l.readyByHour != null)
          HeatNumRow(
            key: const ValueKey('dhw-ready-hour'),
            label: tx(context, 'Valmis klo', 'Ready at'),
            value: l.readyByHour!.toDouble(),
            min: 0,
            max: 23,
            step: 1,
            unit: '',
            onChanged: (v) {
              l.readyByHour = v.round();
              onChanged();
            },
          ),
        Text(
          tx(
            context,
            'Ilman anturia ohjelma lämmittää valittuina tunteina tai ikkunassa. Anturin kanssa lämmitetään tavoitelämpötilaan ja pakotetaan päälle, jos vesi on alle minimin.',
            'Without a sensor the program heats in the chosen hours or window. With a sensor it stops at the target and force-heats when the water is below the minimum.',
          ),
          style: text.bodySmall,
        ),
      ],
    );
  }
}

/// Sensor, legionella, price cap, minimum heat time, power and high/low setpoints.
class HeatDhwAdvanced extends StatelessWidget {
  const HeatDhwAdvanced({super.key, required this.load, required this.onChanged});
  final HeatLoad load;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final l = load;
    final text = Theme.of(context).textTheme;
    final temps = tempTiles(st.config);
    final sensor = temps.where((t) => t.id == l.sensorTileId).firstOrNull?.title;
    final sets = setpointTiles(st.config);
    final setName = sets.where((t) => t.id == l.tileId).firstOrNull?.title;
    return Column(
      key: const ValueKey('dhw-advanced'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tx(context, 'Käyttövesi, edistyneet', 'Domestic hot water, advanced'), style: text.titleSmall),
        ListTile(
          key: const ValueKey('dhw-sensor'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(l.sensorTileId == null ? Icons.sensors_off : Icons.sensors),
          title: Text(tx(context, 'Lämpötila-anturi (valinnainen)', 'Temperature sensor (optional)')),
          subtitle: Text(
            l.sensorTileId == null
                ? tx(context, 'Ei anturia – ohjaus ajan ja hinnan mukaan', 'No sensor – control by time and price')
                : (sensor ?? l.sensorTileId!),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await pickHeatSensor(context, l);
            onChanged();
          },
        ),
        if (l.control == 'setpoint' || sets.isNotEmpty)
          ListTile(
            key: const ValueKey('dhw-setpoint-device'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.thermostat),
            title: Text(tx(context, 'Lämpöpumpun käyttövesiasetus', 'Heat-pump hot-water setpoint')),
            subtitle: Text(
              l.control == 'setpoint'
                  ? (setName ?? l.tileId ?? tx(context, 'Asetusarvo valittu', 'Setpoint chosen'))
                  : tx(
                      context,
                      'Kirjoita korkea tai matala asetusarvoja hinnan mukaan reletiedon sijaan.',
                      'Write a high or low setpoint by price instead of a relay.',
                    ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showDialog<String>(
                context: context,
                builder: (d) => SimpleDialog(
                  title: Text(tx(context, 'Valitse käyttövesiasetus', 'Choose the hot-water setpoint')),
                  children: [
                    for (final t in sets)
                      SimpleDialogOption(
                        key: ValueKey('dhw-set-${t.id}'),
                        onPressed: () => Navigator.pop(d, t.id),
                        child: Text(t.title.isEmpty ? t.id : t.title),
                      ),
                    if (sets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tx(
                            context,
                            'Ei asetusarvoruutua. Lisää ensin lämpöpumppu, jossa on käyttöveden tavoite.',
                            'No setpoint tile. Add a heat pump with a hot-water target first.',
                          ),
                        ),
                      ),
                  ],
                ),
              );
              if (picked == null) return;
              l.tileId = picked;
              l.control = 'setpoint';
              l.thermostatId = null;
              l.dhwHigh ??= l.dhwTargetOr;
              l.dhwLow ??= l.dhwMinOr;
              onChanged();
            },
          ),
        if (l.control == 'setpoint') ...[
          HeatNumRow(
            key: const ValueKey('dhw-high'),
            label: tx(context, 'Korkea asetusarvo (halpa hinta)', 'High setpoint (cheap price)'),
            value: l.dhwHigh ?? l.dhwTargetOr,
            min: 40,
            max: 80,
            step: 1,
            unit: '°C',
            onChanged: (v) {
              l.dhwHigh = v;
              onChanged();
            },
          ),
          HeatNumRow(
            key: const ValueKey('dhw-low'),
            label: tx(context, 'Matala asetusarvo (kallis hinta)', 'Low setpoint (expensive price)'),
            value: l.dhwLow ?? l.dhwMinOr,
            min: 30,
            max: 70,
            step: 1,
            unit: '°C',
            onChanged: (v) {
              l.dhwLow = v;
              onChanged();
            },
          ),
        ],
        SwitchListTile(
          key: const ValueKey('dhw-legionella'),
          contentPadding: EdgeInsets.zero,
          title: Text(tx(context, 'Legionellasuoja viikoittain', 'Weekly legionella protection')),
          subtitle: Text(
            l.legionellaWeekday == null
                ? tx(context, 'Ei käytössä', 'Off')
                : tx(
                    context,
                    '${_weekdayName(context, l.legionellaWeekday!)} klo ${_clock(l.legionellaHour)}, ${l.legionellaTemp.round()} °C',
                    '${_weekdayName(context, l.legionellaWeekday!)} at ${_clock(l.legionellaHour)}, ${l.legionellaTemp.round()} °C',
                  ),
          ),
          value: l.legionellaWeekday != null,
          onChanged: (v) {
            l.legionellaWeekday = v ? 7 : null;
            onChanged();
          },
        ),
        if (l.legionellaWeekday != null) ...[
          DropdownButtonFormField<int>(
            key: const ValueKey('dhw-legionella-day'),
            initialValue: l.legionellaWeekday,
            decoration: InputDecoration(labelText: tx(context, 'Päivä', 'Day')),
            items: [for (var d = 1; d <= 7; d++) DropdownMenuItem(value: d, child: Text(_weekdayName(context, d)))],
            onChanged: (v) {
              if (v == null) return;
              l.legionellaWeekday = v;
              onChanged();
            },
          ),
          HeatNumRow(
            key: const ValueKey('dhw-legionella-hour'),
            label: tx(context, 'Alkaa klo', 'Starts at'),
            value: l.legionellaHour.toDouble(),
            min: 0,
            max: 23,
            step: 1,
            unit: '',
            onChanged: (v) {
              l.legionellaHour = v.round();
              onChanged();
            },
          ),
          HeatNumRow(
            key: const ValueKey('dhw-legionella-temp'),
            label: tx(context, 'Tavoite', 'Target'),
            value: l.legionellaTemp,
            min: 60,
            max: 80,
            step: 1,
            unit: '°C',
            onChanged: (v) {
              l.legionellaTemp = v;
              onChanged();
            },
          ),
        ],
        HeatNumRow(
          key: const ValueKey('dhw-cap'),
          label: tx(context, 'Enimmäishinta', 'Maximum price'),
          value: l.maxPriceCap ?? 0,
          min: 0,
          max: 80,
          step: 0.5,
          unit: 'c/kWh',
          zeroLabel: tx(context, 'ei käytössä', 'not used'),
          onChanged: (v) {
            l.maxPriceCap = v == 0 ? null : v;
            onChanged();
          },
        ),
        HeatNumRow(
          key: const ValueKey('dhw-min-heat'),
          label: tx(context, 'Vähimmäislämmitysaika', 'Minimum heating time'),
          value: l.minHeatMinutes.toDouble(),
          min: 0,
          max: 240,
          step: 15,
          unit: 'min',
          zeroLabel: tx(context, 'ei käytössä', 'not used'),
          onChanged: (v) {
            l.minHeatMinutes = v.round();
            onChanged();
          },
        ),
        HeatNumRow(
          key: const ValueKey('dhw-power'),
          label: tx(context, 'Teho kustannusarviota varten', 'Power for the cost estimate'),
          value: l.powerKw ?? 0,
          min: 0,
          max: 20,
          step: 0.5,
          unit: 'kW',
          zeroLabel: tx(context, 'ei tiedossa', 'unknown'),
          onChanged: (v) {
            l.powerKw = v == 0 ? null : v;
            onChanged();
          },
        ),
      ],
    );
  }
}
