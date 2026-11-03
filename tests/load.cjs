// A model's globals, loaded as QML loads the file: each file has a global
// scope of its own, and `.import "Other.js" as Other` binds the other file's
// globals under that name, the path taken from the importing file's folder.
// Each file runs once per load call, so models importing one owner share it.
//
// The code runs in this realm, not a vm context: arrays and objects a vm
// context makes have that context's prototypes, which assert's deep strict
// equality tells apart from the test's own. A dry run in a scratch context
// names the file's globals for the real run to hand back.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const directive = /^\.(?:import\s+"([^"]+)"\s+as\s+(\w+)|pragma\s+\w+)\s*;?\s*$/;

module.exports = function load(file) {
  const loaded = new Map();
  const run = at => {
    if (loaded.has(at)) return loaded.get(at);
    const model = {};
    loaded.set(at, model);
    const imports = {};
    const source = fs.readFileSync(at, 'utf8').split('\n').map(line => {
      const m = directive.exec(line);
      if (m && m[1]) imports[m[2]] = run(path.resolve(path.dirname(at), m[1]));
      return m ? '' : line;
    }).join('\n');
    const scratch = vm.createContext({ ...imports });
    vm.runInContext(source, scratch, { filename: at });
    const names = Object.keys(scratch).filter(name => !(name in imports));
    const body = `${source}\n;return { ${names.join(', ')} };`;
    const fn = vm.compileFunction(body, Object.keys(imports), { filename: at });
    return Object.assign(model, fn(...Object.values(imports)));
  };
  return run(path.resolve(__dirname, '..', file));
};
