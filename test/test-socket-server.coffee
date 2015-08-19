chai = require 'chai'
expect = chai.expect
NodeCache = require '../lib/dull-cache'
SocketServer = require '../lib/SocketServer'
sinon = require 'sinon'
R = require 'ramda'
Promise = require 'promise'
Storage = require '../lib/storage'

getSocketClient = (port) ->
  require('socket.io-client')('ws://localhost:' + port, {
    'force new connection': true
    })

describe 'Socket server test suite', ->
  socketServer = {}
  clock = {}
  port = 9090
  cache = new NodeCache
    stdTTL: 500
  storage = {}

  beforeEach () ->
    socketServer = new SocketServer
      port: ++port
      cache: cache
    clock = sinon.useFakeTimers()
    userObjects =
      'some21@example.org':
        messages: [{text: 'some text', path: 'some/path'}]
      'some22@example.org':
        messages: [{text: 'yet another text', path: 'another/path'}, {text: 'an', path: 'll'}]
      'some27@example.org':
        messages: [{text: 'text 27 times', url: 'some/27/goes/here'}]
      'some28@example.org':
        componentRequestCount: [{data: 'data1'},{data: 'data2'},{data: 'data3'},{data: 'data4'}]
      'some30@example.org':
        messages: [{text: 'yet another text', path: 'another/path'}, {text: 'an', path: 'll'}]
        componentRequests: [{data: 'data1'},{data: 'data2'},{data: 'data3'}]
    storage =
      persist: (email, userData) ->
      getUserData: (email) ->
        new Promise((resolve, reject) ->
          resolve(userObjects[String(email)])
        )

  afterEach () ->
    clock.restore()
    storage = {}

  describe 'Socket Server', ->

    it 'should be able to be created', ->
      expect(socketServer).to.be.an('object')

    it 'should be able to accept multiple incoming connections', (done) ->
      connections = 0
      onConnect = ->
        connections++
        done() if connections == 2
      socketClient1 = getSocketClient port
      socketClient2 = getSocketClient port
      socketClient1.on 'connect', onConnect
      socketClient2.on 'connect', onConnect

    it 'should populate applied cache with received user credentials', ->
      socketServer.setUserToken 'some@example.org', 'some token'
      expect(cache.get('some@example.org')).to.exist
      clock.tick 510
      expect(cache.get('some@example.org')).not.to.exist

    it 'should remove user record from cache when wrong token from client received', (done) ->
      validateCache = ->
        expect(cache.get('some@example.org')).not.to.exist
        done()
      onConnect = ->
        @emit 'token', {email: 'some@example.org', token: 'another token'}
      socketServer.setUserToken 'some@example.org', 'some token'
      expect(cache.get('some@example.org')).to.exist
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      clock.restore()
      setTimeout validateCache, 100

    it 'should be able to report whether the user is online / or was online recently', ->
      socketServer.setUserToken 'some@example.org', 'user token'
      expect(socketServer.isUserOnline('some@example.org')).to.be.true

    it 'should send messages to connected users or store them in cache', (done) ->
      email1 = 'some@example.org'
      email2 = 'some1@example.org'
      onConnect = ->
        @emit 'token', {email: email1, token: 'a user token'}
      onMessage = (message) ->
        expect(message).to.eql({text: 'some message goes here', url: 'some/url/here'})
        expect(R.pick(['token', 'messages'], cache.get(email1))).to.eql
          token: 'a user token'
          messages: []
        done()
      socketServer.setUserToken email1, 'a user token'
      socketServer.sendMessage email1, {text: 'some message goes here', url: 'some/url/here'}
      socketServer.sendMessage email2, {text: 'another message here', url: 'another/path/here'}
      expect(R.pick(['token', 'messages'], cache.get(email2))).to.eql
        messages: [{text: 'another message here', url: 'another/path/here'}]
      expect(R.pick(['token', 'messages'], cache.get(email1))).to.eql
        token: 'a user token'
        messages: [{text: 'some message goes here', url: 'some/url/here'}]
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      socketClient.on 'message', onMessage

    it 'should accept storage object to persist expired user data', (done) ->
      sinon.spy(storage, 'persist')
      email1 = 'some12@example.org'
      socketServer.setStorage storage
      socketServer.setUserToken email1, 'a token'
      socketServer.sendMessage email1, {text: 'some text', url: 'some/path'}
      socketServer.sendMessage email1, {text: 'another text', url: 'another/path'}
      expect(R.pick(['token', 'messages'],cache.get(email1))).to.eql
        token: 'a token'
        messages: [{text: 'some text', url: 'some/path'}, {text: 'another text', url: 'another/path'}]
      clock.tick 500
      spyCall = storage.persist.getCall(0)
      expect(spyCall.calledWith(email1, {messages: [{text: 'some text', url: 'some/path'}, {text: 'another text', url: 'another/path'}]})).to.be.true
      done()

    it 'should populate user object on token event using supplied storage object', (done) ->
      clock.restore()
      email1 = 'some21@example.org'
      email2 = 'some22@example.org'
      onConnect = ->
        expect(R.pick(['token', 'messages'],cache.get(email1))).to.eql
          token: 'some token'
          messages: [{text: 'some text', path: 'some/path'}]
        @emit 'token', {email: email1, token: 'some token'}
      onMessage = (message) ->
        expect(message).to.eql({text: 'some text', path: 'some/path'})
      validateCache = ->
        expect(R.pick(['token', 'messages'], cache.get(email2))).to.eql
          token: 'another token'
          messages: [{text: 'yet another text', path: 'another/path'}, {text: 'an', path: 'll'}]
        done()
      socketServer.setStorage storage
      socketServer.setUserToken email1, 'some token'
      socketServer.setUserToken email2, 'another token'
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      socketClient.on 'message', onMessage
      setTimeout validateCache, 150

    it 'should persist all pending messages if client sent wrong token', (done) ->
      sinon.spy(storage, 'persist')
      email1 = 'some25@example.org'
      onConnect = ->
        @emit 'token', {email: email1, token: 'wrong token'}
      socketServer.setStorage storage
      socketServer.setUserToken email1, 'a token'
      socketServer.sendMessage email1, {text: 'some text', url: 'some/path/goes/here'}
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      clock.tick 500
      spyCall = storage.persist.getCall(0)
      expect(spyCall.calledWith(email1, {messages: [{text: 'some text', url: 'some/path/goes/here'}]})).to.be.true
      done()

    it 'should persist incoming messages if user is not online', (done) ->
      sinon.spy(storage, 'persist')
      email1 = 'some26@example.org'
      socketServer.setStorage storage
      socketServer.sendMessage email1, {text: 'some text', url: 'soome/path/goes/here'}
      clock.tick 500
      spyCall = storage.persist.getCall(0)
      expect(spyCall.calledWith(email1, {messages: [{text: 'some text', url: 'soome/path/goes/here'}]})).to.be.true
      done()

    it 'should be able to pass storage object via constrctor config parameter', (done) ->
      clock.restore()
      sinon.spy(storage, 'persist')
      email1 = 'some27@example.org'
      validate = ->
        spyCall = storage.persist.getCall(0)
        expect(spyCall.calledWith(email1, {messages: [{text: 'text 27 times', url: 'some/27/goes/here'}]})).to.be.true
        done()
      onConnect = ->
        @emit 'token', {email: email1, token: 'wrong token'}
      someNewCache = new NodeCache
        stdTTL: 500
      someNewServer = new SocketServer
        port: ++port
        cache: someNewCache
        storage: storage
      someClient = getSocketClient port
      someNewServer.setUserToken email1, 'a token'
      someClient.on 'connect', onConnect
      setTimeout validate, 500

    it 'should be able to deliver new component requests count', (done) ->
      clock.restore()
      sinon.spy(storage, 'persist')
      email1 = 'some28@example.org'
      email2 = 'some30@example.org'
      validate = ->
        spyCall = storage.persist.getCall(0)
        expect(spyCall.calledWith(email2, {
          messages: [{text: 'yet another text', path: 'another/path'}, {text: 'an', path: 'll'}]
          componentRequests: [{data: 'data1'},{data: 'data2'},{data: 'data3'},{data: 'data1'},{data: 'data2'},{data: 'data3'}]
        })).to.be.true
        done()
      onConnect = ->
        @emit 'token', {email: email1, token: 'token28'}
      onComponentRequest = (componentRequestCount) ->
        expect(componentRequestCount).to.eql(4)
      socketServer.setStorage storage
      socketServer.setUserToken email1, 'token28'
      socketServer.setUserToken email2, 'token30'
      socketServer.sendComponentRequests email2, [{data: 'data1'},{data: 'data2'},{data: 'data3'}]
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      socketClient.on 'componentRequest', onComponentRequest
      setTimeout validate, 600

    it 'should not persist empty messages and component request counts', (done) ->
      clock.restore()
      email1 = 'some29@example.org'
      mock = sinon.mock(storage)
      mock.expects('persist').never()
      onConnect = ->
        @emit 'token', {email: email1, token: 'some token'}
      socketServer.setStorage storage
      socketServer.setUserToken email1, 'some token'
      socketServer.sendMessage email1, {text: 'some text', path: 'some/path'}
      socketServer.sendComponentRequests email1, [{data: 'data'}]
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      setTimeout(( ->
        mock.verify()
        done()
        ), 600)

    it 'should be able to send a warning to user and not to store it in database', (done) ->
      clock.restore()
      email1 = 'some@example.org'
      email2 = 'another@example.org'
      mock = sinon.mock(storage)
      mock.expects('persist').never()
      onConnect = ->
        @emit 'token', {email: email1, token: 'aToken'}
      onWarning = (message) ->
        expect(message).to.eql('some warning goes here')
      socketServer.setStorage storage
      socketServer.setUserToken email1, 'aToken'
      socketServer.setUserToken email2, 'theToken'
      socketServer.sendWarning email1, 'some warning goes here'
      socketServer.sendWarning email2, 'another warning'
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      socketClient.on 'userWarning', onWarning
      setTimeout(( ->
        mock.verify()
        done()
      ),600)

    it 'should be able to send notification to a user that his interlocutor is blocked', (done) ->
      clock.restore()
      email1 = 'some654@example.org'
      mock = sinon.mock(storage)
      mock.expects('persist').never()
      onConnect = ->
        @emit 'token', {email: email1, token: 'aToken'}
      blockedCallback = sinon.spy()
      socketServer.setStorage storage
      socketServer.setUserToken email1, 'aToken'
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      socketClient.on 'interlocutorBlocked', blockedCallback
      setTimeout(( ->
        socketServer.sendInterlocutorBlockedNotification(email1, 25)
      ), 200)
      setTimeout((->
        mock.verify()
        expect(blockedCallback.calledWith(25)).to.be.true
        done()
      ), 600)
