http          = require 'http'
express       = require 'express'
clone         = require 'clone'
AlertHandler  = require './AlertHandler'

module.exports = class Server
  
  constructor: (@config, @port=5000) ->

  start: =>
    handler = new AlertHandler @config
    
    # create express app
    app = express()
    app.use express.bodyParser()

    app.post '/', (req, res) =>
      handler.handle req, res

    app.get '/alerts', (req, res) =>
      if req.query.secret != @config.librato.secret
        res.send 401, "invalid secret"
        return
  
      json = clone(handler.alerts)
      for key, value of json 
        value.timeoutId = value.timeoutId?
      res.json json
      
    app.get '/config', (req, res) =>
      if req.query.secret != @config.librato.secret
        res.send 401, "invalid secret"
        return

      res.json handler.config.librato.alerts

    app.listen @port
    console.log "mops.alerts start on #{@port}"