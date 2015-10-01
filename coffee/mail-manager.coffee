Promise = require 'bluebird'
R = require 'ramda'

filterOut = (property) ->
  R.compose(
    R.filter((entry) -> entry[property]),
    R.map(R.pick([property, 'email']))
  )
  
substituteEmail = (email) ->
  R.forEach((entry) -> entry.email = email)

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
    messConfig = R.dissoc('to', @getTransporterConfig('dummy', 'Новые предложения на вашу заявку на БиржаЗапчастей.рф'))
    compReqConfig = R.dissoc('to', @getTransporterConfig('dummy', 'Новые заявки на сайте БиржаЗапчастей.рф'))
    @storage.getAllUserData()
    .bind @
    .then (dataList) ->
      compReqList = filterOut('componentRequests')(dataList)
      messList = filterOut('messages')(dataList)
      if @debugRecipient
        substituteEmail(@debugRecipient)(compReqList)
        substituteEmail(@debugRecipient)(messList)
      @mailer.bulkSend 'new-messages', messConfig, messList
      @mailer.bulkSend 'new-requests', compReqConfig, compReqList

module.exports = MailManager
