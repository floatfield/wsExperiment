class SocketServer

  constructor: (config) ->
    @server = require('socket.io')(config.port)
    @cache = config.cache
    @server.on 'connection', @onConnect

  setUserToken: (userId, token) ->
    @cache.set userId, {token: token}

  sendMessage: (userId, message) ->
    console.log 'do the stuff'

  onConnect: (socket) =>
    socket.on 'token', @getTokenHandler(socket)

  getTokenHandler: (socket) =>
    (credentials) =>
      userId = credentials.userId
      cachedToken = @cache.get(userId).token
      token = credentials.token
      @cache.del(userId) unless cachedToken == token

module.exports = SocketServer
