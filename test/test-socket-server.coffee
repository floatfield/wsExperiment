chai = require 'chai'
spies = require 'chai-spies'
expect = chai.expect
NodeCache = require '../lib/dull-cache'
SocketServer = require '../lib/SocketServer.js'
sinon = require 'sinon'
R = require 'ramda'

getSocketClient = (port) ->
  require('socket.io-client')('ws://localhost:' + port, {
    'force new connection': true
    })

chai.use spies

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

  describe 'Socket Server ', ->

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
      done()
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
      expect(cache.get(23)).not.to.exist
      expect(R.pick(['token', 'messages'], cache.get(18))).to.eql
        token: 'a user token'
        messages: [{text: 'some message goes here', url: 'some/url/here'}]
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      socketClient.on 'message', onMessage

    it 'should remove socket object from cache on disconnect', (done) ->
      validateCache = ->
        expect(cache.get(2).socket).not.to.exist
        done()
      onConnect = ->
        @emit 'token', {userId: 2, token: 'token'}
        clock.tick 20
        @disconnect()
        clock.tick 20
        validateCache()
      socketServer.setUserToken 2, 'token'
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect

    it 'should accept callback to persist expired user data', (done) ->
      expireCallback = (userId, userData)->
        console.log 'do smth'
        # done()
      onConnect = ->
        @emit 'token', {userId: 13, token: 'user token 13'}
        clock.tick 20
        @disconnect()
        clock.tick 20
        expect(@cache.get(13).socket).not.to.exist
        done()
      # good path user disconnected and never came back
      socketServer.setUserToken 13, 'user token 13'
      socketClient1 = getSocketClient port
      socketClient1.on 'connect', onConnect
