restler = require 'restler'
crypto  = require('crypto');

module.exports = class Gumsgem
  
  constructor: (@config) ->

  authToken: ->
    shasum = crypto.createHash 'sha1'
    shasum.update @config.api_secret+@config.key
    shasum.digest 'base64'
  
  loadConfig: (cb, retries = 10) ->    
    restler.get "#{@config.api_endpoint}/users/#{@config.key}", 
      headers:
        'X-Auth-Token': @authToken()
    .on 'error', (err) ->
      if retries == 0
        console.error err
      else
        @loadConfig cb, --retries
    .on 'fail', (err) ->
      if retries == 0
        console.error err
      else
        @loadConfig cb, --retries
    .on 'success', (alerts) ->
      alerts = JSON.parse alerts
      cb alerts.data