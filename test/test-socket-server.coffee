chai = require 'chai'
spies = require 'chai-spies'
expect = chai.expect
NodeCache = require '../lib/dull-cache'
SocketServer = require '../lib/SocketServer.js'
sinon = require 'sinon'

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

    it 'should send messages to connected users or store them in cache', (done) ->
      onConnect = ->
        @emit 'token', {userId: 18, token: 'a user token'}
      onMessage = (message) ->
        expect(message).to.eql({text: 'some message goes here', url: 'some/url/here'})
        expect(cache.get(18)).to.eql
          token: 'a user token'
          messages: []
      socketServer.setUserToken 18, 'a user token'
      socketServer.sendMessage 18, {text: 'some message goes here', url: 'some/url/here'}
      expect(cache.get(18)).to.eql
        token: 'a user token'
        messages: [{text: 'some message goes here', url: 'some/url/here'}]
      socketClient = getSocketClient port
      socketClient.on 'connect', onConnect
      socketClient.on 'message', onMessage
