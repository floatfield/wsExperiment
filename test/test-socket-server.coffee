chai = require 'chai'
expect = chai.expect
NodeCache = require '../lib/dull-cache'
SocketServer = require '../lib/SocketServer'
sinon = require 'sinon'
R = require 'ramda'
Promise = require 'promise'

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

  beforeEach () ->
    socketServer = new SocketServer
      port: ++port
      cache: cache
    clock = sinon.useFakeTimers()

  afterEach () ->
    clock.restore()

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
      socketServer.setUserToken 12, 'some token'
      expect(cache.get(12)).to.exist
      clock.tick 510
      expect(cache.get(12)).not.to.exist

    it 'should remove user record from cache when wrong token from client received', (done) ->
      validateCache = ->
        expect(cache.get(15)).not.to.exist
        done()
      onConnect = ->
        @emit 'token', {userId: 15, token: 'another token'}
      socketServer.setUserToken 15, 'some token'
      expect(cache.get(15)).to.exist
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      clock.restore()
      setTimeout validateCache, 100

    it 'should be able to report whether the user is online / or was online recently', ->
      socketServer.setUserToken 34, 'user token'
      expect(socketServer.isUserOnline(34)).to.be.true

    it 'should send messages to connected users or store them in cache', (done) ->
      onConnect = ->
        @emit 'token', {userId: 18, token: 'a user token'}
      onMessage = (message) ->
        expect(message).to.eql({text: 'some message goes here', url: 'some/url/here'})
        expect(R.pick(['token', 'messages'], cache.get(18))).to.eql
          token: 'a user token'
          messages: []
        done()
      socketServer.setUserToken 18, 'a user token'
      socketServer.sendMessage 18, {text: 'some message goes here', url: 'some/url/here'}
      socketServer.sendMessage 23, {text: 'another message here', url: 'another/path/here'}
      expect(R.pick(['token', 'messages'], cache.get(23))).to.eql
        messages: [{text: 'another message here', url: 'another/path/here'}]
      expect(R.pick(['token', 'messages'], cache.get(18))).to.eql
        token: 'a user token'
        messages: [{text: 'some message goes here', url: 'some/url/here'}]
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      socketClient.on 'message', onMessage

    it 'should accept callback to persist expired user data', (done) ->
      onExpire = (userId, userData) ->
        expect(userId).to.eql('12')
        expect(userData).to.eql
          messages: [{text: 'some text', url: 'some/path'}, {text: 'another text', url: 'another/path'}]
        done()
      socketServer.setExpireCallback onExpire
      socketServer.setUserToken 12, 'a token'
      socketServer.sendMessage 12, {text: 'some text', url: 'some/path'}
      socketServer.sendMessage 12, {text: 'another text', url: 'another/path'}
      expect(R.pick(['token', 'messages'],cache.get(12))).to.eql
        token: 'a token'
        messages: [{text: 'some text', url: 'some/path'}, {text: 'another text', url: 'another/path'}]
      clock.tick 500

    it 'should populate user object on token event using supplied callback', (done) ->
      clock.restore()
      userObjects =
        '21':
          messages: [{text: 'some text', path: 'some/path'}]
        '22':
          messages: [{text: 'yet another text', path: 'another/path'}, {text: 'an', path: 'll'}]
      getUserData = (userId) ->
        new Promise((resolve, reject) ->
          resolve(userObjects[String(userId)])
          )
      onConnect = ->
        expect(R.pick(['token', 'messages'],cache.get(21))).to.eql
          token: 'some token'
          messages: [{text: 'some text', path: 'some/path'}]
        @emit 'token', {userId: 21, token: 'some token'}
      onMessage = (message) ->
        expect(message).to.eql({text: 'some text', path: 'some/path'})
      validateCache = ->
        expect(R.pick(['token', 'messages'], cache.get(22))).to.eql
          token: 'another token'
          messages: [{text: 'yet another text', path: 'another/path'}, {text: 'an', path: 'll'}]
        done()
      socketServer.setPopulateCallback(getUserData)
      socketServer.setUserToken 21, 'some token'
      socketServer.setUserToken 22, 'another token'
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      socketClient.on 'message', onMessage
      setTimeout validateCache, 150

    it 'should persist all pending messages if client sent wrong token', (done) ->
      clock.restore()
      onExpire = (userId, userData) ->
        if userId == '25'
          expect(userData).to.eql
            messages: [{text: 'some text', url: 'some/path/goes/here'}]
          done()
      onConnect = ->
        @emit 'token', {userId: 25, token: 'wrong token'}
      socketServer.setExpireCallback onExpire
      socketServer.setUserToken 25, 'a token'
      socketServer.sendMessage 25, {text: 'some text', url: 'some/path/goes/here'}
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect

    it 'should persist incoming messages if user is not online', (done) ->
      clock.restore()
      onExpire = (userId, userData) ->
        if userId == '26'
          expect(userData).to.eql
            messages: [{text: 'some text', url: 'some/path/goes/here'}]
          done()
      socketServer.setExpireCallback onExpire
      socketServer.sendMessage 26, {text: 'some text', url: 'some/path/goes/here'}

    it 'should be able to pass callbacks via constrctor config parameter', (done) ->
      clock.restore()
      onExpire = (userId, userData) ->
        if userId == '27'
          expect(userData).to.eql
            messages: [{text: 'text 27 times', url: 'some/27/goes/here'}]
          done()
      getUserData = (userId) ->
        userObjects =
          '27':
            messages: [{text: 'text 27 times', url: 'some/27/goes/here'}]
          '22':
            messages: [{text: 'yet another text', path: 'another/path'}, {text: 'an', path: 'll'}]
        new Promise((resolve, reject) ->
          resolve(userObjects[String(userId)])
          )
      onConnect = ->
        @emit 'token', {userId: 27, token: 'wrong token'}
      someNewCache = new NodeCache
        stdTTL: 500
      someNewServer = new SocketServer
        port: ++port
        cache: someNewCache
        onExpire: onExpire
        getUserData: getUserData
      someClient = getSocketClient port
      someNewServer.setUserToken 27, 'a token'
      someClient.on 'connect', onConnect

    it 'should be able to deliver new component requests count', (done) ->
      clock.restore()
      getUserData = (userId) ->
        userObjects =
          '28':
            componentRequestCount: 10
          '30':
            messages: [{text: 'yet another text', path: 'another/path'}, {text: 'an', path: 'll'}]
            componentRequestCount: 15
        new Promise((resolve, reject) ->
          resolve(userObjects[String(userId)])
          )
      onExpire = (userId, userData) ->
        if userId == '30'
          expect(userData).to.eql
            messages: [{text: 'yet another text', path: 'another/path'}, {text: 'an', path: 'll'}]
            componentRequestCount: 30
          done()
      onConnect = ->
        @emit 'token', {userId: 28, token: 'token28'}
      onComponentRequest = (componentRequestCount) ->
        expect(componentRequestCount).to.eql(10)
      socketServer.setExpireCallback onExpire
      socketServer.setPopulateCallback getUserData
      socketServer.setUserToken 28, 'token28'
      socketServer.setUserToken 30, 'token30'
      socketServer.sendComponentRequestCount 30, 15
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      socketClient.on 'componentRequest', onComponentRequest

    it 'should not persist empty messages and component request counts', (done) ->
      onExpire = (userId, userData) -> return
      onConnect = ->
        @emit 'token', {userId: 29, token: 'some token'}
      clock.restore()
      expireSpy = sinon.spy(onExpire)
      socketServer.setExpireCallback expireSpy
      socketServer.setUserToken 29, 'some token'
      socketServer.sendMessage 29, {text: 'some text', path: 'some/path'}
      socketServer.sendComponentRequestCount 29, 10
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      setTimeout(( ->
        expect(expireSpy.withArgs('29').callCount).to.eql(0)
        done()
        ), 600)
