R = require 'ramda'

concatOrSum = (xs) ->
  if R.isArrayLike(R.head(xs)) then R.flatten(xs) else R.sum(xs)

concatOrSumProp = (objs, prop) ->
  result = {}
  result[prop] = R.compose(concatOrSum, R.filter(R.identity), R.pluck(prop))(objs)
  result

module.exports =
  mergeAdd: (obs) ->
    keys = R.compose(
      R.uniq,
      R.flatten,
      R.map(R.keys)
    )(obs)
    R.compose(
      R.mergeAll,
      R.map(R.curry(concatOrSumProp)(obs))
    )(keys)
