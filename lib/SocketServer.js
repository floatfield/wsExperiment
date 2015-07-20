var R, SocketServer,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

R = require('ramda');

SocketServer = (function() {
  function SocketServer(config) {
    this.getTokenHandler = bind(this.getTokenHandler, this);
    this.onConnect = bind(this.onConnect, this);
    this.server = require('socket.io')(config.port);
    this.cache = config.cache;
    this.server.on('connection', this.onConnect);
  }

  SocketServer.prototype.setUserToken = function(userId, token) {
    return this.cache.set(userId, {
      token: token,
      messages: []
    });
  };

  SocketServer.prototype.isUserOnline = function(userId) {
    return R.contains(String(userId), this.cache.keys());
  };

  SocketServer.prototype.sendPendingMessages = function(userId) {
    var val;
    val = this.cache.get(userId);
    if (val.socket) {
      R.forEach(function(message) {
        return val.socket.emit('message', message);
      })(val.messages);
      return val.messages = [];
    }
  };

  SocketServer.prototype.sendMessage = function(userId, message) {
    var val;
    if (this.isUserOnline(userId)) {
      val = this.cache.get(userId);
      val.messages.push(message);
      return this.sendPendingMessages(userId);
    }
  };

  SocketServer.prototype.onConnect = function(socket) {
    return socket.on('token', this.getTokenHandler(socket));
  };

  SocketServer.prototype.getTokenHandler = function(socket) {
    return (function(_this) {
      return function(credentials) {
        var cachedToken, token, userId, val;
        userId = credentials.userId;
        cachedToken = _this.cache.get(userId).token;
        token = credentials.token;
        if (cachedToken === token) {
          val = _this.cache.get(userId);
          val.socket = socket;
          return _this.sendPendingMessages(userId);
        } else {
          return _this.cache.del(userId);
        }
      };
    })(this);
  };

  return SocketServer;

})();

module.exports = SocketServer;
