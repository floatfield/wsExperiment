var MailManager, Promise, R;

Promise = require('bluebird');

R = require('ramda');

MailManager = (function() {
  function MailManager(config) {
    this.mailer = config.mailer;
    this.sender = config.sender;
    this.storage = config.storage || {};
    if (config.debugRecipient) {
      this.debugRecipient = config.debugRecipient;
    }
  }

  MailManager.prototype.getTransporterConfig = function(email, subject) {
    var config;
    return config = {
      to: this.debugRecipient || email,
      subject: subject,
      from: this.sender
    };
  };

  MailManager.prototype.setStorage = function(storage) {
    this.storage = storage;
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

  MailManager.prototype.sendUserNotificationLetter = function(email, paras) {
    var config, locals;
    config = this.getTransporterConfig(email, 'Системное уведомление');
    locals = {
      paras: paras
    };
    return this.mailer.sendEmail('user-notifications', config, locals);
  };

  MailManager.prototype.notifyMailingList = function() {
    var config;
    config = R.dissoc('to', this.getTransporterConfig('dummy', 'Новые сообщения'));
    return this.storage.getAllUserData().bind(this).then(function(dataList) {
      if (this.debugRecipient) {
        dataList = R.map((function(_this) {
          return function(locals) {
            locals.email = _this.debugRecipient;
            return locals;
          };
        })(this))(dataList);
      }
      return this.mailer.bulkSend('new-messages', config, dataList);
    });
  };

  return MailManager;

})();

module.exports = MailManager;
