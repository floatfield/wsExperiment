var MailManager, Promise, R, filterOut, substituteEmail;

Promise = require('bluebird');

R = require('ramda');

filterOut = function(property) {
  return R.compose(R.filter(function(entry) {
    return entry[property];
  }), R.map(R.pick([property, 'email'])));
};

substituteEmail = function(email) {
  return R.forEach(function(entry) {
    return entry.email = email;
  });
};

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
      login: email,
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

  MailManager.prototype.sendUserNotificationLetter = function(dataList) {
    var config;
    config = R.dissoc('to', this.getTransporterConfig('dummy', 'Системное уведомление'));
    return this.mailer.bulkSend('user-notifications', config, dataList);
  };

  MailManager.prototype.sendTariffExpireLetter = function(dataList) {
    var config;
    config = R.dissoc('to', this.getTransporterConfig('dummy', 'Окончание срока действия тарифного плана'));
    return this.mailer.bulkSend('tariff-expire', config, dataList);
  };

  MailManager.prototype.notifyMailingList = function() {
    var compReqConfig, messConfig;
    messConfig = R.dissoc('to', this.getTransporterConfig('dummy', 'Новые предложения на вашу заявку на БиржаЗапчастей.рф'));
    compReqConfig = R.dissoc('to', this.getTransporterConfig('dummy', 'Новые заявки на сайте БиржаЗапчастей.рф'));
    return this.storage.getAllUserData().bind(this).then(function(dataList) {
      var compReqList, messList;
      compReqList = filterOut('componentRequests')(dataList);
      messList = filterOut('messages')(dataList);
      if (this.debugRecipient) {
        substituteEmail(this.debugRecipient)(compReqList);
        substituteEmail(this.debugRecipient)(messList);
      }
      this.mailer.bulkSend('new-messages', messConfig, messList);
      return this.mailer.bulkSend('new-requests', compReqConfig, compReqList);
    });
  };

  return MailManager;

})();

module.exports = MailManager;
