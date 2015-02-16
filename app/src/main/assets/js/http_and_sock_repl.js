/*
 * https://gist.github.com/TooTallNate/2053342
 * Requires node v0.7.7 or greater.
 *
 * TODO - create knock knock diffie-hellman
 *
 * To connect: $ curl -sSNT. localhost:8000
 */
var http = require('http'),
    repl = require('repl'),
    buf0 = new Buffer([0])

var http_server = http.createServer(function(req, res) {
    res.setHeader('content-type', 'multipart/octet-stream')

    res.write('Xtendroid nodejs repl\r\n')
    repl.start({
        prompt: '> ',
        input: req,
        output: res,
        terminal: false,
        useColors: true,
        useGlobal: false
    })

    // log
    console.log(req.headers['user-agent'])

    // hack to thread stdin and stdout
    // simultaneously in curl's single thread
    var iv = setInterval(function() {
        res.write(buf0)
    }, 100)

    res.connection.on('end', function() {
        clearInterval(iv)
    })
})
http_server.listen(8000)


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