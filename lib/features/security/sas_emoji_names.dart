/// Namen der 64 Matrix-Vergleichssymbole (SAS) in der Sprache der App, für die Bedienungshilfe (#39).
/// Das SDK liefert nur die englischen Standardnamen.
class SasEmojiNames {
  const SasEmojiNames._();

  static const Map<String, String> _de = <String, String>{
    'Dog': 'Hund',
    'Cat': 'Katze',
    'Lion': 'Löwe',
    'Horse': 'Pferd',
    'Unicorn': 'Einhorn',
    'Pig': 'Schwein',
    'Elephant': 'Elefant',
    'Rabbit': 'Hase',
    'Panda': 'Panda',
    'Rooster': 'Hahn',
    'Penguin': 'Pinguin',
    'Turtle': 'Schildkröte',
    'Fish': 'Fisch',
    'Octopus': 'Oktopus',
    'Butterfly': 'Schmetterling',
    'Flower': 'Blume',
    'Tree': 'Baum',
    'Cactus': 'Kaktus',
    'Mushroom': 'Pilz',
    'Globe': 'Globus',
    'Moon': 'Mond',
    'Cloud': 'Wolke',
    'Fire': 'Feuer',
    'Banana': 'Banane',
    'Apple': 'Apfel',
    'Strawberry': 'Erdbeere',
    'Corn': 'Mais',
    'Pizza': 'Pizza',
    'Cake': 'Kuchen',
    'Heart': 'Herz',
    'Smiley': 'Lächeln',
    'Robot': 'Roboter',
    'Hat': 'Hut',
    'Glasses': 'Brille',
    'Spanner': 'Schraubenschlüssel',
    'Santa': 'Weihnachtsmann',
    'Thumbs Up': 'Daumen hoch',
    'Umbrella': 'Regenschirm',
    'Hourglass': 'Sanduhr',
    'Clock': 'Uhr',
    'Gift': 'Geschenk',
    'Light Bulb': 'Glühbirne',
    'Book': 'Buch',
    'Pencil': 'Bleistift',
    'Paperclip': 'Büroklammer',
    'Scissors': 'Schere',
    'Lock': 'Schloss',
    'Key': 'Schlüssel',
    'Hammer': 'Hammer',
    'Telephone': 'Telefon',
    'Flag': 'Flagge',
    'Train': 'Zug',
    'Bicycle': 'Fahrrad',
    'Aeroplane': 'Flugzeug',
    'Rocket': 'Rakete',
    'Trophy': 'Pokal',
    'Ball': 'Ball',
    'Guitar': 'Gitarre',
    'Trumpet': 'Trompete',
    'Bell': 'Glocke',
    'Anchor': 'Anker',
    'Headphones': 'Kopfhörer',
    'Folder': 'Ordner',
    'Pin': 'Stecknadel',
  };

  /// Name für die Sprache [languageCode]; unbekannte Namen bleiben englisch.
  static String of(String englishName, String languageCode) =>
      languageCode == 'de' ? (_de[englishName] ?? englishName) : englishName;

  /// Alle bekannten englischen Namen (für Tests).
  static Iterable<String> get known => _de.keys;
}
