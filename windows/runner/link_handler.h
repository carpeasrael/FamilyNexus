#ifndef RUNNER_LINK_HANDLER_H_
#define RUNNER_LINK_HANDLER_H_

#include <windows.h>

#include <string>

// Einladungslinks (`familynexus://join?...`, E-69): Schema-Registrierung und Einzelinstanz.
namespace link_handler {

// Kennung der WM_COPYDATA-Nachricht, mit der eine zweite Instanz den Link an die laufende übergibt.
constexpr ULONG_PTR kCopyDataId = 0x464E4C4B;  // "FNLK"

// Längster Link in Bytes (die Dart-Seite prüft zusätzlich selbst, E-14).
constexpr DWORD kMaxLinkBytes = 2048;

// Nur das eigene Schema wird weitergereicht.
bool IsFamilyNexusLink(const std::string& link);

// Trägt `familynexus:` unter HKEY_CURRENT_USER ein (kein Administrator nötig), falls es fehlt oder auf einen
// anderen Ort zeigt. Wird bei jedem Start geprüft, damit ein verschobener Ordner weiter funktioniert.
void RegisterUrlScheme();

// Gibt es schon eine laufende Instanz, übergibt diese Funktion den Link (falls vorhanden), holt deren Fenster nach
// vorn und liefert true; dann beendet sich die neue Instanz. Liefert false, wenn dies die erste Instanz ist
// oder die laufende nicht antwortet.
bool ForwardToRunningInstance(const std::string& link);

// Muss die erste Instanz einmal aufrufen (hält die Marke, solange das Programm läuft).
bool ClaimInstance();

}  // namespace link_handler

#endif  // RUNNER_LINK_HANDLER_H_
