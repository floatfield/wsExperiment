R = require 'ramda'

class SocketServer

  constructor: (config) ->
    @server = require('socket.io')(config.port)
    @cache = config.cache
    if config.storage
      @storage = config.storage
      @subscribeToCacheEvents()
    @server.on 'connection', @onConnect

  setUserToken: (email, token) ->
    if not @cache.get(email)
      @cache.set email, {token: token, messages: [], componentRequests: [], userWarnings: []}
      if @storage
        @storage.getUserData(email).then((persistedUserData) => @addInfoChunk email, persistedUserData)
    else
      @cache.get(email).token = token

  subscribeToCacheEvents: ->
    @cache.removeAllListeners('expire')
    @cache.on 'expire', (key, value) =>
      if value.socket
        @cache.set key, value
      else
        delete value.messages if value.messages.length == 0
        delete value.componentRequests if value.componentRequests.length == 0
        delete value.userWarnings
        @storage.persist(key, R.dissoc('token', value)) if value.messages or value.componentRequests

  isUserOnline: (email) ->
    R.contains String(email), @cache.keys()

  sendPendingMessages: (email) ->
    val = @cache.get email
    if val.socket
      R.forEach((message) -> val.socket.emit('message', message))(val.messages)
      val.messages = []
      R.forEach((warning) -> val.socket.emit('userWarning', warning))(val.userWarnings)
      val.userWarnings = []
      if val.componentRequests.length > 0
        val.socket.emit 'componentRequests', val.componentRequests.length
        val.componentRequests = []

  addInfoChunk: (email, chunk) ->
    requests = chunk.componentRequests
    messages = chunk.messages
    warnings = chunk.userWarnings
    if @isUserOnline email
      val = @cache.get email
      val.messages = R.concat(val.messages, messages) if messages
      val.componentRequests = R.concat(val.componentRequests, requests) if requests
      val.userWarnings = R.concat(val.userWarnings, warnings) if warnings
      @sendPendingMessages email
    else
      @cache.set email,
        messages: if messages then messages else []
        componentRequests: if requests then requests else []
        userWarnings: if warnings then warnings else []

  sendMessage: (email, message) ->
    @addInfoChunk email, {messages: [message]}

  sendComponentRequests: (email, componentRequests) ->
    @addInfoChunk email, {componentRequests: componentRequests}

  sendWarning: (email, message) ->
    @addInfoChunk email, {userWarnings: [message]}

  onConnect: (socket) =>
    socket.on 'token', @getTokenHandler(socket)

  getTokenHandler: (socket) =>
    (credentials) =>
      email = credentials.email
      cachedToken = if @cache.get(email) then @cache.get(email).token else undefined
      token = credentials.token
      if cachedToken and cachedToken == token
        val = @cache.get email
        val.socket = socket
        @sendPendingMessages email
        socket.on 'disconnect', =>
          delete @cache.get(email).socket
      else
        @cache.ttl(email, 0)

  setStorage: (@storage) ->
    @subscribeToCacheEvents()

module.exports = SocketServer
