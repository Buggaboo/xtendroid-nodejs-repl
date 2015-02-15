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

var httpReplServer = http.createServer(function(req, res) {
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
httpReplServer.listen(8000)