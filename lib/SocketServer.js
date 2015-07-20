var SocketServer,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

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
      token: token
    });
  };

  SocketServer.prototype.sendMessage = function(userId, message) {
    return console.log('send message');
  };

  SocketServer.prototype.onConnect = function(socket) {
    return socket.on('token', this.getTokenHandler(socket));
  };

  SocketServer.prototype.getTokenHandler = function(socket) {
    return (function(_this) {
      return function(credentials) {
        var cachedToken, token, userId;
        userId = credentials.userId;
        cachedToken = _this.cache.get(userId).token;
        token = credentials.token;
        if (cachedToken !== token) {
          return _this.cache.del(userId);
        }
      };
    })(this);
  };

  return SocketServer;

})();

module.exports = SocketServer;
