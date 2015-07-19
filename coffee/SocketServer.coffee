class SocketServer

  constructor: (config) ->
    @server = require('socket.io')(config.port)
    @cache = config.cache
    @server.on 'connection', @onConnect

  setUserToken: (userId, token) ->
    @cache.set userId, {token: token}

  onConnect: (socket) =>
    socket.on 'token', @onToken

  onToken: (credentials) =>
    userId = credentials.userId
    cachedToken = @cache.get(userId).token
    token = credentials.token
    @cache.del(userId) unless cachedToken == token
    console.log 'cahce keys: ', @cache.keys()

module.exports = SocketServer
