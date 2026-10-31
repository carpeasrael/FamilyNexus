import 'dart:convert';

/// Felder eines Einladungslinks als Query, in der Reihenfolge von `InviteLink.create` (`n` zuletzt).
/// Ohne [srv] fehlt das Feld (Versionen 1 und 2).
String inviteFields({
  required String room,
  required String via,
  required String inv,
  required int exp,
  required String n,
  String? srv,
  String? family,
  String? by,
}) =>
    Uri(queryParameters: <String, String>{
      'room': room,
      'via': via,
      'srv': ?srv,
      'inv': inv,
      'exp': '$exp',
      'f': ?family,
      'by': ?by,
      'n': n,
    }).query;

/// Link der Version 3, wie ihn ältere Apps erzeugen: Diese Links gelten noch bis zu 7 Tage.
String v3Link(String fields) => 'familynexus://join?v=3&$fields';

/// Payload `d` eines Links der Version 4.
String v4Payload(String inner) => base64Url.encode(utf8.encode(inner)).replaceAll('=', '');

/// Link der Version 4 mit beliebigem Inneren (auch manipuliertem).
String v4(String inner) => 'familynexus://join?v=4&d=${v4Payload(inner)}';

/// Das Innere eines Links der Version 4.
String v4Inner(String link) => utf8.decode(base64Url.decode(base64Url.normalize(link.substring(link.indexOf('&d=') + 3))));
