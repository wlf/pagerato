Librato       = require '../app/Librato'
Pagerduty     = require '../app/Pagerduty'
Gumsgem       = require '../app/Gumsgem'
Statistic     = require '../app/Statistic'
AlertHandler  = require '../app/AlertHandler'

YML           = require 'js-yaml'
vows          = require 'vows'
assert        = require 'assert'
config        = require('../lib/apis.yml').production

#hide log messages
console.log = (msg) ->

tests = vows.describe('mops.alerts')
  
# add some basic tests
tests.addBatch

  'test basics':
  
    'config': ->
      assert.isObject config.librato
      assert.isObject config.gums
      assert.equal config.gums.key, 'mops.alert'

  'statistics':

    'mean with empty array': ->
      assert.equal 0, Statistic.mean []
      
    'mean with values': ->
      assert.equal 4, Statistic.mean [2,6,4]
      
    'regression': ->
      regression = 
        Statistic.linearRegression [[20,0],[16,3],[15,7],[16,4],[13,6],[10,10]]
        
      assert.equal -0.98, Math.round(regression.slope*100)/100
      assert.equal 19.73, Math.round(regression.intercept*100)/100
      
    'regression with floating point values': ->
      regression = 
        Statistic.linearRegression [[20.1,0],[16,3],[15,7],[16,4],[13,6],[9.1,10]]
        
      assert.equal -0.9, Math.round(regression.slope*100)/100
      assert.equal 18.37, Math.round(regression.intercept*100)/100
      
    'range test': ->
      assert.ok Statistic.inRange 1, 3, 4, "range should be ok"
      assert.ok Statistic.inRange 1, 3, null, "should handle null value"
      assert.ok Statistic.inRange 1, 3, undefined, "should handle undefined"
      assert.ok Statistic.inRange 1, 3, "", "should handle empty string"
      
      assert.ok Statistic.inRange null, -1, 2, "should handle null value"
      assert.ok Statistic.inRange undefined, -1, 2, "should handle undefined"
      assert.ok Statistic.inRange 1, 3, "", "should handle empty string"
      
      assert.isFalse Statistic.inRange 1, 3, 2
      assert.isFalse Statistic.inRange 1, 0, 2
      assert.isFalse Statistic.inRange 1, -10, 2

# add alertHandler tests
tests.addBatch
  'alert filter':
    
    topic: ->
      alertHandler = new AlertHandler config
      return alertHandler

    'should find an alert': (handler) ->
      assert.ok handler.findAlerts 'test', 'alert.name', [{alert: 'test', lower_limit: 10}]
      assert.ok handler.findAlerts 'test', 'alert.name', [{alert: 'test', lower_limit: 10, blacklist: 'black.list, blacklist'}]
      assert.ok handler.findAlerts 'test', 'alert.name', [{alert: 'test', lower_limit: 10, whitelist: 'alert.name'}]

    'should not find alert': (handler) ->
      assert.isFalse handler.findAlerts 'test', 'alert.name', []
      assert.isFalse handler.findAlerts 'test', 'other.name', [{alert: 'test', lower_limit: 10, whitelist: 'alert.name'}]
      assert.isFalse handler.findAlerts 'test', 'alert.name', [{alert: 'test', lower_limit: 10, blacklist: 'other.name, alert.name'}]
      assert.isFalse handler.findAlerts 'test', 'alert.name', [{alert: 'test', lower_limit: 10, whitelist: 'alert.name', blacklist: 'alert.name'}]

# add alertHandler tests
tests.addBatch

  'parameter tests':
    topic: ->
      alertHandler = new AlertHandler config
      return alertHandler 
      
    'missing secret': (handler) ->
      request = 
        query: {}
        body: {}
      response = 
        send: (code) ->
          assert.equal code, 401
      handler.handle request, response 
    
    'invalid secret': (handler) ->
      request = 
        query:
          secret: 'invalid secret'
        body: {}
      response = 
        send: (code) ->
          assert.equal code, 401
      handler.handle request, response
    
    'invalid secret 2': (handler) ->
      request = 
        query:
          secret: 'invalid secret'
        body:
          secret: 'invalid secret2'
      response = 
        send: (code) ->
          assert.equal code, 401
      handler.handle request, response
    
    'valid secret (query param)': (handler) ->
      request = 
        query:
          secret: config.librato.secret
        body: {}
      response = 
        send: (code) ->
          assert.equal code, 400

      # should throw an empty payload message
      handler.handle request, response
    
    'valid secret (body param)': (handler) ->
      request = 
        query: {}
        body:
          secret: config.librato.secret
      response = 
        send: (code) ->
          assert.equal code, 400
      handler.handle request, response
    
    'empty payload': (handler) ->
      request = 
        query:
          secret: config.librato.secret
        body: {}
      response = 
        send: (code) ->
          assert.equal code, 400
      handler.handle request, response

