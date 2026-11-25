/// Texte von Fremden (Name, Kennung) mit Unicode-Isolierung anzeigen (First-Strong-Isolate bis Pop-Directional-Isolate):
/// Eine Kennung oder ein Name mit Zeichen anderer Schreibrichtung kann so den umgebenden Text nicht umordnen
/// (#119, K3b-1).
String isolateText(String s) => '\u2068$s\u2069';
