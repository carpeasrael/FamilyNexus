// Landingpage für Einladungslinks (E-68). Die Angaben stehen im Fragment (#…) der Adresse und gehen nie an den Server.
// Sie werden nur geprüft und zu `familynexus://join?…` zusammengesetzt; ob der Link gültig ist, entscheidet die App.
// Ab Version 4 stehen die Felder kodiert in `d` (E-79). Die Seite dekodiert sie nicht und erkennt abgeschnittene Links
// deshalb nicht, das tut erst die App.
(function () {
  'use strict';

  var KEYS = ['v', 'room', 'via', 'srv', 'inv', 'exp', 'n', 'f', 'by', 'd'];
  var MAX = 1024;
  var SAFE = /^[A-Za-z0-9%._~!$'()*+,;=:@\/?&\-]*$/;
  var PAYLOAD = /^d=[A-Za-z0-9_\-]+$/;

  // Liefert den App-Link oder null. Streng: nur bekannte Felder, keine doppelten, nur unverfängliche Zeichen.
  // Zwei Formen schließen einander aus: genau `v` und `d` (ab Version 4) oder die einzelnen Felder (Version 1 bis 3).
  function buildAppLink(hash) {
    var q = hash && hash.charAt(0) === '#' ? hash.slice(1) : hash;
    if (!q || q.length > MAX || !SAFE.test(q)) return null;
    var seen = {};
    var parts = q.split('&');
    for (var i = 0; i < parts.length; i++) {
      var key = parts[i].split('=')[0];
      if (KEYS.indexOf(key) < 0 || seen[key]) return null;
      if (key === 'd' && !PAYLOAD.test(parts[i])) return null;
      seen[key] = true;
    }
    if (!seen.v || (seen.d ? parts.length !== 2 : !seen.room || !seen.n)) return null;
    return 'familynexus://join?' + q;
  }

  var TEXT = {
    de: {
      title: 'Einladung zu FamilyNexus',
      lead: 'Du wurdest in eine Familie eingeladen. Mit der App FamilyNexus legst du ein Konto an und trittst bei.',
      open: 'App öffnen',
      copy: 'Link kopieren',
      copied: 'Link kopiert. In der App: „Ich wurde eingeladen“ → Link einfügen.',
      installTitle: 'Die App ist noch nicht installiert?',
      installText: 'Installiere FamilyNexus und tippe danach hier erneut auf „App öffnen“. Oder kopiere den Link und füge ihn in der App ein.',
      download: 'App laden',
      web: 'Im Browser öffnen',
      privacy: 'Die Angaben der Einladung bleiben in deinem Browser und werden nicht an diese Seite übertragen.',
      error: 'Dieser Link ist unvollständig oder beschädigt. Bitte die Person, die dich eingeladen hat, um einen neuen Link.'
    },
    en: {
      title: 'Invitation to FamilyNexus',
      lead: 'You have been invited to a family. Use the FamilyNexus app to create an account and join.',
      open: 'Open app',
      copy: 'Copy link',
      copied: 'Link copied. In the app: “I was invited” → paste the link.',
      installTitle: 'App not installed yet?',
      installText: 'Install FamilyNexus, then tap “Open app” here again. Or copy the link and paste it into the app.',
      download: 'Get the app',
      web: 'Open in the browser',
      privacy: 'The details of the invitation stay in your browser and are not sent to this site.',
      error: 'This link is incomplete or damaged. Please ask the person who invited you for a new link.'
    }
  };

  function $(id) { return document.getElementById(id); }

  function run() {
    var lang = (navigator.language || 'en').slice(0, 2).toLowerCase() === 'de' ? 'de' : 'en';
    var t = TEXT[lang];
    document.documentElement.lang = lang;
    document.title = t.title;
    $('title').textContent = t.title;
    $('lead').textContent = t.lead;
    $('open').textContent = t.open;
    $('copy').textContent = t.copy;
    $('installTitle').textContent = t.installTitle;
    $('installText').textContent = t.installText;
    $('download').textContent = t.download;
    $('web').textContent = t.web;
    $('privacy').textContent = t.privacy;

    var link = buildAppLink(window.location.hash);
    if (!link) {
      $('actions').hidden = true;
      $('error').hidden = false;
      $('error').textContent = t.error;
      return;
    }
    $('open').setAttribute('href', link);
    $('copy').addEventListener('click', function () {
      var done = function () { $('copied').hidden = false; $('copied').textContent = t.copied; };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(link).then(done, function () { window.prompt(t.copy, link); });
      } else {
        window.prompt(t.copy, link);
      }
    });
  }

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { buildAppLink: buildAppLink };
  } else {
    run();
  }
})();
