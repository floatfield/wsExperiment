// var chai = require('chai'),
//   spies = require('chai-spies'),
//   expect = chai.expect,
//   NodeCache = require('node-cache'),
//   sinon = require('sinon');
//
// chai.use(spies);
//
// describe('Socket server', function() {
//
//   var socketServer,
//     clock,
//     port = 9090,
//     cache = new NodeCache({
//       stdTTL: 30,
//       checkPeriod: 40
//     });
//
//   before(function() {
//     clock = sinon.useFakeTimers();
//   });
//
//   after(function() {
//     clock.restore();
//   });
//
//   beforeEach(function() {
//     socketServer = require('../socketServer')({
//       port: ++port,
//       cache: cache
//     });
//   });
//
//   describe('#created socket server ', function() {
//
//     it('should be able to be created', function() {
//       expect(socketServer).to.be.an('object');
//     });
//
//   });
//
//   describe('#socket server ', function() {
//
//     it('should be able to accept single connection', function(done) {
//       socketClient = require('socket.io-client')('ws://localhost:' + port, {
//         'force new connection': true
//       });
//       socketClient.on('connect', function() {
//         done();
//       });
//     });
//
//     it('should be able to accept multiple incoming connections', function(done) {
//       function onConnect() {
//         connections++;
//         if (connections === 2) {
//           done();
//         }
//       }
//       var connections = 0,
//         socketClient1 = require('socket.io-client')('ws://localhost:' + port, {
//           'force new connection': true
//         }),
//         socketClient2 = require('socket.io-client')('ws://localhost:' + port, {
//           'force new connection': true
//         });
//       socketClient1.on('connect', onConnect);
//       socketClient2.on('connect', onConnect);
//     });
//
//
//
//   });
//
//   describe('#socket server ', function() {
//
//     it('should accept incoming user identity objects', function() {
//       expect(socketServer).to.include.keys('setUserToken');
//       expect(socketServer.setUserToken).to.be.a('function');
//     });
//
//     it('should populate applied cache with received user credentials', function() {
//       socketServer.setUserToken(12, 'some token');
//       expect(cache.get(12)).to.exist;
//       clock.tick(40000);
//       expect(cache.get(12)).not.to.exist;
//     });
//
//   });
//
// });
