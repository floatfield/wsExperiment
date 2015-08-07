chai = require 'chai'
expect = chai.expect
sinon = require 'sinon'
R = require 'ramda'
Promise = require 'bluebird'
cradle = require 'cradle'
Storage = require '../lib/storage'

describe 'User data persist/populate test suite', ->
  dbName = 'test-user-data-store'
  storage = new Storage(dbName)
  connection = new(cradle.Connection)()
  db = connection.database(dbName)
  get = Promise.promisify db.get, db
  save = Promise.promisify db.save, db
  remove = Promise.promisify db.remove, db

  before ->
    storage.createDb()
    .then ->
      storage.persistDesignDocument '../design_documents/find_new_user_data.json', 'user_data'

  after ->
    storage.destroyDb()

  describe 'store user data', ->

    it 'should be able to check if database exists', (done) ->
      storage.exists()
      .then (exists) ->
        expect(exists).to.be.true
      .then ->
        anotherStorage = new Storage('not-existent-name')
        anotherStorage.exists()
      .then (exists) ->
        expect(exists).to.be.false
        done()

    it 'should be able to create database with given name', (done) ->
      checkDbExistance = ->
        anotherDb = connection.database 'another-db-name-for-testing-purpose'
        anotherDb.exists (err, yep) ->
          expect(err).to.be.null
          expect(yep).to.be.true
          done()
      anotherStorage = new Storage('another-db-name-for-testing-purpose')
      anotherStorage.createDb()
      .then (res) ->
        checkDbExistance()

    it 'should be able to remove database with given name', (done) ->
      checkDbExistance = ->
        anotherDb = connection.database 'another-db-name-for-testing-purpose'
        anotherDb.exists (err, yep) ->
          expect(err).to.be.null
          expect(yep).to.be.false
          done()
      anotherStorage = new Storage('another-db-name-for-testing-purpose')
      anotherStorage.createDb()
      .then ->
        anotherStorage.destroyDb()
      .then ->
        checkDbExistance()

    it 'should be able to store a chunk of user data', (done) ->
      userData =
        messages: [{text: 'some text', path: 'some/path'}]
      storage.persist('39', userData)
      .then (storedId) ->
        db.get storedId, (err, doc) ->
          expect(err).to.be.null
          persistedObject = R.pick ['userId', 'new', 'messages'], doc
          expectedObject = R.merge(userData, {new: true, userId: '39'})
          expect(persistedObject).to.eql(expectedObject)
          done()

    it 'should be able to store design document', (done) ->
      storage.persistDesignDocument '../design_documents/test_purpose_dd.json', 'test'
      .then ->
        db.get '_design/test', (err, doc) ->
          expect(err).to.be.null
          done()

    it 'should be able to get all new user data chunks and mark them as old', (done) ->
      userData1 =
        messages: [{text: 'message1', path: 'some/path'}]
      userData2 =
        messages: [{text: 'message2', path: 'another/path'}]
        componentRequestCount: 2
      storedIds = []
      storage.persist '32', userData1
      .then (id) ->
        storedIds.push id
      .then ->
        storage.persist '32', userData2
      .then (id)->
        storedIds.push id
        storage.getUserData '32'
      .then (userData) ->
        expect(userData).to.eql
          messages: R.concat userData1.messages, userData2.messages
          componentRequestCount: 2
        get storedIds
      .then (data) ->
        isAnyUnreadDoc = R.compose(
          R.any(R.identity)
          R.pluck('new'),
          R.pluck('doc')
        )(data)
        expect(isAnyUnreadDoc).to.be.false
      .catch (err) ->
        expect(err).to.be.null
      .finally ->
        done()

    it 'should be able to get all the user data', (done) ->
      userData1 =
        messages: [{text: 'message1', path: 'some/path'}]
      userData2 =
        messages: [{text: 'message2', path: 'another/path'}]
        componentRequestCount: 2
      userData3 =
        componentRequestCount: 4
      userData4 =
        messages: [{text: 'message3', path: 'some/path3'}]
      storage.persist '23', userData1
      .then ->
        storage.persist '23', userData2
      .then ->
        storage.persist '3', userData3
      .then ->
        storage.persist '31', userData4
      .then ->
        storage.getAllUserData()
      .then (allData) ->
        expect(allData).to.eql
