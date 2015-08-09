var R, concatOrSum, concatOrSumProp, nextIndex;

R = require('ramda');

nextIndex = 0;

concatOrSum = function(xs) {
  if (R.isArrayLike(R.head(xs))) {
    return R.flatten(xs);
  } else {
    return R.sum(xs);
  }
};

concatOrSumProp = function(objs, prop) {
  var result;
  result = {};
  result[prop] = R.compose(concatOrSum, R.filter(R.identity), R.pluck(prop))(objs);
  return result;
};

module.exports = {
  mergeAdd: function(obs) {
    var keys;
    keys = R.compose(R.uniq, R.flatten, R.map(R.keys))(obs);
    return R.compose(R.mergeAll, R.map(R.curry(concatOrSumProp)(obs)))(keys);
  },
  generateDbName: function() {
    var now;
    now = new Date();
    return now.toDateString().split(' ').map(function(str) {
      return str.toLowerCase();
    }).join('-') + '-' + [++nextIndex, 'user-data'].join('-');
  }
};
