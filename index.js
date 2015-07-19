function getUniqueId(){
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8);
        return v.toString(16);
    });
}

function getRandomInt(min, max) {
    return Math.floor(Math.random() * (max - min)) + min;
}

var app = require('express')(),
    server = require('http').Server(app),
    io = require('socket.io')(server),
    Rx = require('rx'),
    Mustache = require('mustache'),
    fs = require('fs'),
    R = require('ramda'),
    uniqueIds = R.map(function(){ return getUniqueId(); })(R.range(1,10)),
    fastMap = require('collections/fast-map')();

server.listen(8085);

app.get('/', function (req, res) {
    res.send('lol!');
});
