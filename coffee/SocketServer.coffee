R = require 'ramda'

class SocketServer

  constructor: (config) ->
    @server = require('socket.io')(config.port)
    @cache = config.cache
    @server.on 'connection', @onConnect

  setUserToken: (userId, token) ->
    @cache.set userId, {token: token, messages: []}

  isUserOnline: (userId) ->
    R.contains String(userId), @cache.keys()

  sendPendingMessages: (userId) ->
    val = @cache.get userId
    if val.socket
      R.forEach((message) ->
        val.socket.emit('message', message))(val.messages)
      val.messages = []

  sendMessage: (userId, message) ->
    if @isUserOnline(userId)
      val = @cache.get userId
      val.messages.push message
      @sendPendingMessages userId

  onConnect: (socket) =>
    socket.on 'token', @getTokenHandler(socket)

  getTokenHandler: (socket) =>
    (credentials) =>
      userId = credentials.userId
      cachedToken = @cache.get(userId).token
      token = credentials.token
      if cachedToken == token
        val = @cache.get userId
        val.socket = socket
        @sendPendingMessages userId
      else
        @cache.del(userId)

module.exports = SocketServer
