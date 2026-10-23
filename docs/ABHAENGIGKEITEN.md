# Abhängigkeiten (SBOM)

Stand: 2026-10-22 · erzeugt mit `tool/sbom.py` aus `pubspec.lock` und pub.dev.

Alle direkten Abhängigkeiten sind in `pubspec.yaml` exakt gepinnt; transitive Versionen fixiert `pubspec.lock`. Spalte „Pub-Punkte“ = pub.dev-Bewertung (max. 160).

| Paket | Art | Version | Veröffentlicht | Lizenz | Pub-Punkte | Hinweis |
|---|---|---|---|---|---|---|
| `file_picker` | direct main | 13.1.0 | 2026-09-15 | mit | 160 | ok |
| `flutter` | direct main | 0.0.0 | — | — | — | SDK/lokal |
| `flutter_local_notifications` | direct main | 22.3.2 | 2026-10-12 | bsd-3-clause | 150 | ok |
| `flutter_localizations` | direct main | 0.0.0 | — | — | — | SDK/lokal |
| `flutter_secure_storage` | direct main | 11.2.0 | 2026-09-16 | bsd-3-clause | 160 | ok |
| `flutter_timezone` | direct main | 5.1.1 | 2026-10-03 | apache-2.0 | 160 | ok |
| `flutter_vodozemac` | direct main | 0.9.0 | 2026-10-19 | agpl-3.0 | 140 | ok |
| `http` | direct main | 1.6.0 | 2025-11-10 | bsd-3-clause | 160 | ok |
| `intl` | direct main | 0.20.3 | 2026-06-25 | bsd-3-clause | 160 | ok |
| `local_auth` | direct main | 3.0.2 | 2026-07-09 | bsd-3-clause | 160 | ok |
| `matrix` | direct main | 14.2.0 | 2026-10-20 | agpl-3.0 | 150 | ok |
| `path` | direct main | 1.9.1 | 2024-10-17 | bsd-3-clause | 160 | ok |
| `qr` | direct main | 4.0.0 | 2026-05-16 | bsd-3-clause | 160 | ok |
| `sqflite_common` | direct main | 2.5.14 | — | bsd-2-clause | — | Web-Fabrik (E-53), vorher nur transitiv |
| `sqflite_common_ffi` | direct main | 2.4.4 | 2026-10-13 | bsd-2-clause | 160 | ok |
| `sqflite_common_ffi_web` | direct main | 1.2.0 | — | bsd-2-clause | — | nur Browser (E-53) |
| `sqflite_sqlcipher` | direct main | 3.4.1 | 2026-08-04 | mit | 150 | ok |
| `sqlite3` | direct main | 3.5.2 | — | mit | — | Browser: WebAssembly-Anbindung (E-53), vorher nur transitiv |
| `timezone` | direct main | 0.11.2 | 2026-10-12 | bsd-2-clause | 160 | ok |
| `url_launcher` | direct main | 6.3.3 | 2026-10-02 | bsd-3-clause | 160 | ok |
| `uuid` | direct main | 4.6.0 | 2026-07-15 | mit | 160 | ok |
| `web` | direct main | 1.1.1 | — | bsd-3-clause | — | Browser: WebCrypto, Web Locks (E-53), vorher nur transitiv |
| `flutter_lints` | direct dev | 6.0.0 | 2025-05-27 | bsd-3-clause | 160 | ok |
| `flutter_test` | direct dev | 0.0.0 | — | — | — | SDK/lokal |
| `integration_test` | direct dev | 0.0.0 | — | — | — | SDK/lokal |
| `path_provider` | direct dev | 2.1.6 | 2026-06-15 | bsd-3-clause | 160 | ok |
| `vodozemac` | direct dev | 0.9.0 | 2026-10-19 | agpl-3.0 | 150 | ok |
| `android_file_picker` | transitive | 2.1.1 | 2026-10-15 | mit | 160 | ok |
| `archive` | transitive | 4.5.2 | 2026-10-13 | mit | 160 | ok |
| `args` | transitive | 2.7.0 | 2025-03-12 | bsd-3-clause | 150 | ok |
| `async` | transitive | 2.13.1 | 2026-03-26 | bsd-3-clause | 150 | ok |
| `base58check` | transitive | 2.0.0 | 2021-03-06 | mit | 120 | ok |
| `blurhash_dart` | transitive | 1.2.1 | 2023-02-04 | mit | 160 | ok |
| `boolean_selector` | transitive | 2.1.2 | 2024-10-22 | bsd-3-clause | 160 | ok |
| `build_cli_annotations` | transitive | 2.1.1 | 2025-09-08 | mit | 150 | ok |
| `canonical_json` | transitive | 1.1.3 | 2026-02-24 | apache-2.0 | 160 | ok |
| `characters` | transitive | 1.4.1 | 2025-06-25 | bsd-3-clause | 160 | ok |
| `clock` | transitive | 1.1.3 | 2026-08-28 | apache-2.0 | 140 | ok |
| `code_assets` | transitive | 1.2.1 | 2026-06-01 | bsd-3-clause | 160 | neuer: 2.1.0 |
| `collection` | transitive | 1.19.1 | 2024-10-21 | bsd-3-clause | 140 | ok |
| `cross_file` | transitive | 0.3.5+5 | 2026-08-25 | bsd-3-clause | 160 | neuer: 0.4.0 |
| `crypto` | transitive | 3.0.7 | 2025-11-04 | bsd-3-clause | 160 | ok |
| `csslib` | transitive | 1.0.2 | 2024-10-29 | bsd-3-clause | 160 | ok |
| `dbus` | transitive | 0.8.0 | 2026-09-16 | mpl-2.0 | 160 | ok |
| `equatable` | transitive | 3.0.0 | 2026-09-15 | mit | 160 | ok |
| `fake_async` | transitive | 1.3.3 | 2025-01-28 | apache-2.0 | 150 | ok |
| `ffi` | transitive | 2.2.0 | 2026-02-11 | bsd-3-clause | 160 | ok |
| `ffi_leak_tracker` | transitive | 0.1.2 | 2026-04-11 | bsd-3-clause | 160 | ok |
| `file` | transitive | 7.0.1 | 2024-10-08 | bsd-3-clause | 150 | ok |
| `file_picker_darwin` | transitive | 2.3.2 | 2026-10-15 | mit | 160 | ok |
| `file_picker_linux` | transitive | 2.0.2 | 2026-10-06 | mit | 160 | ok |
| `file_picker_platform_interface` | transitive | 4.2.0 | 2026-10-13 | mit | 160 | ok |
| `file_picker_web` | transitive | 4.2.0 | 2026-10-15 | mit | 160 | ok |
| `fixnum` | transitive | 1.1.1 | 2024-10-16 | bsd-3-clause | 150 | ok |
| `flutter_driver` | transitive | 0.0.0 | — | — | — | SDK/lokal |
| `flutter_local_notifications_linux` | transitive | 8.0.2 | 2026-10-12 | bsd-3-clause | 150 | ok |
| `flutter_local_notifications_platform_interface` | transitive | 12.2.0 | 2026-08-08 | bsd-3-clause | 150 | ok |
| `flutter_local_notifications_web` | transitive | 1.0.0 | 2026-06-07 | bsd-3-clause | 150 | ok |
| `flutter_local_notifications_windows` | transitive | 3.1.1 | 2026-06-14 | bsd-3-clause | 150 | ok |
| `flutter_plugin_android_lifecycle` | transitive | 2.0.35 | 2026-06-02 | bsd-3-clause | 160 | ok |
| `flutter_rust_bridge` | transitive | 2.13.0 | 2026-08-23 | mit | 160 | ok |
| `flutter_secure_storage_darwin` | transitive | 0.4.3 | 2026-09-16 | bsd-3-clause | 150 | ok |
| `flutter_secure_storage_linux` | transitive | 3.0.3 | 2026-09-11 | bsd-3-clause | 140 | ok |
| `flutter_secure_storage_platform_interface` | transitive | 2.1.1 | 2026-09-16 | bsd-3-clause | 150 | ok |
| `flutter_secure_storage_web` | transitive | 2.1.1 | 2026-05-06 | bsd-3-clause | 150 | ok |
| `flutter_secure_storage_windows` | transitive | 4.2.2 | 2026-05-22 | bsd-3-clause | 150 | ok |
| `flutter_web_plugins` | transitive | 0.0.0 | — | — | — | SDK/lokal |
| `fuchsia_remote_debug_protocol` | transitive | 0.0.0 | — | — | — | SDK/lokal |
| `glob` | transitive | 2.2.0 | 2026-08-28 | bsd-3-clause | 150 | ok |
| `hooks` | transitive | 2.0.2 | 2026-06-02 | bsd-3-clause | 160 | neuer: 2.2.0 |
| `html` | transitive | 0.15.7 | 2026-08-28 | unknown | 150 | ok |
| `html_unescape` | transitive | 2.0.0 | 2021-03-22 | bsd-3-clause | 160 | ok |
| `http_parser` | transitive | 4.1.2 | 2025-01-02 | bsd-3-clause | 160 | ok |
| `image` | transitive | 4.12.0 | 2026-10-11 | mit | 160 | ok |
| `jni` | transitive | 1.1.0 | 2026-10-01 | bsd-3-clause | 160 | ok |
| `jni_flutter` | transitive | 1.0.4+1 | 2026-10-06 | bsd-3-clause | 160 | ok |
| `jni_util` | transitive | 1.0.0 | 2026-07-27 | bsd-3-clause | 150 | ok |
| `leak_tracker` | transitive | 11.0.2 | 2025-09-10 | bsd-3-clause | 160 | ok |
| `leak_tracker_flutter_testing` | transitive | 3.0.10 | 2025-04-21 | bsd-3-clause | 150 | ok |
| `leak_tracker_testing` | transitive | 3.0.2 | 2025-04-21 | bsd-3-clause | 120 | ok |
| `lints` | transitive | 6.1.0 | 2026-01-30 | bsd-3-clause | 160 | ok |
| `local_auth_android` | transitive | 2.3.0 | 2026-10-13 | bsd-3-clause | 150 | ok |
| `local_auth_darwin` | transitive | 2.0.5 | 2026-10-17 | bsd-3-clause | 150 | ok |
| `local_auth_platform_interface` | transitive | 1.1.0 | 2025-09-30 | bsd-3-clause | 150 | ok |
| `local_auth_windows` | transitive | 2.0.2 | 2026-08-28 | bsd-3-clause | 150 | ok |
| `logging` | transitive | 1.3.0 | 2024-10-17 | bsd-3-clause | 160 | ok |
| `markdown` | transitive | 7.3.1 | 2026-03-18 | bsd-3-clause | 160 | ok |
| `matcher` | transitive | 0.12.20 | 2026-04-27 | bsd-3-clause | 150 | ok |
| `material_color_utilities` | transitive | 0.13.0 | 2025-06-04 | apache-2.0 | 150 | neuer: 0.13.1 |
| `meta` | transitive | 1.18.3 | 2026-06-04 | bsd-3-clause | 150 | neuer: 1.19.0 |
| `mime` | transitive | 2.1.0 | 2026-08-28 | bsd-3-clause | 160 | ok |
| `native_toolchain_c` | transitive | 0.19.2 | 2026-06-29 | bsd-3-clause | 150 | neuer: 0.19.5 |
| `objective_c` | transitive | 9.5.0 | 2026-07-27 | bsd-3-clause | 150 | neuer: 9.6.2 |
| `package_config` | transitive | 3.0.0 | 2026-06-08 | bsd-3-clause | 150 | ok |
| `path_provider_android` | transitive | 2.3.1 | 2026-04-08 | bsd-3-clause | 160 | ok |
| `path_provider_foundation` | transitive | 2.6.0 | 2026-01-15 | bsd-3-clause | 160 | ok |
| `path_provider_linux` | transitive | 2.2.2 | 2026-06-24 | bsd-3-clause | 150 | ok |
| `path_provider_platform_interface` | transitive | 2.1.3 | 2026-06-15 | bsd-3-clause | 140 | ok |
| `path_provider_windows` | transitive | 2.3.0 | 2024-07-09 | bsd-3-clause | 160 | ok |
| `petitparser` | transitive | 7.0.2 | 2026-02-14 | mit | 160 | neuer: 7.1.0 |
| `platform` | transitive | 3.2.0 | 2026-09-07 | bsd-3-clause | 160 | ok |
| `plugin_platform_interface` | transitive | 2.1.8 | 2024-01-04 | bsd-3-clause | 150 | ok |
| `posix` | transitive | 6.5.2 | 2026-07-24 | mit | 130 | ok |
| `process` | transitive | 5.0.6 | 2026-08-28 | bsd-3-clause | 150 | ok |
| `pub_semver` | transitive | 2.2.1 | 2026-08-28 | bsd-3-clause | 160 | ok |
| `random_string` | transitive | 2.3.1 | 2021-07-16 | bsd-3-clause | 160 | ok |
| `record_use` | transitive | 0.6.0 | 2026-03-25 | bsd-3-clause | 160 | neuer: 1.1.1 |
| `sdp_transform` | transitive | 0.3.2 | 2021-09-04 | mit | 120 | neuer: 0.4.0 |
| `sky_engine` | transitive | 0.0.0 | — | — | — | SDK/lokal |
| `slugify` | transitive | 2.0.0 | 2021-03-28 | mit | 135 | ok |
| `source_span` | transitive | 1.10.2 | 2026-02-05 | bsd-3-clause | 160 | ok |
| `sqflite_common` | transitive | 2.5.14 | 2026-10-13 | bsd-2-clause | 160 | ok |
| `sqlite3` | transitive | 3.5.2 | 2026-08-19 | mit | 150 | neuer: 3.7.1 |
| `stack_trace` | transitive | 1.12.2 | 2026-08-28 | bsd-3-clause | 160 | ok |
| `stream_channel` | transitive | 2.1.4 | 2025-01-07 | bsd-3-clause | 140 | ok |
| `string_scanner` | transitive | 1.4.1 | 2024-12-17 | bsd-3-clause | 150 | ok |
| `sync_http` | transitive | 0.3.1 | 2022-06-15 | bsd-3-clause | 120 | ok |
| `synchronized` | transitive | 3.5.0 | 2026-10-13 | mit | 160 | ok |
| `term_glyph` | transitive | 1.2.2 | 2024-12-17 | bsd-3-clause | 140 | ok |
| `test_api` | transitive | 0.7.12 | 2026-04-27 | bsd-3-clause | 150 | neuer: 0.7.15 |
| `typed_data` | transitive | 1.4.0 | 2024-10-17 | bsd-3-clause | 150 | ok |
| `unorm_dart` | transitive | 0.3.3 | 2026-10-04 | mit | 150 | ok |
| `url_launcher_android` | transitive | 6.3.33 | 2026-08-28 | bsd-3-clause | 160 | ok |
| `url_launcher_ios` | transitive | 6.4.2 | 2026-08-28 | bsd-3-clause | 150 | ok |
| `url_launcher_linux` | transitive | 3.2.3 | 2026-08-28 | bsd-3-clause | 150 | ok |
| `url_launcher_macos` | transitive | 3.2.6 | 2026-08-28 | bsd-3-clause | 150 | ok |
| `url_launcher_platform_interface` | transitive | 2.3.2 | 2024-02-15 | bsd-3-clause | 150 | ok |
| `url_launcher_web` | transitive | 2.4.3 | 2026-05-05 | bsd-3-clause | 150 | ok |
| `url_launcher_windows` | transitive | 3.1.6 | 2026-08-28 | bsd-3-clause | 160 | ok |
| `vector_math` | transitive | 2.4.0 | 2026-06-03 | bsd-3-clause | 150 | neuer: 2.4.3 |
| `vm_service` | transitive | 15.4.0 | 2026-10-15 | bsd-3-clause | 150 | ok |
| `web` | transitive | 1.1.1 | 2025-02-26 | bsd-3-clause | 150 | ok |
| `webdriver` | transitive | 3.2.0 | 2026-09-09 | apache-2.0 | 130 | ok |
| `webrtc_interface` | transitive | 1.5.1 | 2026-03-16 | mit | 130 | ok |
| `win32` | transitive | 6.4.0 | 2026-08-05 | bsd-3-clause | 160 | ok |
| `windows_file_picker` | transitive | 2.0.1 | 2026-10-06 | mit | 160 | ok |
| `xdg_directories` | transitive | 1.1.0 | 2024-10-04 | bsd-3-clause | 160 | ok |
| `xml` | transitive | 7.0.1 | 2026-04-25 | mit | 160 | neuer: 7.1.0 |
| `yaml` | transitive | 3.1.4 | 2026-08-28 | mit | 160 | ok |
