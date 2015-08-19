var R, SocketServer,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

R = require('ramda');

SocketServer = (function() {
  function SocketServer(config) {
    this.getTokenHandler = bind(this.getTokenHandler, this);
    this.onConnect = bind(this.onConnect, this);
    this.server = require('socket.io')(config.port);
    this.cache = config.cache;
    if (config.storage) {
      this.storage = config.storage;
      this.subscribeToCacheEvents();
    }
    this.server.on('connection', this.onConnect);
  }

  SocketServer.prototype.setUserToken = function(email, token) {
    if (!this.cache.get(email)) {
      this.cache.set(email, {
        token: token,
        messages: [],
        componentRequests: [],
        userWarnings: []
      });
      if (this.storage) {
        return this.storage.getUserData(email).then((function(_this) {
          return function(persistedUserData) {
            return _this.addInfoChunk(email, persistedUserData);
          };
        })(this));
      }
    } else {
      return this.cache.get(email).token = token;
    }
  };

  SocketServer.prototype.subscribeToCacheEvents = function() {
    this.cache.removeAllListeners('expire');
    return this.cache.on('expire', (function(_this) {
      return function(key, value) {
        if (value.socket) {
          return _this.cache.set(key, value);
        } else {
          if (value.messages.length === 0) {
            delete value.messages;
          }
          if (value.componentRequests.length === 0) {
            delete value.componentRequests;
          }
          delete value.userWarnings;
          if (value.messages || value.componentRequests) {
            return _this.storage.persist(key, R.dissoc('token', value));
          }
        }
      };
    })(this));
  };

  SocketServer.prototype.isUserOnline = function(email) {
    return R.contains(String(email), this.cache.keys());
  };

  SocketServer.prototype.sendPendingMessages = function(email) {
    var val;
    val = this.cache.get(email);
    if (val.socket) {
      R.forEach(function(message) {
        return val.socket.emit('message', message);
      })(val.messages);
      val.messages = [];
      R.forEach(function(warning) {
        return val.socket.emit('userWarning', warning);
      })(val.userWarnings);
      val.userWarnings = [];
      if (val.componentRequests.length > 0) {
        val.socket.emit('componentRequests', val.componentRequests.length);
        return val.componentRequests = [];
      }
    }
  };

  SocketServer.prototype.addInfoChunk = function(email, chunk) {
    var messages, requests, val, warnings;
    requests = chunk.componentRequests;
    messages = chunk.messages;
    warnings = chunk.userWarnings;
    if (this.isUserOnline(email)) {
      val = this.cache.get(email);
      if (messages) {
        val.messages = R.concat(val.messages, messages);
      }
      if (requests) {
        val.componentRequests = R.concat(val.componentRequests, requests);
      }
      if (warnings) {
        val.userWarnings = R.concat(val.userWarnings, warnings);
      }
      return this.sendPendingMessages(email);
    } else {
      return this.cache.set(email, {
        messages: messages ? messages : [],
        componentRequests: requests ? requests : [],
        userWarnings: warnings ? warnings : []
      });
    }
  };

  SocketServer.prototype.sendInterlocutorBlockedNotification = function(email, correspondenceId) {
    var val;
    val = this.cache.get(email);
    if (val && val.socket) {
      return val.socket.emit('interlocutorBlocked', correspondenceId);
    }
  };

  SocketServer.prototype.sendMessage = function(email, message) {
    return this.addInfoChunk(email, {
      messages: [message]
    });
  };

  SocketServer.prototype.sendComponentRequests = function(email, componentRequests) {
    return this.addInfoChunk(email, {
      componentRequests: componentRequests
    });
  };

  SocketServer.prototype.sendWarning = function(email, message) {
    return this.addInfoChunk(email, {
      userWarnings: [message]
    });
  };

  SocketServer.prototype.onConnect = function(socket) {
    return socket.on('token', this.getTokenHandler(socket));
  };

  SocketServer.prototype.getTokenHandler = function(socket) {
    return (function(_this) {
      return function(credentials) {
        var cachedToken, email, token, val;
        email = credentials.email;
        cachedToken = _this.cache.get(email) ? _this.cache.get(email).token : void 0;
        token = credentials.token;
        if (cachedToken && cachedToken === token) {
          val = _this.cache.get(email);
          val.socket = socket;
          _this.sendPendingMessages(email);
          return socket.on('disconnect', function() {
            return delete _this.cache.get(email).socket;
          });
        } else {
          return _this.cache.ttl(email, 0);
        }
      };
    })(this);
  };

  SocketServer.prototype.setStorage = function(storage) {
    this.storage = storage;
    return this.subscribeToCacheEvents();
  };

  return SocketServer;

})();

module.exports = SocketServer;
