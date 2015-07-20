var DullCache, EventEmitter, R,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

R = require('ramda');

EventEmitter = require('events').EventEmitter;

DullCache = (function(superClass) {
  extend(DullCache, superClass);

  function DullCache(config) {
    this.stdTTL = config.stdTTL || 3000;
    this.entries = {};
  }

  DullCache.prototype.getExpireCallback = function(key, value) {
    this.emit('expire', key, value);
    return (function(_this) {
      return function() {
        return _this.del(key);
      };
    })(this);
  };

  DullCache.prototype.set = function(key, value, ttl) {
    var timeToLive;
    key = String(key);
    timeToLive = ttl || this.stdTTL;
    this.entries[key] = {
      value: value,
      timeout: setTimeout(this.getExpireCallback(key, value), timeToLive)
    };
    if (ttl) {
      return this.entries[key].ttl = ttl;
    }
  };

  DullCache.prototype.get = function(key) {
    var timeToLive, val;
    key = String(key);
    val = this.entries[key];
    if (val != null) {
      timeToLive = this.entries[key].ttl ? this.entries[key].ttl : this.stdTTL;
      clearTimeout(val.timeout);
      val.timeout = setTimeout(this.getExpireCallback(key, val.value), timeToLive);
      return val.value;
    } else {
      return void 0;
    }
  };

  DullCache.prototype.keys = function() {
    return R.keys(this.entries);
  };

  DullCache.prototype.del = function(key) {
    key = String(key);
    if (this.entries[key]) {
      clearTimeout(this.entries[key].timeout);
    }
    return this.entries = R.dissoc(key, this.entries);
  };

  DullCache.prototype.ttl = function(key, ttl) {
    var val;
    key = String(key);
    val = this.entries[key];
    if (val != null) {
      clearTimeout(val.timeout);
      return val.timeout = setTimeout(this.getExpireCallback(key, val.value), ttl);
    }
  };

  return DullCache;

})(EventEmitter);

module.exports = DullCache;
