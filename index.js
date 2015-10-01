var express = require('express'),
  app = express(),
  http = require('http'),
  server = http.Server(app),
  R = require('ramda'),
  DullCache = require('./lib/dull-cache'),
  SocketServer = require('./lib/SocketServer'),
  Mailer = require('./lib/mailer'),
  MailManager = require('./lib/mail-manager'),
  Storage = require('./lib/storage'),
  bodyParser = require('body-parser'),
  util = require('./lib/util'),
  nodemailer = require('nodemailer'),
  smtpPool = require('nodemailer-smtp-pool'),
  schedule = require('node-schedule'),
  argv = require('minimist')(process.argv.slice(2)),
  smtpConfig = {
    port: 2525,
    host: 'mail.used-part.ru',
    auth: {
      user: 'parts',
      pass: 'somePassPhrase'
    },
    tls: {
      rejectUnauthorized: false
    }
  },
  transporter = nodemailer.createTransport(smtpPool(smtpConfig)),
  dbName = util.generateDbName(),
  storage = new Storage(dbName),
  dullCache = new DullCache({
    stdTTL: 15000
  }),
  socketServer = new SocketServer({
    port: 8091,
    cache: dullCache,
    storage: storage
  }),
  mailer = new Mailer({
    templatesDir: '../templates',
    transporter: transporter
  }),
  mailManagerConfig = {
    mailer: mailer,
    sender: 'Биржа запчастей <admin@used-part.ru>',
    storage: storage
  };

if(argv.h){
  console.log('node index.js [-d email] [--tls-accept]');
  process.exit();
}

if(argv.d || argv['debug-recipient']){
  var debugRecipient = argv.d ? argv.d : argv['debugRecipient'];
  mailManagerConfig = R.assoc('debugRecipient', debugRecipient, mailManagerConfig);
}
var mailManager = new MailManager(mailManagerConfig);

if(argv['tls-accept']){
  process.env.NODE_TLS_REJECT_UNAUTHORIZED = 0;
}

schedule.scheduleJob('* * * * *', function() {
  var newStorage = new Storage(util.generateDbName());
  newStorage.createDb()
    .then(function() {
      return newStorage.persistDesignDocument('../design_documents/find_new_user_data.json', 'user_data');
    })
    .then(function() {
      socketServer.setStorage(newStorage);
      return mailManager.notifyMailingList();
    })
    .then(function() {
      mailManager.setStorage(newStorage);
      return storage.destroyDb();
    })
    .then(function() {
      storage = newStorage;
    })
    .catch(function(err) {
      console.error('error scheduling stuff');
      console.error(err);
    });
});

storage.createDb()
  .then(function() {
    return storage.persistDesignDocument('../design_documents/find_new_user_data.json', 'user_data');
  })
  .catch(function(err) {
    console.error('error creating db');
    console.error(err);
  });

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({
  extended: true
}));
app.use(express.static('public'));

server.listen(8090);

app.post('/token', function(req, res) {
  var email = req.body.email,
    token = req.body.token;
  socketServer.setUserToken(email, token);
  res.send({
    success: true
  });
});

app.post('/message', function(req, res) {
  var email = req.body.email,
    message = JSON.parse(req.body.message),
    correspondencePath = req.body.correspondencePath,
    correspondenceId = req.body.correspondenceId;
  socketServer.sendMessage(email, {
    message: message,
    link: correspondencePath,
    correspondenceId: correspondenceId
  });
  res.send({
    success: true
  });
});

app.post('/request_notification', function(req, res) {
  var email = req.body.email,
    requests = R.values(JSON.parse(req.body.requests));
  socketServer.sendComponentRequests(email, requests);
  res.send({
    success: true
  });
});

app.post('/password_restore', function(req, res) {
  mailManager.sendPasswordRestorationLetter(req.body.email, req.body.link);
  res.send({
    success: true
  });
});

app.post('/password_email', function(req, res) {
  mailManager.sendPasswordLetter(req.body.email, req.body.password);
  res.send({
    success: true
  });
});

app.post('/user_notification', function(req, res) {
  var emails = req.body.emails.split(','),
      paras = R.filter(function (para) {
        return para.length > 0;
      }, req.body.text.split('\n'));
      dataList =emails.map(function (email) {
        return {
          email: email,
          paras: paras
        };
      });
  mailManager.sendUserNotificationLetter(dataList);
});

app.post('/user_warning', function (req, res) {
  var email = req.body.email,
      message = req.body.warning;
  socketServer.sendWarning(email, message);
  res.send({
    success: true
  });
});

app.post('/interlocutor_blocked', function (req, res) {
  var email = req.body.email,
      correspondenceId = req.body.correspondenceId;
  socketServer.sendInterlocutorBlockedNotification(email, correspondenceId);
  res.send({
    success: true
  });
});

app.post('/expire_notifications', function (req, res) {
  var localData = JSON.parse(req.body.data);
  mailManager.sendTariffExpireLetter(localData);
  res.send({
    success: true
  });
});
