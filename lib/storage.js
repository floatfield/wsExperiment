var Promise, R, Storage, del, get, getBodyFromRes, groupByCorrespondence, mergeAdd, post, put, request;

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

groupByCorrespondence = R.groupBy(function(message) {
  return message.correspondenceId;
});

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

  Storage.prototype.persist = function(email, userData) {
    return post({
      url: this.url,
      json: true,
      body: R.merge(userData, {
        "new": true,
        email: email
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

  Storage.prototype.getUserData = function(email) {
    var userData;
    userData = {};
    return get(this.url + '/_design/user_data/_view/new_data?key="' + email + '"').bind(this).then(function(res) {
      return getBodyFromRes(res);
    }).then(function(res) {
      var changed, data;
      if (!res.rows) {
        return {};
      } else {
        changed = R.compose(R.map(R.assoc('new', false)), R.pluck('value'))(res.rows);
        data = R.map(R.pick(['messages', 'componentRequests']))(changed);
        userData = mergeAdd(data);
        return post({
          url: this.url + '/_bulk_docs',
          json: true,
          body: {
            docs: changed
          }
        });
      }
    }).then(function() {
      return userData;
    })["catch"](function(err) {
      console.error('error reading user data for user: ', email);
      console.error(err);
      throw err;
    });
  };

  Storage.prototype.getAllUserData = function() {
    return get(this.url + '/_design/user_data/_view/new_data').bind(this).then(function(res) {
      return getBodyFromRes(res);
    }).then(function(res) {
      if (!res.rows) {
        return [];
      } else {
        return R.compose(R.map(function(arg) {
          var data, email;
          email = arg[0], data = arg[1];
          data.email = email;
          return data;
        }), R.toPairs, R.mapObj(R.compose(mergeAdd, R.map(R.dissoc('email')))), R.groupBy(R.prop('email')), R.map(R.pick(['email', 'messages', 'componentRequests'])), R.pluck('value'))(res.rows);
      }
    }).then(function(userData) {
      userData.forEach(function(dataLine) {
        var rearrangedMessages;
        if (dataLine.messages) {
          rearrangedMessages = R.compose(R.map(function(messageGroup) {
            return {
              messageCount: messageGroup.length,
              correspondenceUrl: 'http://биржазапчастей.рф' + messageGroup[0].link,
              componentRequestName: messageGroup[0].message.componentRequestName
            };
          }), R.values, groupByCorrespondence)(dataLine.messages);
        }
        return dataLine.messages = rearrangedMessages;
      });
      return userData;
    })["catch"](function(err) {
      console.error('error getting all user data:');
      console.error(err);
      throw err;
    });
  };

  return Storage;

})();

module.exports = Storage;
