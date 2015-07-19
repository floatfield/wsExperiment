R = require 'ramda'
EventEmitter = require('events').EventEmitter

class DullCache extends EventEmitter
  constructor: (config) ->
    @stdTTL = config.stdTTL || 3000
    @checkPeriod = config.checkPeriod || 4000
    @entries = {}
    setInterval @checkExpired, @checkPeriod
  checkExpired: =>
    isExpired = (v) ->
      v.expiresAt <= now
    emitExpired = (pair) =>
      @emit 'expire', pair[0], pair[1].value
    now = Date.now()
    R.forEach(emitExpired)(R.toPairs(R.pickBy(isExpired, @entries)))
    @entries = R.pickBy(R.complement(isExpired), @entries)
  set: (key, value, ttl) ->
    ttl = ttl || @stdTTL
    @entries[key] =
      expiresAt: Date.now() + ttl
      value: value
  get: (key) ->
    val = @entries[key]
    if val?
      val.expiresAt = Date.now() + @stdTTL
      val.value
    else
      undefined
  keys: ->
    R.keys(@entries)
  del: (key) ->
    @entries = R.dissoc key, @entries
  ttl: (key, ttl) ->
    @entries[key].expiresAt = Date.now() + ttl

module.exports = DullCache
