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

groupByCorrespondence = R.groupBy (message) ->
  message.correspondenceId

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

  persist: (email, userData) ->
    post
      url: @url
      json: true
      body: R.merge(userData, {new: true, email: email})
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

  getUserData: (email) ->
    userData = {}
    get @url + '/_design/user_data/_view/new_data?key="' + email + '"'
    .bind @
    .then (res) ->
      getBodyFromRes res
    .then (res) ->
      if not res.rows
        {}
      else
        changed = R.compose(
          R.map(R.assoc('new', false)),
          R.pluck('value')
        )(res.rows)
        data = R.map(R.pick(['messages', 'componentRequests']))(changed)
        userData = mergeAdd(data)
        post
          url: @url + '/_bulk_docs'
          json: true
          body:
            docs: changed
    .then ->
      userData
    .catch (err) ->
      console.error 'error reading user data for user: ', email
      console.error err
      throw err

  getAllUserData: ->
    get @url + '/_design/user_data/_view/new_data'
    .bind @
    .then (res) ->
      getBodyFromRes res
    .then (res) ->
      if not res.rows
        []
      else
        R.compose(
          R.map(([email,data]) ->
            data.email = email
            data
          ),
          R.toPairs,
          R.mapObj(R.compose(mergeAdd, R.map(R.dissoc('email')))),
          R.groupBy(R.prop('email')),
          R.map(R.pick(['email','messages','componentRequests'])),
          R.pluck('value')
        )(res.rows)
    .then (userData) ->
      userData.forEach (dataLine) ->
        rearrangedMessages = R.compose(
          R.map((messageGroup) ->
            {
              messageCount: messageGroup.length
              correspondenceUrl: 'http://биржазапчастей.рф' + messageGroup[0].link
              componentRequestName: messageGroup[0].message.componentRequestName
            }
            ),
          R.values,
          groupByCorrespondence
        )(dataLine.messages) if dataLine.messages
        dataLine.messages = rearrangedMessages
      userData
    .catch (err) ->
      console.error 'error getting all user data:'
      console.error err
      throw err

module.exports = Storage
