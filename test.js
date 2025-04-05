const http = require("http");

((async () => {
    http.createServer((req, res) => res.end()).listen(6942);
}))();

http.createServer((req, res) => res.end()).listen(6943);

