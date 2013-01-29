YML     = require 'js-yaml'
restler = require 'restler'
util    = require 'util'
config  = require('./lib/apis.yml').production
Server  = require './app/Server'
Gumsgem = require './app/Gumsgem'
Librato = require './app/Librato'

url =
  staging: 'http://mops-alerts-staging.herokuapp.com'
  production: 'http://mops-alerts.herokuapp.com'

task 'default', (params) ->
  jake.Task['start'].invoke []

desc "start server"
task 'start', ->
  server = new Server config
  server.start()

desc "run tests"
task 'tests', ->
  jake.exec ['./node_modules/vows/bin/vows test/*.coffee --spec'], ->
      console.info 'run ./node_modules/vows/bin/vows test/*.coffee --spec for colored output'
  , {printStdout: true, printStderr: false}

namespace 'deploy', ->

  desc "heroku staging"
  task "staging", ->
    cmds = [
      'heroku config:add BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-nodejs.git  --app mops-alerts-staging',
      'heroku config:add CONFIG="`cat lib/apis.yml`" --app mops-alerts-staging',
      'git checkout heroku',
      'git push -f staging'
    ]
    jake.exec cmds, ->
      console.log 'heroku staging deployed'
    , {printStdout: true, printStderr:true}

  desc "heroku production"
  task "production", ->
    cmds = [
      'heroku config:add BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-nodejs.git  --app mops-alerts',
      'heroku config:add CONFIG="`cat lib/apis.yml`" --app mops-alerts',
      'git checkout heroku',
      'git push -f production'
    ]
    jake.exec cmds, ->
      console.log 'heroku production deployed'
    , {printStdout: true, printStderr:true}

namespace 'info', ->

  desc "show last mesurement from librato"
  task 'value', (metric, source) ->
    if !metric
      console.error 'metric is required'
      console.error 'jake value:regression[metric,source?]'
      return
    date = Math.floor Date.now()/1000
    @librato = new Librato config.librato.url, config.librato.username, config.librato.password
    @librato.getAverageRegressions metric, source, date, 1, 1, (error, metrics, completed) =>
      console.log util.inspect metrics.last, false, 3, true

  desc "compute regression based on the current values"
  task 'regression', (metric, source, regressions=3, values=10) ->
    if !metric
      console.error 'metric is required'
      console.error 'jake info:regression[metric,source?]'
      return
    date = Math.floor Date.now()/1000
    @librato = new Librato config.librato.url, config.librato.username, config.librato.password
    @librato.getAverageRegressions metric, source, date, regressions, values, (error, metrics, completed) =>
      delete metrics.last
      console.log util.inspect metrics, false, 3, true

  desc "show current alert configurations from production or staging system"
  task 'config', (env='staging') ->
    url = if env=='staging' then url.staging else url.production
    restler.get("#{url}/config", {
      query:
        secret: config.librato.secret
    }).on 'complete', (data, response) ->
      console.log util.inspect data, false, 3, true

  
  desc "show current alerts from production or staging system"
  task "alerts", (env='staging') ->
    url = if env=='staging' then url.staging else url.production
    restler.get("#{url}/alerts", {
      query:
        secret: config.librato.secret
    }).on 'complete', (data, response) ->
      console.log util.inspect data, false, 3, true
  
  namespace 'staging', ->
    
    desc "show current alerts", ->
    task 'alerts', ->
      jake.Task['info:alerts'].invoke()

    desc "show current config", ->
    task 'config', ->
      jake.Task['info:config'].invoke()
      
  namespace 'production', ->
    
    desc "show current alerts", ->
    task 'alerts', ->
      jake.Task['info:alerts'].invoke('production')
    
    desc "show current config", ->
    task 'config', ->
      jake.Task['info:config'].invoke('production')