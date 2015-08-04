chai = require 'chai'
expect = chai.expect
Mailer = require '../lib/mailer'
cheerio = require 'cheerio'
R = require 'ramda'
Promise = require 'promise'
validUrl = require 'valid-url'
nodemailer = require 'nodemailer'

describe 'Mailer test suite', ->

  mailer = {}

  before ->
    stubTransport = require('nodemailer-stub-transport')
    transporter = nodemailer.createTransport(stubTransport())
    mailer = new Mailer
      templatesDir: '../templates/'
      transporter: transporter

  describe '#renderTemplate()', ->

    it 'should be able to render a given template', (done) ->
      mailer.renderTemplate('password-letter', {password: 'some-pass'})
      .then (res)->
        $ = cheerio.load res.html
        expect($('#sub-nav-cell-left.sub-nav-cell').text()).to.eql('Пароль к вашей учетной записи')
        expect($('#content.page_container > div').text()).to.eql('some-pass')
        done()

    it 'should render images urls correctly', (done) ->
      mailer.renderTemplate('password-letter', {password: 'some-pass'})
      .then (res) ->
        $ = cheerio.load res.html
        urls = []
        $('img').each (index, elem) ->
          urls.push $(@).attr('src')
        urls.forEach (url) ->
          expect(validUrl.isWebUri(url)).not.be.undefined
        done()

  describe '#sendEmail()', ->

    it 'should send email', (done) ->
      config =
        to: 'john.doe@example.org'
        subject: 'example is here'
        from: 'jane.doe@example.org'
      data =
        password: 'pass is here'
      mailer.sendEmail 'password-letter', config, data
      .then (res) ->
        expect(res.envelope).to.eql
          from: 'jane.doe@example.org'
          to: ['john.doe@example.org']
        done()
      .catch (err) ->
        console.error 'error sending mail: ', err

  describe '#bulkSend()', ->

    it 'should be able to send bulk of emails', (done) ->
      config =
        subject: 'example is here'
        from: 'jane.doe@example.org'
      dataList = [
        {password: 'pass1', email: 'john@example.org'},
        {password: 'pass2', email: 'doe@example.org'},
        {password: 'pass3', email: 'unknown@example.org'},
        {password: 'pass4', email: 'noone@example.org'},
      ]
      mailer.bulkSend 'password-letter', config, dataList
      .then (res) ->
        emails = R.pluck('email', dataList)
        R.forEach( (result) ->
          expect(emails).to.include.members(result.envelope.to)
          expect(result.envelope.from).to.eql('jane.doe@example.org')
        )(res)
        done()
