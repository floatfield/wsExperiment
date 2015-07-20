chai = require 'chai'
expect = chai.expect
sinon = require 'sinon'
DullCache = require '../lib/dull-cache'
R = require 'ramda'

describe 'Dull cache test suit', ->
  clock = {}
  cache = {}

  before () ->
    clock = sinon.useFakeTimers()

  after () ->
    clock.restore()

  beforeEach () ->
    cache = new DullCache({stdTTL: 3000})

  describe 'Dull cache', ->
    it 'should be able to store values by keys and delete them', ->
      cache.set 'bar', 'baz'
      expect(cache.get('bar')).to.eql('baz')
      cache.del 'bar'
      expect(cache.get('bar')).not.to.exist
      cache.set 'foo', 'bar'
      clock.tick 2500
      expect(cache.get('foo')).to.eql('bar')
      clock.tick 2500
      expect(cache.get('foo')).to.eql('bar')
      clock.tick 4100
      expect(cache.get('foo')).to.not.exist
    it 'should remove expired keys', ->
      keys = R.map((i) ->
        key = 'key' + i
        cache.set key, 'value' + i
        key)(R.range(1,10))
      expect(keys).to.eql(cache.keys())
      clock.tick 41000
      expect(cache.keys()).to.be.empty
    it 'should execute supplied callback before removing expired key', (done) ->
      onExpire = (key, value) ->
        expect(key).to.eql('foo')
        expect(value).to.eql('bar')
        done()
      cache.on 'expire', onExpire
      cache.set 'foo', 'bar'
      clock.tick 4000
    it 'should be able to set TTL for an entry', ->
      cache.set 'foo', 'bar'
      cache.ttl 'foo', 8000
      clock.tick 7800
      expect(cache.get('foo')).to.eql('bar')
    it 'should be able to preserve ttl which was applied via "set" method', ->
      cache.set 'foo', 'bar', 10000
      clock.tick 9800
      expect(cache.get('foo')).to.eql('bar')
      clock.tick 9800
      expect(cache.get('foo')).to.eql('bar')
