/**
 *
 * http://nodejs.org/api/repl.html
 *
 */

var net = require("net"),
    repl = require("repl"),
    fs = require('fs');

var socketPath = "/data/data/nl.sison.android.nodejs.repl/cache/node-repl-sock";

var localSocketServer = net.createServer(function (socket) {

  repl.start({
    prompt: "node via Unix socket> ",
    input: socket,
    output: socket
  }).on('exit', function() {
    socket.end();
  });

  socket.setTimeout(60000, function () {
    socket.destroy();
    fs.unlinkSync(socketPath);
  });

}).listen(socketPath);
