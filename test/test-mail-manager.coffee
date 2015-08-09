chai = require 'chai'
expect = chai.expect
Mailer = require '../lib/mailer'
MailManager = require '../lib/mail-manager'
sinon = require 'sinon'
R = require 'ramda'
Promise = require 'promise'
nodemailer = require 'nodemailer'
Storage = require '../lib/storage'

describe 'MailManager test suite', ->

  mailManager = {}
  mailer = {}
  storage = new Storage('test-user-data-store')

  before ->
    storage.createDb()
    .then ->
      storage.persistDesignDocument '../design_documents/find_new_user_data.json', 'user_data'

  after ->
    storage.destroyDb()

  beforeEach ->
    stubTransport = require('nodemailer-stub-transport')
    transporter = nodemailer.createTransport(stubTransport())
    mailer = new Mailer
      templatesDir: '../templates'
      transporter: transporter
    mailManager = new MailManager
      mailer: mailer
      sender: 'jane.doe@example.org'

  describe '#sendPassword()', ->

    it 'should be able to send a password letter to a user', (done) ->
      email = 'some@example.org'
      password = 'some_pass_goes_here'
      mailManager.sendPasswordLetter email, password
      .then (res) ->
        expect(res.envelope).to.eql
          to: ['some@example.org']
          from: 'jane.doe@example.org'
      .catch (err) ->
        throw err
      .finally ->
        done()

  describe '#sendPasswordRestorationLetter()', ->

    it 'should be able to send a password restoration letter to a user', (done) ->
      email = 'john.doe@example.org'
      link = 'http://restore.expample.org/restore/your/password'
      mailManager.sendPasswordRestorationLetter email, link
      .then (res) ->
        expect(res.envelope).to.eql
          to: ['john.doe@example.org']
          from: 'jane.doe@example.org'
      .catch (err) ->
        throw err
      .finally ->
        done()

    it 'should be able to support debug "to" email address and send letters there', (done) ->
      anotherManager = new MailManager
        mailer: mailer
        sender: 'jane.doe@example.org'
        debugRecipient: 'bromshveiger@gmail.com'
      email = 'john.doe@example.org'
      link = 'http://restore.expample.org/restore/your/password'
      anotherManager.sendPasswordRestorationLetter email, link
      .then (res) ->
        expect(res.envelope).to.eql
          to: ['bromshveiger@gmail.com']
          from: 'jane.doe@example.org'
      .finally ->
        done()

  describe '#sendUserNotificationLetter()', ->

    it 'should be able to send a user notification letter', (done) ->
      email = 'john.daewoo@example.org'
      text = 'oh no-no!'
      mailManager.sendUserNotificationLetter email, text
      .then (res) ->
        expect(res.envelope).to.eql
          to: [email]
          from: 'jane.doe@example.org'
      .catch (err) ->
        throw err
      .finally ->
        done()

  describe '#notifyMailingList()', ->

    it 'should be able to send all the new storage data to corresponding emails', (done) ->
      mailManager.setStorage storage
      emails = ['some111@example.org','some121@example.org','some131@example.org']
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
      storage.persist 'some111@example.org', userData1
      .then ->
        storage.persist 'some121@example.org', userData2
      .then ->
        storage.persist 'some131@example.org', userData3
      .then ->
        storage.persist 'some131@example.org', userData4
      .then ->
        storage.persist 'some141@example.org', userData5
      .then ->
        storage.getUserData 'some141@example.org'
      .then ->
        mailManager.notifyMailingList()
      .then (res) ->
        R.forEach( (result) ->
          expect(emails).to.include.members(result.envelope.to)
          expect(result.envelope.from).to.eql('jane.doe@example.org')
        )(res)
      .catch (err) ->
        throw err
      .finally ->
        done()
