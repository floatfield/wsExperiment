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
      .catch (err) ->
        throw err
      .finally ->
        done()

    it 'should be able to create database with given name', (done) ->
      checkDbExistance = ->
        anotherDb = connection.database 'another-db-name-for-testing-purpose'
        anotherDb.exists (err, yep) ->
          expect(err).to.be.null
          expect(yep).to.be.true
      anotherStorage = new Storage('another-db-name-for-testing-purpose')
      anotherStorage.createDb()
      .then (res) ->
        checkDbExistance()
      .catch (err) ->
        throw err
      .finally ->
        done()

    it 'should be able to remove database with given name', (done) ->
      checkDbExistance = ->
        anotherDb = connection.database 'another-db-name-for-testing-purpose'
        anotherDb.exists (err, yep) ->
          expect(err).to.be.null
          expect(yep).to.be.false
      anotherStorage = new Storage('another-db-name-for-testing-purpose')
      anotherStorage.createDb()
      .then ->
        anotherStorage.destroyDb()
      .then ->
        checkDbExistance()
      .catch (err) ->
        throw err
      .finally ->
        done()

    it 'should be able to store a chunk of user data', (done) ->
      userData =
        messages: [{text: 'some text', path: 'some/path'}]
      storage.persist('some@example.org', userData)
      .then (storedId) ->
        db.get storedId, (err, doc) ->
          expect(err).to.be.null
          persistedObject = R.pick ['email', 'new', 'messages'], doc
          expectedObject = R.merge(userData, {new: true, email: 'some@example.org'})
          expect(persistedObject).to.eql(expectedObject)
      .catch (err) ->
        throw err
      .finally ->
        done()

    it 'should be able to store design document', (done) ->
      storage.persistDesignDocument '../design_documents/test_purpose_dd.json', 'test'
      .then ->
        db.get '_design/test', (err, doc) ->
          expect(err).to.be.null
      .catch (err) ->
        throw err
      .finally ->
        done()

    it 'should be able to get all new user data chunks and mark them as old', (done) ->
      userData1 =
        messages: [{text: 'message1', path: 'some/path'}]
      userData2 =
        messages: [{text: 'message2', path: 'another/path'}]
        componentRequests: [{someData: 'some data for component requeset'},{anotherData: 'another'}]
      storedIds = []
      storage.persist 'some1@example.org', userData1
      .then (id) ->
        storedIds.push id
      .then ->
        storage.persist 'some1@example.org', userData2
      .then (id)->
        storedIds.push id
        storage.getUserData 'some1@example.org'
      .then (userData) ->
        expect(userData).to.eql
          messages: R.concat userData1.messages, userData2.messages
          componentRequests: [{someData: 'some data for component requeset'},{anotherData: 'another'}]
        get storedIds
      .then (data) ->
        isAnyUnreadDoc = R.compose(
          R.any(R.identity)
          R.pluck('new'),
          R.pluck('doc')
        )(data)
        expect(isAnyUnreadDoc).to.be.false
      .catch (err) ->
        throw err
      .finally ->
        done()

    it 'should be able to store and find user data by email address', (done) ->
      userData =
        messages: [{text: 'message2', path: 'another/path'}]
        componentRequests: [{data: 'some data'}]
      storage.persist 'some@example.org', userData
      .then (id) ->
        storage.getUserData 'some@example.org'
      .then (userData) ->
        expect(userData).to.eql(userData)
      .catch (err) ->
        throw err
      .finally ->
        done()

    it 'should be able to get all the user data', (done) ->
      userData1 =
        messages: [{text: 'message1', path: 'some/path'}]
      userData2 =
        messages: [{text: 'message2', path: 'another/path'}]
        componentRequests: [{data: 'data1'},{data: 'data2'},{data: 'data3'}]
      userData3 =
        componentRequests: [{data: 'data1'},{data: 'data2'},{data: 'data3'}]
      userData4 =
        messages: [{text: 'message3', path: 'some/path3'}]
      userData5 =
        messages: [{text: 'message11', path: 'some/path453'}]
      storage.persist 'some11@example.org', userData1
      .then ->
        storage.persist 'some12@example.org', userData2
      .then ->
        storage.persist 'some13@example.org', userData3
      .then ->
        storage.persist 'some13@example.org', userData4
      .then ->
        storage.persist 'some14@example.org', userData5
      .then ->
        storage.getUserData 'some14@example.org'
      .then ->
        storage.getAllUserData()
      .then (allData) ->
        expect(allData).to.eql([
          {
            email: 'some11@example.org'
            messages: [{text: 'message1', path: 'some/path'}]
          },
          {
            email: 'some12@example.org'
            messages: [{text: 'message2', path: 'another/path'}]
            componentRequests: [{data: 'data1'},{data: 'data2'},{data: 'data3'}]
          },
          {
            email: 'some13@example.org'
            messages: [{text: 'message3', path: 'some/path3'}]
            componentRequests: [{data: 'data1'},{data: 'data2'},{data: 'data3'}]
          }
        ])
      .catch (err) ->
        throw err
      .finally ->
        done()

    it 'should not return any data if there is no any', (done) ->
      anotherStorage = new Storage('empty-database')
      anotherStorage.createDb()
      .then ->
        anotherStorage.persistDesignDocument '../design_documents/find_new_user_data.json', 'test'
      .then ->
        anotherStorage.getAllUserData()
      .then (data) ->
        expect(data).to.be.empty
      .then ->
        anotherStorage.destroyDb()
      .catch (err) ->
        throw err
      .finally ->
        done()

    it 'should not return any data if there is no new data', (done) ->
      anotherStorage = new Storage('empty-database')
      anotherStorage.createDb()
      .then ->
        anotherStorage.persistDesignDocument '../design_documents/find_new_user_data.json', 'test'
      .then ->
        anotherStorage.persist 'some_one@example.org', {data: 'lol'}
      .then ->
        anotherStorage.getUserData 'some_one@example.org'
      .then ->
        anotherStorage.getAllUserData()
      .then (data) ->
        expect(data).to.be.empty
      .then ->
        anotherStorage.destroyDb()
      .catch (err) ->
        throw err
      .finally ->
        done()
