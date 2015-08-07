Promise = require 'bluebird'
request = require 'request'
R = require 'ramda'

get = Promise.promisify request.get
post = Promise.promisify request.post
put = Promise.promisify request.put
del = Promise.promisify request.del

getBodyFromRes = (res) ->
  if typeof res[1] == 'string' then JSON.parse(res[1]) else res[1]

mergeAdd = require('./util').mergeAdd

class Storage

  constructor: (dbName) ->
    @url = 'http://localhost:5984/' + dbName

  exists: (docname = '')->
    get @url + docname
    .bind @
    .then (res) ->
      if getBodyFromRes(res).error && getBodyFromRes(res).error == 'not_found'
        false
      else
        true

  createDb: ->
    @exists()
    .then (exists) ->
      if exists
        [{},'{"result": "ok"}']
      else
        put @url
    .then (res) ->
      getBodyFromRes res
    .catch (err) ->
      console.error 'error creating database: ', err

  destroyDb: ->
    @exists()
    .then (exists) ->
      if exists
        del @url
      else
        [{},'{"result": "ok"}']
    .then (res) ->
      getBodyFromRes res
    .catch (err) ->
      console.error 'error destroying database: ', err

  persist: (userId, userData) ->
    post
      url: @url
      json: true
      body: R.merge(userData, {new: true, userId: userId})
    .then (res) ->
      getBodyFromRes(res).id
    .catch (err) ->
      console.error 'error persisting object:'
      console.error err

  persistDesignDocument: (jsonFileName, docName) ->
    designDocument = require jsonFileName
    put
      url: @url + '/_design/' + docName
      json: true
      body: designDocument
    .bind @
    .then (res) ->
      getBodyFromRes(res)
    .catch (err) ->
      console.error 'error persisting design document:'
      console.error err

  getUserData: (userId) ->
    userData = {}
    get @url + '/_design/user_data/_view/new_data?key="' + userId + '"'
    .bind @
    .then (res) ->
      changed = R.compose(
        R.map(R.assoc('new', false)),
        R.pluck('value')
      )(getBodyFromRes(res).rows)
      data = R.map(R.pick(['messages', 'componentRequestCount']))(changed)
      userData = mergeAdd(data)
      post
        url: @url + '/_bulk_docs'
        json: true
        body:
          docs: changed
    .then ->
      userData

  getAllUserData: ->
    undefined

module.exports = Storage