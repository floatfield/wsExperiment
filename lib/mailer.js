var DullCache, EmailTemplate, Mailer, Promise, R, base64, basify, imagesUrl, inlineBase64, isIPv4, ownIp, path;

isIPv4 = function(entry) {
  return entry.family === 'IPv4' && entry.address !== '127.0.0.1';
};

EmailTemplate = require('email-templates').EmailTemplate;

path = require('path');

Promise = require('bluebird');

base64 = require('node-base64-image');

basify = Promise.promisify(base64.base64encoder);

DullCache = require('./dull-cache');

R = require('ramda');

ownIp = R.compose(R.head, R.pluck('address'), R.filter(isIPv4), R.flatten, R.values)(require('os').networkInterfaces());

imagesUrl = 'http://used-part.ru/bundles/parts/res/';

inlineBase64 = require('nodemailer-plugin-inline-base64');

Mailer = (function() {
  function Mailer(config) {
    this.templatesDir = config.templatesDir;
    this.transporter = config.transporter;
    this.transporter.use('compile', inlineBase64);
    this.send = Promise.promisify(this.transporter.sendMail, this.transporter);
    this.cache = new DullCache({
      stdTTL: 30000
    });
  }

  Mailer.prototype.renderTemplate = function(templateName, locals) {
    var letter, render, templateDir;
    if (!this.cache.get(templateName)) {
      templateDir = path.resolve(__dirname, path.join(this.templatesDir, templateName));
      letter = new EmailTemplate(templateDir);
      render = Promise.promisify(letter.render, letter);
      this.cache.set(templateName, render);
    } else {
      render = this.cache.get(templateName);
    }
    return basify(imagesUrl + 'logo.png', {}).then(function(base64image) {
      var logo;
      logo = base64image.toString('base64');
      return render(R.assoc('logo', logo, locals));
    })["catch"](function(err) {
      return console.error('error rendering mail template: ', err);
    });
  };

  Mailer.prototype.sendEmail = function(templateName, config, locals) {
    return this.renderTemplate(templateName, locals).bind(this).then(function(arg) {
      var html, text;
      html = arg.html, text = arg.text;
      return this.send(R.merge(config, {
        html: html,
        text: text
      }));
    });
  };

  Mailer.prototype.bulkSend = function(templateName, config, localsList) {
    var promiseList;
    promiseList = R.map((function(_this) {
      return function(locals) {
        return _this.sendEmail(templateName, R.assoc('to', locals.email, config), locals);
      };
    })(this))(localsList);
    return Promise.all(promiseList);
  };

  return Mailer;

})();

module.exports = Mailer;
