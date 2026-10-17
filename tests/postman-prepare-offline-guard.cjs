'use strict';
// Used by real-CLI tests. Any attempted network or subprocess API fails the run.
const Module = require('node:module');
const original = Module._load;
Module._load = function (id, ...rest) {
  if (/^(node:)?(https?|http2|net|tls|dgram|dns|child_process|cluster|worker_threads)$/.test(id)) throw Error('Offline guard blocked ' + id);
  return original.call(this, id, ...rest);
};
global.fetch = () => { throw Error('Offline guard blocked fetch'); };
global.WebSocket = class { constructor() { throw Error('Offline guard blocked WebSocket'); } };
