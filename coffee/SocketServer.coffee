R = require 'ramda'

class SocketServer

  constructor: (config) ->
    @server = require('socket.io')(config.port)
    @cache = config.cache
    @server.on 'connection', @onConnect
    @getUserData = config.getUserData if config.getUserData
    @setExpireCallback config.onExpire if config.onExpire

  setUserToken: (userId, token) ->
    if not @cache.get(userId)
      @cache.set userId, {token: token, messages: [], componentRequestCount: 0}
      if @getUserData
        @getUserData(userId).then((persistedUserData) => @addInfoChunk userId, persistedUserData)
    else
      @cache.get(userId).token = token

  isUserOnline: (userId) ->
    R.contains String(userId), @cache.keys()

  sendPendingMessages: (userId) ->
    val = @cache.get userId
    if val.socket
      R.forEach((message) -> val.socket.emit('message', message))(val.messages)
      val.messages = []
      if val.componentRequestCount > 0
        val.socket.emit 'componentRequests', val.componentRequestCount
        val.componentRequestCount = 0

  addInfoChunk: (userId, chunk) ->
    count = chunk.componentRequestCount
    messages = chunk.messages
    if @isUserOnline userId
      val = @cache.get userId
      val.messages = R.concat(val.messages, messages) if messages
      val.componentRequestCount += count if count
      @sendPendingMessages userId
    else
      @cache.set userId,
        messages: if messages then messages else []
        componentRequestCount: if count then count else 0

  sendMessage: (userId, message) ->
    @addInfoChunk userId, {messages: [message]}

  sendComponentRequestCount: (userId, count) ->
    @addInfoChunk userId, {componentRequestCount: count}

  onConnect: (socket) =>
    socket.on 'token', @getTokenHandler(socket)

  getTokenHandler: (socket) =>
    (credentials) =>
      userId = credentials.userId
      cachedToken = if @cache.get(userId) then @cache.get(userId).token else undefined
      token = credentials.token
      if cachedToken and cachedToken == token
        val = @cache.get userId
        val.socket = socket
        @sendPendingMessages userId
        socket.on 'disconnect', =>
          delete @cache.get(userId).socket
      else
        @cache.ttl(userId, 0)

  setExpireCallback: (fn) ->
    @cache.removeAllListeners('expire')
    @cache.on 'expire', (key, value) ->
      delete value.messages if value.messages.length == 0
      delete value.componentRequestCount if value.componentRequestCount == 0
      fn(key, R.dissoc('token', value)) if value.messages or value.componentRequestCount

  setPopulateCallback: (fn) =>
    @getUserData = fn

module.exports = SocketServer
