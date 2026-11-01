import 'family.dart';
import 'security.dart';

/// Wo die Schlüssel der lokalen Datenbanken liegen (je Plattform).
enum KeyStoreKind { androidKeystore, appleKeychain, linuxSecretService, linuxFlatpakPortal, windowsCredentialManager, browserVault }

/// Speicherorte der lokalen Daten dieser App.
class StorageLocations {
  const StorageLocations({
    required this.databaseDirectory,
    required this.appDatabase,
    required this.matrixDatabase,
    required this.keyStore,
    this.inBrowser = false,
  });

  /// Ordner der Datenbankdateien; leer im Browser (dort IndexedDB).
  final String databaseDirectory;

  /// Vollständiger Pfad (Browser: Name in IndexedDB) der App-Datenbank.
  final String appDatabase;

  /// Vollständiger Pfad (Browser: Name in IndexedDB) der Matrix-Datenbank.
  final String matrixDatabase;
  final KeyStoreKind keyStore;
  final bool inBrowser;
}

/// Eine Tabelle der App-Datenbank mit allen Zeilen.
class LocalTable {
  const LocalTable(this.name, this.rows);
  final String name;
  final List<Map<String, Object?>> rows;
}

/// Eintrag im Schlüsselspeicher; der Wert selbst wird nie herausgegeben.
class LocalKey {
  const LocalKey(this.name, {required this.present});
  final String name;
  final bool present;
}

/// Alles, was diese App lokal in der App-Datenbank und im Schlüsselspeicher ablegt.
class LocalInventory {
  const LocalInventory({
    required this.locations,
    required this.keys,
    required this.tables,
    this.appDatabaseBytes,
    this.matrixDatabaseBytes,
  });

  final StorageLocations locations;
  final List<LocalKey> keys;
  final List<LocalTable> tables;

  /// Dateigröße; `null` im Browser oder wenn die Datei fehlt.
  final int? appDatabaseBytes;
  final int? matrixDatabaseBytes;
}

/// Liest Speicherorte und Inhalt der lokalen App-Datenbank (für das Datenprotokoll).
abstract class LocalDataInventory {
  Future<StorageLocations> locations();
  Future<LocalInventory> read();
}

enum InventoryRoomKind { family, private, direct, other }

/// Ein Matrix-Raum des Kontos mit den auf diesem Gerät zwischengespeicherten Ereignissen.
class InventoryRoom {
  const InventoryRoom({
    required this.id,
    required this.kind,
    required this.name,
    required this.encrypted,
    required this.membership,
    required this.joinedMembers,
    required this.invitedMembers,
    required this.cachedEvents,
    required this.eventTypes,
    required this.attachments,
  });

  final String id;
  final InventoryRoomKind kind;

  /// Bereinigter Raumname (kann leer sein).
  final String name;
  final bool encrypted;

  /// Eigene Mitgliedschaft (`join`, `invite`, `knock`, `leave` …).
  final String membership;
  final int joinedMembers;
  final int invitedMembers;

  /// Anzahl der lokal gespeicherten Ereignisse dieses Raums.
  final int cachedEvents;

  /// Ereignisarten (entschlüsselt, soweit möglich) → Anzahl.
  final Map<String, int> eventTypes;

  /// Nachrichten mit (verschlüsselt hochgeladener) Datei.
  final int attachments;
}

/// Was beim Matrix-Anbieter zu diesem Konto gespeichert ist (Stand: letzter Abgleich, Profil frisch abgefragt).
class OnlineInventory {
  const OnlineInventory({
    required this.server,
    required this.userId,
    required this.deviceId,
    required this.displayName,
    required this.hasAvatar,
    required this.devices,
    required this.crossSigning,
    required this.keyBackup,
    required this.accountDataTypes,
    required this.rooms,
    this.family,
  });

  final String server;
  final String userId;
  final String deviceId;

  /// `null`, wenn kein Anzeigename gesetzt ist oder das Profil nicht abrufbar war.
  final String? displayName;
  final bool hasAvatar;
  final List<DeviceEntry> devices;
  final bool crossSigning;

  /// Verschlüsselte Sicherung der Raumschlüssel (Schlüssel-Backup) ist eingerichtet.
  final bool keyBackup;

  /// Arten der Kontodaten (Inhalte werden nicht ausgegeben).
  final List<String> accountDataTypes;
  final List<InventoryRoom> rooms;
  final Family? family;
}
