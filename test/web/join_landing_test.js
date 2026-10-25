const assert = require('assert');
const { buildAppLink } = require(require('path').join(__dirname, '../../web/join/join.js'));
const q = 'v=3&room=!abc%3Afake.test&via=fake.test&srv=fake.test&inv=%40anna%3Afake.test&exp=1&n=' + '0'.repeat(32);
assert.strictEqual(buildAppLink('#' + q), 'familynexus://join?' + q);
assert.strictEqual(buildAppLink('#' + q + '&f=Familie%20Test&by=Anna'), 'familynexus://join?' + q + '&f=Familie%20Test&by=Anna');
for (const bad of ['', '#', '#v=3', '#' + q + '&evil=1', '#' + q + '&v=3', '#' + q + '"><script>', '#' + q + ' x', '#' + 'a'.repeat(2000), '#javascript:alert(1)', '#' + q + '#x', '#v=3&room=x']) {
  assert.strictEqual(buildAppLink(bad), null, JSON.stringify(bad).slice(0, 60));
}
console.log('ok');
