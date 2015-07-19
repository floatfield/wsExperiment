function onIoServerConnection(socket) {}

function socketServer(config) {
  var ioSocketServer = {
    setUserToken: function(userId, token) {
      this.cache.set(userId, token);
    }
  };

  ioSocketServer.server = require('socket.io')(config.port);
  ioSocketServer.cache = config.cache || new require('node-cache')({
    stdTTL: 120,
    checkPeriod: 140
  });
  ioSocketServer.server.on('connection', onIoServerConnection);

  return ioSocketServer;
}

module.exports = socketServer;
