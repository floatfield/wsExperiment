var MailManager, Promise, R;

Promise = require('bluebird');

R = require('ramda');

MailManager = (function() {
  function MailManager(config) {
    this.mailer = config.mailer;
    this.sender = config.sender;
    this.dbName = config.dbName;
  }

  MailManager.prototype.getTransporterConfig = function(email, subject) {
    var config;
    return config = {
      to: email,
      subject: subject,
      from: this.sender
    };
  };

  MailManager.prototype.sendPasswordLetter = function(email, password) {
    var config, locals;
    config = this.getTransporterConfig(email, 'Пароль к вашей учетной записи');
    locals = {
      password: password
    };
    return this.mailer.sendEmail('password-letter', config, locals);
  };

  MailManager.prototype.sendPasswordRestorationLetter = function(email, link) {
    var config, locals;
    config = this.getTransporterConfig(email, 'Восстановление учетной записи');
    locals = {
      link: link
    };
    return this.mailer.sendEmail('password-restore-letter', config, locals);
  };

  MailManager.prototype.sendUserNotificationLetter = function(email, text) {
    var config, locals;
    config = this.getTransporterConfig(email, 'Системное уведомление');
    locals = {
      text: text
    };
    return this.mailer.sendEmail('user-notifications', config, locals);
  };

  return MailManager;

})();

module.exports = MailManager;
