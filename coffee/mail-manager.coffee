Promise = require 'bluebird'
R = require 'ramda'

class MailManager

  constructor: (config) ->
    @mailer = config.mailer
    @sender = config.sender
    @dbName = config.dbName

  getTransporterConfig: (email, subject) ->
    config =
      to: email
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

  sendUserNotificationLetter: (email, text) ->
    config = @getTransporterConfig email, 'Системное уведомление'
    locals =
      text: text
    @mailer.sendEmail 'user-notifications', config, locals

  notifyMailingList: ->
    config = R.dissoc('to', @getTransporterConfig('dummy', 'Новые сообщения'))
    @storage.getAllUserData()
    .bind @
    .then (dataList) ->
      @mailer.bulkSend 'new-messages', config, dataList

module.exports = MailManager
