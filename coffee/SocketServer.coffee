onIoServerConnection = (socket) ->
  console.log 'connected'

onToken = (userCredentials) ->
  userId = userCredentials.userId
  token = userCredentials.token


class SocketServer
  constructor: (config) ->
    @server = require('socket.io')(config.port)
    @cache = config.cache
    @server.on 'connection', @onConnect
  setUserToken: (userId, token) ->
    @cache.set userId, token
  onConnect: (socket) =>
    socket.on 'token', @onToken
  onToken: (credentials) =>
    console.log @cache.get(credentials.userId)
    console.log @cache.data['15']
    userId = credentials.userId
    cachedToken = @cache.get(String(userId))
    token = credentials.token
    @cache.ttl(userId, 0) unless cachedToken == token

module.exports = SocketServer
