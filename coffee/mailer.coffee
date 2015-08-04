isIPv4 = (entry) ->
  entry.family == 'IPv4' and entry.address != '127.0.0.1'

EmailTemplate = require('email-templates').EmailTemplate
path = require 'path'
Promise = require 'bluebird'
DullCache = require './dull-cache'
R = require 'ramda'
ownIp = R.compose(
        R.head,
        R.pluck('address'),
        R.filter(isIPv4),
        R.flatten,
        R.values
    )(require('os').networkInterfaces())
imagesUrl = 'http://' + ownIp + '/bundles/parts/res/'

class Mailer

  constructor: (config) ->
    @templatesDir = config.templatesDir
    @transporter = config.transporter
    @send = Promise.promisify @transporter.sendMail, @transporter
    @cache = new DullCache
      stdTTL: 30000

  renderTemplate: (templateName, locals) ->
    if not @cache.get templateName
      templateDir = path.resolve(__dirname, path.join(@templatesDir, templateName))
      letter = new EmailTemplate(templateDir)
      render = Promise.promisify letter.render, letter
      @cache.set templateName, render
    else
      render = @cache.get templateName
    render R.assoc('images', imagesUrl, locals)

  sendEmail: (templateName, config, locals) ->
    @renderTemplate templateName, locals
    .bind @
    .then ({html, text}) ->
      @send R.merge(config, {html: html, text: text})

  bulkSend: (templateName, config, localsList) ->
    promiseList = R.map( (locals) =>
      @sendEmail templateName, R.assoc('to', locals.email, config), locals
    )(localsList)
    Promise.all(promiseList)

module.exports = Mailer
