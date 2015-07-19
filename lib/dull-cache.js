var DullCache, EventEmitter, R,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

R = require('ramda');

EventEmitter = require('events').EventEmitter;

DullCache = (function(superClass) {
  extend(DullCache, superClass);

  function DullCache(config) {
    this.checkExpired = bind(this.checkExpired, this);
    this.stdTTL = config.stdTTL || 3000;
    this.checkPeriod = config.checkPeriod || 4000;
    this.entries = {};
    setInterval(this.checkExpired, this.checkPeriod);
  }

  DullCache.prototype.checkExpired = function() {
    var emitExpired, isExpired, now;
    isExpired = function(v) {
      return v.expiresAt <= now;
    };
    emitExpired = (function(_this) {
      return function(pair) {
        return _this.emit('expire', pair[0], pair[1].value);
      };
    })(this);
    now = Date.now();
    R.forEach(emitExpired)(R.toPairs(R.pickBy(isExpired, this.entries)));
    return this.entries = R.pickBy(R.complement(isExpired), this.entries);
  };

  DullCache.prototype.set = function(key, value, ttl) {
    ttl = ttl || this.stdTTL;
    return this.entries[key] = {
      expiresAt: Date.now() + ttl,
      value: value
    };
  };

  DullCache.prototype.get = function(key) {
    var val;
    val = this.entries[key];
    if (val != null) {
      val.expiresAt = Date.now() + this.stdTTL;
      return val.value;
    } else {
      return void 0;
    }
  };

  DullCache.prototype.keys = function() {
    return R.keys(this.entries);
  };

  DullCache.prototype.del = function(key) {
    return this.entries = R.dissoc(key, this.entries);
  };

  DullCache.prototype.ttl = function(key, ttl) {
    return this.entries[key].expiresAt = Date.now() + ttl;
  };

  return DullCache;

})(EventEmitter);

module.exports = DullCache;
