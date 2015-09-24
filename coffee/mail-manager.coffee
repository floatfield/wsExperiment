Promise = require 'bluebird'
R = require 'ramda'
util = require './util.js'

class MailManager

  constructor: (config) ->
    @mailer = config.mailer
    @sender = config.sender
    @storage = config.storage || {}
    @debugRecipient = config.debugRecipient if config.debugRecipient
    @logger = config.logger if config.logger

  getTransporterConfig: (email, subject) ->
    config =
      to: @debugRecipient || email
      subject: subject
      from: @sender

  setStorage: (@storage) ->

  sendPasswordLetter: (email, password) ->
    config = @getTransporterConfig email, 'Пароль к вашей учетной записи'
    locals =
      login: email
      password: password
    @mailer.sendEmail 'password-letter', config, locals

  sendPasswordRestorationLetter: (email, link) ->
    config = @getTransporterConfig email, 'Восстановление учетной записи'
    locals =
      link: link
    @mailer.sendEmail 'password-restore-letter', config, locals

  sendUserNotificationLetter: (dataList) ->
    config = R.dissoc('to', @getTransporterConfig('dummy', 'Системное уведомление'))
    @mailer.bulkSend 'user-notifications', config, dataList

  sendTariffExpireLetter: (dataList) ->
    config = R.dissoc('to', @getTransporterConfig('dummy', 'Окончание срока действия тарифного плана'))
    @mailer.bulkSend 'tariff-expire', config, dataList

  notifyMailingList: ->
    config = R.dissoc('to', @getTransporterConfig('dummy', 'Новые сообщения'))
    @storage.getAllUserData()
    .bind @
    .then (dataList) ->
      if @debugRecipient
        dataList = R.map((locals) =>
          locals.email = @debugRecipient
          locals
        )(dataList)
      if @logger
        util.logObject @logger, 'all user data list', dataList
      @mailer.bulkSend 'new-messages', config, dataList

module.exports = MailManager