tests.addBatch
  'request tests':
    topic: ->
      config.librato['alerts'] = [{
                'alert': 'test.metric'
                'warn_time': 10
                'timeout':0
                'grouped_values': 10
                'regressions': 3
                'pagerduty_service': 'P0QV1J0'
                'upper_limit': 10
                'lower_limit': 0
                'blacklist': 'blacklisted.source, wildcard'
      }]
      alertHandler = new AlertHandler config
      return alertHandler
    
    'upper limit': (handler) ->
      handler.alerts = {}
      trigger = resolved =false
      request = 
        query:
          secret: config.librato.secret
        body: 
          payload: '{"metric":{"name":"test.metric"},"measurement":{"value":4.5,"source":"test.source"}}'
      response = 
        send: (code) ->
          assert.equal code, 204
      handler.pagerduty.resolveIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source"
        resolved = true
      handler.pagerduty.triggerIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source"
        assert.equal description, "[test.metric - test.source] - limits exceeded: 0 < 11 < 10"
        trigger = true
      handler.librato.getAverageRegressions = (metric, source, end_date, count, group_count, cb) ->
        assert.equal metric, 'test.metric'
        assert.equal source, 'test.source'
        assert.equal group_count, 10
        assert.equal count, 3
        result = 
          slope: 1
          intercept: 0
          last:
            value: 11
            measure_time: 1
        cb false, result
      handler.handle request, response
      assert.ok trigger
      assert.isFalse resolved
      
    'lower limit': (handler) ->
      handler.alerts = {}
      trigger = resolved =false
      request = 
        query:
          secret: config.librato.secret
        body: 
          payload: '{"metric":{"name":"test.metric"}, "measurement":{"value":4.5,"source":"test.source"}}'
      response = 
        send: (code) ->
          assert.equal code, 204

      handler.pagerduty.resolveIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source"
        resolved = true
      handler.pagerduty.triggerIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source"
        assert.equal description, "[test.metric - test.source] - limits exceeded: 0 < 0 < 10"
        trigger = true
      handler.librato.getAverageRegressions = (metric, source, end_date, count, group_count, cb) ->
        assert.equal metric, 'test.metric'
        assert.equal source, 'test.source'
        assert.equal group_count, 10
        assert.equal count, 3
        result = 
          slope: 1
          intercept: 0
          last:
            value: 0
            measure_time: 1
        cb false, result
      handler.handle request, response
      assert.ok trigger
      assert.isFalse resolved
      
    'upper limit regression test':  (handler) ->
      handler.alerts = {}
      trigger = resolved =false
      request = 
        query:
          secret: config.librato.secret
        body: 
          payload: '{"metric":{"name":"test.metric"},"measurement":{"value":4.5,"source":"test.source"}}'
      response = 
        send: (code) ->
          assert.equal code, 204

      handler.pagerduty.resolveIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source"
        resolved = true
      handler.pagerduty.triggerIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source"
        assert.equal description, "[test.metric - test.source] - limit will be exceeded within warn time: 0 < 11 < 10"
        trigger = true 
      handler.librato.getAverageRegressions = (metric, source, end_date, count, group_count, cb) ->
        assert.equal metric, 'test.metric'
        assert.equal source, 'test.source'
        assert.equal group_count, 10
        assert.equal count, 3
        result = 
          slope: 1
          intercept: 0
          last:
            value: 1
            measure_time: 1
        cb false, result
      handler.handle request, response
      assert.ok trigger
      assert.isFalse resolved

    'lower limit regression test':  (handler) ->
      handler.alerts = {}
      trigger = resolved =false      
      request = 
        query:
          secret: config.librato.secret
        body: 
          payload: '{"metric":{"name":"test.metric"},"measurement":{"value":4.5,"source":"test.source2"}}'
      response = 
        send: (code) ->
          assert.equal code, 204

      handler.pagerduty.resolveIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source2"
        resolved = true
      handler.pagerduty.triggerIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source2"
        assert.equal description, "[test.metric - test.source2] - limit will be exceeded within warn time: 0 < -1 < 10"
        trigger = true 
      handler.librato.getAverageRegressions = (metric, source, end_date, count, group_count, cb) ->
        assert.equal metric, 'test.metric'
        assert.equal source, 'test.source2'
        assert.equal group_count, 10
        assert.equal count, 3
        result = 
          slope: -1
          intercept: 10
          last:
            value: 1
            measure_time: 1
        cb false, result      
      handler.handle request, response
      assert.ok trigger
      assert.isFalse resolved

    'lower limit regression test (slope=0)':  (handler) ->
      handler.alerts = {}
      trigger = resolved =false      
      request = 
        query:
          secret: config.librato.secret
        body: 
          payload: '{"metric":{"name":"test.metric"},"measurement":{"value":4.5,"source":"test.source2"}}'
      response = 
        send: (code) ->
          assert.equal code, 204

      handler.pagerduty.resolveIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source2"
        resolved = true
      handler.pagerduty.triggerIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source2"
        assert.equal description, "[test.metric - test.source2] - limit will be exceeded within warn time: 0 < 0 < 10"
        trigger = true 
      handler.librato.getAverageRegressions = (metric, source, end_date, count, group_count, cb) ->
        assert.equal metric, 'test.metric'
        assert.equal source, 'test.source2'
        assert.equal group_count, 10
        assert.equal count, 3
        result = 
          slope: 0
          intercept: 0
          last:
            value: 5
            measure_time: 1
        cb false, result
      
      handler.handle request, response
      assert.ok trigger
      assert.isFalse resolved

    'blacklisted source':  (handler) ->
      handler.alerts = {}
      trigger = resolved =false      
      request = 
        query:
          secret: config.librato.secret
        body: 
          payload: '{"metric":{"name":"test.metric"},"measurement":{"value":4.5,"source":"blacklisted.source"}}'
      response = 
        send: (code) ->
          assert.equal code, 204

      handler.pagerduty.resolveIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source2"
        resolved = true
      handler.pagerduty.triggerIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source2"
        assert.equal description, "limit will be exceeded within warn time. (0 < 0 < 10)"
        trigger = true 

      handler.handle request, response
      assert.isFalse trigger
      assert.isFalse resolved

    'wildcard blacklisted source':  (handler) ->
      handler.alerts = {}
      trigger = resolved =false      
      request = 
        query:
          secret: config.librato.secret
        body: 
          payload: '{"metric":{"name":"test.metric"},"measurement":{"value":4.5,"source":"blackliste.wildcard"}}'
      response = 
        send: (code) ->
          assert.equal code, 204

      handler.pagerduty.resolveIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source2"
        resolved = true
      handler.pagerduty.triggerIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source2"
        assert.equal description, "limit will be exceeded within warn time. (0 < 0 < 10)"
        trigger = true 

      handler.handle request, response
      assert.isFalse trigger
      assert.isFalse resolved

    'resolve': (handler) ->
      
      trigger = resolved =false      
      request = 
        query:
          secret: config.librato.secret
        body: 
          payload: '{"metric":{"name":"test.metric"},"measurement":{"value":4.5,"source":"test.source"}}'
      response = 
        send: (code) ->
          assert.equal code, 204

      handler.pagerduty.resolveIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source"
        resolved = true
      handler.pagerduty.triggerIncident = (service_key, incident, description, value) ->
        assert.equal incident, "test.metric:test.source"
        assert.equal incident, "test.metric:test.source"
        assert.equal description, "limit will be exceeded within warn time. (0 < 0 < 10)"
        trigger = true
      handler.librato.getAverageRegressions = (metric, source, end_date, count, group_count, cb) ->
        assert.equal metric, 'test.metric'
        assert.equal source, 'test.source'
        assert.equal group_count, 10
        assert.equal count, 3
        result = 
          slope: 0.0
          intercept: 1
          last:
            value: 4
            measure_time: 1
        cb false, result
      handler.handle request, response
      assert.isFalse trigger
      assert.ok resolved

tests.export(module);