Promise = require 'bluebird'
R = require 'ramda'

class MailManager

  constructor: (config) ->
    @mailer = config.mailer
    @sender = config.sender
    @storage = config.storage || {}
    if config.debugRecipient
      @debugRecipient = config.debugRecipient

  getTransporterConfig: (email, subject) ->
    config =
      to: @debugRecipient || email
      subject: subject
      from: @sender

  setStorage: (@storage) ->

  sendPasswordLetter: (email, password) ->
    config = @getTransporterConfig email, 'Пароль к вашей учетной записи'
    locals =
      password: password
    @mailer.sendEmail 'password-letter', config, locals

  sendPasswordRestorationLetter: (email, link) ->
    config = @getTransporterConfig email, 'Восстановление учетной записи'
    locals =
      link: link
    @mailer.sendEmail 'password-restore-letter', config, locals

  sendUserNotificationLetter: (dataList) ->
    config = R.dissoc('to', @getTransporterConfig('dummy', 'Системное уведомление'))
    dataList = dataList
    @mailer.bulkSend 'user-notifications', config, dataList
    
  sendWelcomeLetter: (email, password) ->
    config = @getTransporterConfig email, 'Добро пожаловать'
    locals =
      password: password
      login: email
    @mailer.sendEmail 'welcome-letter', config, locals

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
      @mailer.bulkSend 'new-messages', config, dataList

module.exports = MailManager
