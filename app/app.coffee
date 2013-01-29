YML           = require 'js-yaml'
Server        = require './Server'
Gumsgem       = require './Gumsgem'

# load config
config        = YML.load process.env.CONFIG
config        = config.production

gumsgem = new Gumsgem config.gums
config.update = (cb) ->
  gumsgem.loadConfig (alerts) ->
    config.librato['alerts'] = alerts
    cb() if cb

config.update ->
  server = new Server config, process.env.PORT
  server.start()