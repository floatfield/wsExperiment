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

  MailManager.prototype.sendUserNotificationLetter = function(email, text) {
    var config, locals;
    config = this.getTransporterConfig(email, 'Системное уведомление');
    locals = {
      text: text
    };
    return this.mailer.sendEmail('user-notifications', config, locals);
  };

  MailManager.prototype.notifyMailingList = function() {
    var config;
    console.log(this.storage);
    config = R.dissoc('to', this.getTransporterConfig('dummy', 'Новые сообщения'));
    return this.storage.getAllUserData().bind(this).then(function(dataList) {
      return this.mailer.bulkSend('new-messages', config, dataList);
    });
  };

  return MailManager;

})();

module.exports = MailManager;
