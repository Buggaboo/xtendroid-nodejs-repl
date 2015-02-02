/**
 *
 * http://nodejs.org/api/repl.html
 *
 */

var net = require("net"),
    repl = require("repl");

net.createServer(function (socket) {
  repl.start({
    prompt: "node via Unix socket> ",
    input: socket,
    output: socket
  }).on('exit', function() {
    socket.end();
  })
}).listen("/data/data/nl.sison.android.nodejs.repl/cache/node-repl-sock");
