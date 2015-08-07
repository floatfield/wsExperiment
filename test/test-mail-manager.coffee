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

  beforeEach ->
    stubTransport = require('nodemailer-stub-transport')
    transporter = nodemailer.createTransport(stubTransport())
    mailer = new Mailer
      templatesDir: '../templates'
      transporter: transporter
    mailManager = new MailManager
      mailer: mailer
      sender: 'jane.doe@example.org'
      dbName: 'testing-purpose-database'

  describe '#sendPassword()', ->

    it 'should be able to send a password letter to a user', (done) ->
      email = 'some@example.org'
      password = 'some_pass_goes_here'
      mailManager.sendPasswordLetter email, password
      .then (res) ->
        expect(res.envelope).to.eql
          to: ['some@example.org']
          from: 'jane.doe@example.org'
        done()
      .catch (err) ->
        expect(err).to.be.null
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
        done()
      .catch (err) ->
        expect(err).to.be.null
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
        done()
      .catch (err) ->
        expect(err).to.be.null
        done()

  # describe '#notifyMailingList()'
