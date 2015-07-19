var SocketServer,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

SocketServer = (function() {
  function SocketServer(config) {
    this.onToken = bind(this.onToken, this);
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

  SocketServer.prototype.onConnect = function(socket) {
    return socket.on('token', this.onToken);
  };

  SocketServer.prototype.onToken = function(credentials) {
    var cachedToken, token, userId;
    userId = credentials.userId;
    cachedToken = this.cache.get(userId).token;
    token = credentials.token;
    if (cachedToken !== token) {
      this.cache.del(userId);
    }
    return console.log('cahce keys: ', this.cache.keys());
  };

  return SocketServer;

})();

module.exports = SocketServer;
