const http = require("http");

((async () => {
    http.createServer((req, res) => {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('okay');
    }).listen(80, "0.0.0.0");
}))();
http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('not okay');
}).listen(5480, "0.0.0.0");

