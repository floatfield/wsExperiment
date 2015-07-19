var SocketServer, onIoServerConnection, onToken,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

onIoServerConnection = function(socket) {
  return console.log('connected');
};

onToken = function(userCredentials) {
  var token, userId;
  userId = userCredentials.userId;
  return token = userCredentials.token;
};

SocketServer = (function() {
  function SocketServer(config) {
    this.onToken = bind(this.onToken, this);
    this.onConnect = bind(this.onConnect, this);
    this.server = require('socket.io')(config.port);
    this.cache = config.cache;
    this.server.on('connection', this.onConnect);
  }

  SocketServer.prototype.setUserToken = function(userId, token) {
    return this.cache.set(userId, token);
  };

  SocketServer.prototype.onConnect = function(socket) {
    return socket.on('token', this.onToken);
  };

  SocketServer.prototype.onToken = function(credentials) {
    var cachedToken, token, userId;
    console.log(this.cache.get(credentials.userId));
    console.log(this.cache.data['15']);
    userId = credentials.userId;
    cachedToken = this.cache.get(String(userId));
    token = credentials.token;
    if (cachedToken !== token) {
      return this.cache.ttl(userId, 0);
    }
  };

  return SocketServer;

})();

module.exports = SocketServer;
