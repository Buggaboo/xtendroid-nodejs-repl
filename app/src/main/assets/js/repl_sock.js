/**
 *
 * http://nodejs.org/api/repl.html
 *
 * [src](http://stackoverflow.com/questions/16178239/gracefully-shutdown-unix-socket-server-on-nodejs-running-under-forever)
 *
 */
var net = require("net"),
    repl = require("repl"),
    fs = require('fs');

var socketPath = "/data/data/nl.sison.android.nodejs.repl/cache/node-repl-sock";
//var socketPath = "/home/me/node-repl-sock";

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
            fs.unlinkSync(socketPath);
            process.exit();
        });
    }
});

server.listen(socketPath, function() { //'listening' listener
    console.log('server bound');
});
