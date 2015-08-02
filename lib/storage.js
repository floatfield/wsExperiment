var Promise, R, Storage, del, get, getBodyFromRes, mergeAdd, post, put, request;

Promise = require('bluebird');

request = require('request');

R = require('ramda');

get = Promise.promisify(request.get);

post = Promise.promisify(request.post);

put = Promise.promisify(request.put);

del = Promise.promisify(request.del);

getBodyFromRes = function(res) {
  if (typeof res[1] === 'string') {
    return JSON.parse(res[1]);
  } else {
    return res[1];
  }
};

mergeAdd = require('./util').mergeAdd;

Storage = (function() {
  function Storage(dbName) {
    this.url = 'http://localhost:5984/' + dbName;
  }

  Storage.prototype.exists = function(docname) {
    if (docname == null) {
      docname = '';
    }
    return get(this.url + docname).bind(this).then(function(res) {
      if (getBodyFromRes(res).error && getBodyFromRes(res).error === 'not_found') {
        return false;
      } else {
        return true;
      }
    });
  };

  Storage.prototype.createDb = function() {
    return this.exists().then(function(exists) {
      if (exists) {
        return [{}, '{"result": "ok"}'];
      } else {
        return put(this.url);
      }
    }).then(function(res) {
      return getBodyFromRes(res);
    })["catch"](function(err) {
      return console.error('error creating database: ', err);
    });
  };

  Storage.prototype.destroyDb = function() {
    return this.exists().then(function(exists) {
      if (exists) {
        return del(this.url);
      } else {
        return [{}, '{"result": "ok"}'];
      }
    }).then(function(res) {
      return getBodyFromRes(res);
    })["catch"](function(err) {
      return console.error('error destroying database: ', err);
    });
  };

  Storage.prototype.persist = function(userId, userData) {
    return post({
      url: this.url,
      json: true,
      body: R.merge(userData, {
        "new": true,
        userId: userId
      })
    }).then(function(res) {
      return getBodyFromRes(res).id;
    })["catch"](function(err) {
      console.error('error persisting object:');
      return console.error(err);
    });
  };

  Storage.prototype.persistDesignDocument = function(jsonFileName, docName) {
    var designDocument;
    designDocument = require(jsonFileName);
    return put({
      url: this.url + '/_design/' + docName,
      json: true,
      body: designDocument
    }).bind(this).then(function(res) {
      return getBodyFromRes(res);
    })["catch"](function(err) {
      console.error('error persisting design document:');
      return console.error(err);
    });
  };

  Storage.prototype.getUserData = function(userId) {
    var userData;
    userData = {};
    return get(this.url + '/_design/user_data/_view/new_data?key="' + userId + '"').bind(this).then(function(res) {
      var changed, data;
      changed = R.compose(R.map(R.assoc('new', false)), R.pluck('value'))(getBodyFromRes(res).rows);
      data = R.map(R.pick(['messages', 'componentRequestCount']))(changed);
      userData = mergeAdd(data);
      return post({
        url: this.url + '/_bulk_docs',
        json: true,
        body: {
          docs: changed
        }
      });
    }).then(function() {
      return userData;
    });
  };

  Storage.prototype.removeUserData = function(userId) {};

  return Storage;

})();

module.exports = Storage;
