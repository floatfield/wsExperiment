util = require '../lib/util'
chai = require 'chai'
expect = chai.expect

describe 'Util test suite', ->

  describe '#mergeAdd()', ->

    it 'should do it correctly', ->
      mergeAdd = util.mergeAdd
      obj1 =
        a: [{a: 1, b: 'sd'}]
        b: 2
        c: [1, 2, 3]
      obj2 =
        a: [{l: 1}]
      obj3 =
        b: 7
      obs = [obj1, obj2, obj3]
      expect(mergeAdd(obs)).to.eql
        a: [{a: 1, b: 'sd'}, {l: 1}]
        b: 9
        c: [1, 2, 3]
      expect(mergeAdd([obj2, obj3])).to.eql
        a: [{l: 1}]
        b: 7
