/**
 *
 * http://nodejs.org/api/repl.html
 *
 * [src](http://stackoverflow.com/questions/16178239/gracefully-shutdown-unix-socket-server-on-nodejs-running-under-forever)
 *
 test with:

var net = require('net');
var conn = net.createConnection("/home/me/node-repl-sock");
conn.on('connect', function() { console.log('connected to unix socket server');});
conn.on('data', function (data) {
  console.log(data);
});


 */
var net = require("net"),
    repl = require("repl"),
    fs = require('fs');

var socketPath = "/home/me/node-repl-sock";

var server = net.createServer(function(c) { //'connection' listener
    console.log('server connected');
    repl.start({
        prompt: "node via Unix socket> ",
        input: c,
        output: c
    }).on('exit', function() {
        socket.end();
    });

    c.setTimeout(60000, function () {
        c.destroy();
        fs.unlinkSync(socketPath);
    });

    c.on('end', function() {
        console.log('server disconnected');
    });

    c.write('hello\r\n');
    c.pipe(c);
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
            process.exit();
        });
    }
});

server.listen(socketPath, function() { //'listening' listener
    console.log('server bound');
});


/**
 *
 *
 test with:

var net = require('net'),
    repl = require('repl');
var conn = net.createConnection("/home/me/node-repl-sock");
conn.on('connect', function() {
  console.log('connected to unix socket server');
  repl.start({
    prompt: "node via Unix socket> ",
    input: c,
    output: c
  }).on('exit', function() {
    socket.end();
  });
});
conn.on('data', function (data) {
  console.log(data);
});
 */
var net = require("net"),
    repl = require("repl"),
    fs = require('fs');

var socketPath = "/home/me/node-repl-sock-1";

var server = net.createServer(function(c) { //'connection' listener
    console.log('server connected');

    c.setTimeout(60000, function () {
        c.destroy();
        fs.unlinkSync(socketPath);
    });

    c.on('end', function() {
        console.log('server disconnected');
    });

    c.write('hello\r\n');
    c.pipe(c);
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
            process.exit();
        });
    }
});

server.listen(socketPath, function() { //'listening' listener
    console.log('server bound');
});