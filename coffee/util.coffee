R = require 'ramda'

nextIndex = 0

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
  generateDbName: ->
    now = new Date()
    now.toDateString().split(' ').map((str) -> str.toLowerCase()).join('-') + '-' + [++nextIndex, 'user-data'].join('-')
  formatDate: (date) ->
    date.toISOString().replace(/T/, ' ').replace(/\..+/, '')
  logObject: (logger, message, object) ->
    logger.log 'info', "#{message} --- %j", object, {
      time: this.formatDate(new Date())
    }
