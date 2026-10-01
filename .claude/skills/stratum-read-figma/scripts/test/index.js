// Lets `node --test scripts/test/` load the directory: requires every *.test.js in this folder.
const fs = require('fs');
const path = require('path');

fs.readdirSync(__dirname).filter((f) => f.endsWith('.test.js')).sort().forEach((f) => require(path.join(__dirname, f)));
