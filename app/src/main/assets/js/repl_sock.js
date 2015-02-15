/**
 *
 * http://nodejs.org/api/repl.html
 *
 * [src](http://stackoverflow.com/questions/16178239/gracefully-shutdown-unix-socket-server-on-nodejs-running-under-forever)
 *

connect with:

var net = require('net');
var conn = net.createConnection('/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock');
conn.on('connect', function() { console.log('connected to unix socket server');});

get file descriptor:

var fd = fs.openSync('/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock', 'r');
 */

var net = require("net"),
    repl = require("repl"),
    fs = require('fs');

var socketPath = "/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock";

var server = net.createServer(function(socket) { //'connection' listener
    console.log('server connected');

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

    socket.on('end', function() {
        console.log('server disconnected');
    });

    socket.write('hello\r\n');
    socket.pipe(socket);
});

server.listen(socketPath, function() {
    console.log('server bound');
});

server.on('error', function (e) {
    if (e.code == 'EADDRINUSE') {
        var clientSocket = new net.Socket();
        clientSocket.on('error', function(e) { // handle error trying to talk to server
            if (e.code == 'ECONNREFUSED') {  // No other server listening
                fs.unlinkSync(socketPath);
                server.listen(socketPath, function() { //'listening' listener
                    console.log('server recovered');
                });
            }
        });
        clientSocket.connect({path: socketPath}, function() {
            console.log('Server running, giving up...');
//            fs.unlinkSync(socketPath); // TODO review if this is actually what you need
            process.exit();
        });
    }
});

/**
 *
 * Another unix domain socket test -- also broken
 *
 */
var net = require('net');
var socketPath2 = "/data/data/nl.sison.android.nodejs.repl/cache/node-repl-2.sock";
var server = net.createServer(function(c) {
  console.log('client connected');
  c.on('end', function() {
    console.log('client disconnected');
  });
  c.write('hello\r\n');
  c.pipe(c);
});

server.listen(socketPath2, function() {
  console.log('server bound');
});

var conn = net.createConnection({ path:socketPath2 }, function () {});

**
 *
 * Another unix domain socket test, with REPL from the client
 * Not file based.
 *
 */
var net = require('net');
var socketPath = "ghostly";
var server = net.createServer(function(c) {
  console.log('client connected');
  c.on('end', function() {
    console.log('client disconnected');
  });
  c.write('hello\r\n');
  c.pipe(c);
});
server.listen(socketPath);