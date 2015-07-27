var R, SocketServer,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

R = require('ramda');

SocketServer = (function() {
  function SocketServer(config) {
    this.setPopulateCallback = bind(this.setPopulateCallback, this);
    this.getTokenHandler = bind(this.getTokenHandler, this);
    this.onConnect = bind(this.onConnect, this);
    this.server = require('socket.io')(config.port);
    this.cache = config.cache;
    this.server.on('connection', this.onConnect);
    if (config.getUserData) {
      this.getUserData = config.getUserData;
    }
    if (config.onExpire) {
      this.setExpireCallback(config.onExpire);
    }
  }

  SocketServer.prototype.setUserToken = function(userId, token) {
    if (!this.cache.get(userId)) {
      this.cache.set(userId, {
        token: token,
        messages: [],
        componentRequestCount: 0
      });
      if (this.getUserData) {
        return this.getUserData(userId).then((function(_this) {
          return function(persistedUserData) {
            return _this.addInfoChunk(userId, persistedUserData);
          };
        })(this));
      }
    } else {
      return this.cache.get(userId).token = token;
    }
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
      val.messages = [];
      if (val.componentRequestCount > 0) {
        val.socket.emit('componentRequests', val.componentRequestCount);
        return val.componentRequestCount = 0;
      }
    }
  };

  SocketServer.prototype.addInfoChunk = function(userId, chunk) {
    var count, messages, val;
    count = chunk.componentRequestCount;
    messages = chunk.messages;
    if (this.isUserOnline(userId)) {
      val = this.cache.get(userId);
      if (messages) {
        val.messages = R.concat(val.messages, messages);
      }
      if (count) {
        val.componentRequestCount += count;
      }
      return this.sendPendingMessages(userId);
    } else {
      return this.cache.set(userId, {
        messages: messages ? messages : [],
        componentRequestCount: count ? count : 0
      });
    }
  };

  SocketServer.prototype.sendMessage = function(userId, message) {
    return this.addInfoChunk(userId, {
      messages: [message]
    });
  };

  SocketServer.prototype.sendComponentRequestCount = function(userId, count) {
    return this.addInfoChunk(userId, {
      componentRequestCount: count
    });
  };

  SocketServer.prototype.onConnect = function(socket) {
    return socket.on('token', this.getTokenHandler(socket));
  };

  SocketServer.prototype.getTokenHandler = function(socket) {
    return (function(_this) {
      return function(credentials) {
        var cachedToken, token, userId, val;
        userId = credentials.userId;
        cachedToken = _this.cache.get(userId) ? _this.cache.get(userId).token : void 0;
        token = credentials.token;
        if (cachedToken && cachedToken === token) {
          val = _this.cache.get(userId);
          val.socket = socket;
          _this.sendPendingMessages(userId);
          return socket.on('disconnect', function() {
            return delete _this.cache.get(userId).socket;
          });
        } else {
          return _this.cache.ttl(userId, 0);
        }
      };
    })(this);
  };

  SocketServer.prototype.setExpireCallback = function(fn) {
    this.cache.removeAllListeners('expire');
    return this.cache.on('expire', function(key, value) {
      return fn(key, R.dissoc('token', value));
    });
  };

  SocketServer.prototype.setPopulateCallback = function(fn) {
    return this.getUserData = fn;
  };

  return SocketServer;

})();

module.exports = SocketServer;
