var Rx = require('rx'),
  util = require('util'),
  EventEmitter = require('events').EventEmitter,
  socketServer = require('socket.io')(9090),
  TokenManager = function(){
    EventEmitter.call(this);
    this.ids = require('collections/fast-map')();
  },
  manager = new TokenManager(),
  clientTokenStream = Rx.Observable.fromEventPattern(function (h) {
    socketServer.on('connection', h);
  }).flatMap(function (socket) {
    return Rx.Observable.fromEvent(socket, 'token');
  });

util.inherits(TokenManager, EventEmitter);

TokenManager.prototype.addToken = function (id, token) {
  this.ids.set(id, token);
  this.emit('new token', {
    id: id,
    token: token
  });
};

TokenManager.prototype.removeToken = function (id) {
  this.ids.delete(id);
};
