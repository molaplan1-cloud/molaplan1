# Molaplan app – agent notes

New Molaplan (Nov 2026): user-customisable remote control / status terminal.
Flutter, targets Windows + Android. UI default Finnish, English available.

## Env (box)
- Flutter: ~/flutter (3.50.1 stable). Material is `package:material_ui/material_ui.dart` (flutter/material.dart deprecated in 3.47+).
- JDK 17: ~/jdk/jdk-17.0.21.1+2 ; Android SDK: ~/android-sdk (env in ~/.bashrc)
- Run: `bash -lc 'cd /workspace/molaplan-app && flutter test'`

## Structure
- lib/core: jsonpath, templates ({{value}}), FieldSpec (generic form schema)
- lib/models: ConnectionConfig, TileConfig, CommandStep, Dashboard, AppConfig (JSON)
- lib/drivers: Driver interface + http, mqtt, modbus (own client), homeassistant (REST+ws), camera (MJPEG/snapshot), websocket, tcp, udp; registry.dart
- lib/state: storage (prefs + secure storage), app_state, tile runtime (poll/watch)
- lib/ui: screens

## Progress
- [x] Flutter installed, project created, drivers written
