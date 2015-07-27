R = require 'ramda'
EventEmitter = require('events').EventEmitter

class DullCache extends EventEmitter

  constructor: (config) ->
    @stdTTL = config.stdTTL || 3000
    @entries = {}

  getExpireCallback: (key, value) ->
    () =>
      @emit 'expire', key, value
      @del key

  set: (key, value, ttl) ->
    key = String(key)
    timeToLive = ttl || @stdTTL
    @entries[key] =
      value: value
      timeout: setTimeout @getExpireCallback(key, value), timeToLive
    @entries[key].ttl = ttl if ttl

  get: (key) ->
    key = String(key)
    val = @entries[key]
    if val?
      timeToLive = if @entries[key].ttl then @entries[key].ttl else @stdTTL
      clearTimeout val.timeout
      val.timeout = setTimeout @getExpireCallback(key, val.value), timeToLive
      val.value
    else
      undefined

  keys: ->
    R.keys(@entries)

  del: (key) ->
    key = String(key)
    clearTimeout(@entries[key].timeout) if @entries[key]
    @entries = R.dissoc key, @entries

  ttl: (key, ttl) ->
    key = String(key)
    val = @entries[key]
    if val?
      clearTimeout val.timeout
      val.timeout = setTimeout @getExpireCallback(key, val.value), ttl


module.exports = DullCache
