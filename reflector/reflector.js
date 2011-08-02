/*

openssl genrsa -out privatekey.pem 1024 
openssl req -new -key privatekey.pem -out certrequest.csr 
openssl x509 -req -in certrequest.csr -signkey privatekey.pem -out certificate.pem

A challenge password []:fooo

openssl s_client -connect localhost:7000 -crlf

*/

var secret = "password"
var serverVersion = "1";
var net = require("net");
var fs = require("fs");
var tls = require('tls');

require("./prototypes.js");

var options = {
    key: fs.readFileSync('privatekey.pem'),
    cert: fs.readFileSync('certificate.pem')
};

function Client(stream) {
    this.name = null;
    this.stream = stream;
    this.authenticated = false;
}

var clients = [];

var server = tls.createServer(options, function (stream) {
    
    console.log("New Client");
    
    var client = new Client(stream);
    clients.push(client);
    
    stream.setTimeout(0);
    stream.setEncoding("utf8");
    
    stream.addListener("connect", function () {
        console.log("Connection");
    });
    
    stream.addListener("timeout", function () {
        console.log("Timeout!");
    });
    
    /*
    stream.addListener("drain", function () {
        console.log("drain!");
    });
    */
    
    stream.addListener("error", function (exception) {
        console.log("exception!");
        console.log(exception);
    });
    stream.addListener("data", function (data) {
        
        console.log(data);
        
        if (!client.authenticated) {
            if (data.startsWith("PASS ")) {
                console.log("PASS!");
                
                var clientPass = data.substring(5, data.length).stripNewline();
                
                console.log("Got password '" + clientPass + "'");
                if (clientPass == secret) {
                    client.authenticated = true;
                    stream.write("OKAUTH v" + serverVersion + " (Welcome!)\r\n");
                }
                else {
                    stream.write("BADAUTH v" + serverVersion + "\r\n");
                }
                
                return;
            }
            else {
                stream.write("BADAUTH v" + serverVersion + "\r\n");
            }
            return;
        }
        
        /*
        if (client.name == null) {
            client.name = data.match(/\S+/);
            stream.write("===========\n");
            clients.forEach(function(c) {
                if (c != client) {
                    c.stream.write(client.name + " has joined.\n");
                }
            });
            return;
        }
        
        var command = data.match(/^\/(.*)/);
        if (command) {
            if (command[1] == 'users') {
                clients.forEach(function(c) {
                    stream.write("- " + c.name + "\n");
                });
            }
            else if (command[1] == 'quit') {
                stream.end();
            }
            return;
        }
        */
        
        clients.forEach(function(c) {
            if (c != client) {
                try {
                    c.stream.write(data);
                }
                catch(err) {
                    console.log("Got error writing to stream!");
                    console.log(err);
                    c.stream.end();
                    clients.remove(c);
                }
            }
        });
    });
    
    stream.addListener("end", function() {
        clients.remove(client);
        stream.end();
    });
    
    stream.addListener("close", function (had_error) {
        console.log("close! had_error: " + had_error);
    });
});

server.on('error', function (e) {
    console.log("Got error!");
    console.log(e);
});

server.listen(7000, function () {
  address = server.address();
  console.log("Listening on port %j", address.port);
});