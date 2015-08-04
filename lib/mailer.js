var DullCache, EmailTemplate, Mailer, Promise, R, imagesUrl, isIPv4, ownIp, path;

isIPv4 = function(entry) {
  return entry.family === 'IPv4' && entry.address !== '127.0.0.1';
};

EmailTemplate = require('email-templates').EmailTemplate;

path = require('path');

Promise = require('bluebird');

DullCache = require('./dull-cache');

R = require('ramda');

ownIp = R.compose(R.head, R.pluck('address'), R.filter(isIPv4), R.flatten, R.values)(require('os').networkInterfaces());

imagesUrl = 'http://' + ownIp + '/bundles/parts/res/';

Mailer = (function() {
  function Mailer(config) {
    this.templatesDir = config.templatesDir;
    this.transporter = config.transporter;
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
    return render(R.assoc('images', imagesUrl, locals));
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
