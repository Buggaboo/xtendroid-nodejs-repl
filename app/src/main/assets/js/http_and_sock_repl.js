/*
 * https://gist.github.com/TooTallNate/2053342
 * Requires node v0.7.7 or greater.
 *
 * TODO - create knock knock diffie-hellman
 *
 * To connect: $ curl -sSNT. localhost:8000
 */
 var android = require('android');
 console.log = function (msg) { android.logcat.d('http_and_sock_repl.js', msg); }

var http = require('http'),
    repl = require('repl'),
    util = require('util'),
    buf0 = new Buffer([0]),
    TAG = 'http_and_sock_repl.js';

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

connect with LocalServerSocket sensors:

    var net = require('net');
    var conn = net.createConnection('/data/data/nl.sison.android.nodejs.repl/cache/sensor_sockets/TYPE_ALL.sock');
    conn.on('connect', function() { console.log('connected to unix socket server');});
    conn.on('data', function () { console.log(data) });

get file descriptor, if non-abstract:

    var fd = fs.openSync('/data/data/nl.sison.android.nodejs.repl/cache/sensor_sockets/TYPE_ALL.sock', 'r');
 */

var net = require("net"),
    fs = require('fs');

// TODO refactor out hard coded path and replace with:
// var socketPath = process.argv[2]
var socketPath = "/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock";

if (fs.existsSync(socketPath))
{
    fs.unlinkSync(socketPath);
}

var socket_server = net.createServer(function(socket) { //'connection' listener
    console.log(util.format('server connected: %j', socket.address()));

    socket.on ('connect', function () {

    });

    repl.start({
        prompt: "node via Unix socket> ",
        input: socket,
        output: socket,
    }).on('exit', function() {
        console.log('repl shutdown');
        socket.end();
    });

/*
    // WTF would you want this?
    socket.setTimeout(60000, function () {
        socket.destroy();
        if (fs.existsSync(socketPath))
        {
            fs.unlinkSync(socketPath);
        }
    });
*/

});

socket_server.on('data', function (data) {
    console.log('data: ' + data);
    console.log('bytes read: ' + socket.bytesRead);
    console.log('bytes written: ' + socket.bytesWritten);
});

socket_server.on('end', function() {
    console.log('server disconnected');
    if (fs.existsSync(socketPath))
    {
        fs.unlinkSync(socketPath);
    }
});

socket_server.listen(socketPath, function() {
    console.log('server bound');
});


socket_server.on('error', function (e) {
    if (e.code == 'EADDRINUSE') {
        var clientSocket = new net.Socket();
        clientSocket.on('error', function(e) { // handle error trying to talk to server
            if (e.code == 'ECONNREFUSED') {  // No other server listening
                if (fs.existsSync(socketPath))
                {
                    fs.unlinkSync(socketPath);
                }
                socket_server.listen(socketPath, function() { //'listening' listener
                    console.log('server recovered');
                });
            }
        });
/*
        clientSocket.connect({path: socketPath}, function() {
            console.log('Server running, giving up...');
//            fs.unlinkSync(socketPath); // TODO review if this is actually what you need
            process.exit();
        });
*/
    }
});


/**
 * test baked in logcat
 */
/*
var util = require('util'),
    android = require('android');

var logcat = android.logcat,
    android_logcat = android.android_logcat;

var TAG = 'script.js';

android_logcat(3, TAG, util.format('%s: %j', 'json', { 'a' : 'b' }));
android_logcat(4, TAG, util.format('%s: %j', 'json', { 'a' : 'b' }));

logcat.d(TAG, util.format('%s: %j', 'json', { 'c' : 'd' }));
logcat.i(TAG, util.format('%s: %j', 'json', { 'c' : 'd' }));
*/