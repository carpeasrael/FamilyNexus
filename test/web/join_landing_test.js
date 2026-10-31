const assert = require('assert');
const { buildAppLink } = require(require('path').join(__dirname, '../../web/join/join.js'));
const q = 'v=3&room=!abc%3Afake.test&via=fake.test&srv=fake.test&inv=%40anna%3Afake.test&exp=1&n=' + '0'.repeat(32);
assert.strictEqual(buildAppLink('#' + q), 'familynexus://join?' + q);
assert.strictEqual(buildAppLink('#' + q + '&f=Familie%20Test&by=Anna'), 'familynexus://join?' + q + '&f=Familie%20Test&by=Anna');
const v4 = 'v=4&d=cm9vbT0lMjFhYmMtX18';
assert.strictEqual(buildAppLink('#' + v4), 'familynexus://join?' + v4);
assert.strictEqual(buildAppLink(v4), 'familynexus://join?' + v4);
assert.strictEqual(buildAppLink('#d=abc&v=4'), 'familynexus://join?d=abc&v=4');
assert.strictEqual(buildAppLink('#v=5&d=abc'), 'familynexus://join?v=5&d=abc', 'neuere Version entscheidet die App');
for (const bad of ['#v=4', '#v=4&d', '#v=4&d=', '#d=abc', '#' + v4 + '&d=abc', '#' + v4 + '&room=x', '#' + v4 + '&n=1', '#' + v4 + '&evil=1', '#' + q + '&d=abc', '#room=x&d=abc', '#' + v4 + '=', '#' + v4 + '+', '#' + v4 + '/', '#' + v4 + '%41', '#' + v4 + '"><script>']) {
  assert.strictEqual(buildAppLink(bad), null, JSON.stringify(bad).slice(0, 60));
}
for (const bad of ['', '#', '#v=3', '#' + q + '&evil=1', '#' + q + '&v=3', '#' + q + '"><script>', '#' + q + ' x', '#' + 'a'.repeat(2000), '#javascript:alert(1)', '#' + q + '#x', '#v=3&room=x']) {
  assert.strictEqual(buildAppLink(bad), null, JSON.stringify(bad).slice(0, 60));
}
console.log('ok');
