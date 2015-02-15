var net  = require('net'),
    repl = require('repl');

var socketPath = "\0abstract.sock";

var server = net.createServer(function(socket) {
  console.log('client connected');

  socket.on('data', function(data) {
    console.log(data.toString('UTF-8'));
  });

});

server.listen(socketPath);

var socket = net.createConnection({path:socketPath}, function () {
  repl.start({
    prompt: "node via Unix socket xxxxxxx> ",
    input: socket,
    output: socket
  }).on('exit', function() {
    socket.end();
  });
});

//var socketPath = '/home/me/server-replified-client.sock';
//var socketPath = '/data/data/nl.sison.android.nodejs.repl/cache/node-repl-x.sock';

// abstract #0
var socket = net.createConnection({path:"\\0abstract"}, function () {
  repl.start({
    prompt: "node via Unix socket xxxxxxx> ",
    input: socket,
    output: socket
  }).on('exit', function() {
    socket.end();
  });
});

// abstract #1
var socket = net.createConnection({path:"\0abstract"}, function () {
  repl.start({
    prompt: "node via Unix socket xxxxxxx> ",
    input: socket,
    output: socket
  }).on('exit', function() {
    socket.end();
  });
});

// fs #0
var socket = net.createConnection({path:'/data/data/nl.sison.android.nodejs.repl/cache/repl.sock'}, function () {
  repl.start({
    prompt: "node via Unix socket xxxxxxx> ",
    input: socket,
    output: socket
  }).on('exit', function() {
    socket.end();
  });
});