qs            = require 'querystring'
Librato       = require './Librato'
Pagerduty     = require './Pagerduty'
Statistic     = require './Statistic'
clone         = require 'clone'

module.exports = class AlertHandler
  
  constructor: (@config) ->
    @librato = new Librato @config.librato.url, @config.librato.username, @config.librato.password 
    @pagerduty = new Pagerduty config.pagerduty.url
    @alerts = {}  
  
  handle: (req, res) ->
    
    # check secret
    if (req.query.secret or req.body.secret) != @config.librato.secret
      res.send 401, "invalid secret"
      return

    # refresh required
    if (req.query.refresh or req.body.refresh) and @config.update
      @config.update ->
        console.log 'update config'
      res.send 204
      return

    # payload is required
    payload = JSON.parse req.body.payload if req.body.payload?
    if not payload
      res.send 400, "empty payload"
      return

    # some shorthands
    metric = payload?.metric?.name
    source = payload?.measurement?.source
    incident= "#{metric}:#{source}"
    
    # validate inputs
    if not (metric and source)
      res.send 400, "missing params"
      return

    # close librator request
    res.send 204
    
    # find config
    config = @findAlerts metric, source
    if !config
      console.log "[#{metric} - #{source}] config not found"
      return
    
    timeout = config.timeout * 1000
    interval = config.interval * 1000
    service_key =  @config.pagerduty.service_key[config['pagerduty_service']]
    
    if !service_key
      console.log "missing pagerduty service key"
      return
    
    # return if alert is already handled
    if @alerts[incident] isnt undefined
      @alerts[incident].triggerCount += 1
      return
    else
      @alerts[incident]  =
        alertTime: Date.now()
        triggerCount: 0
        pagerDuty: false
        payload: payload
        config: config
        libratoUrl:  "https://metrics.librato.com/metrics/#{metric}"

    # trigger unknown sources immediately
    if config.metric == 'default'
      @pagerduty.triggerIncident service_key, incident, "Received unknown alert", clone(@alerts[incident])
      delete @alerts[incident]
      return

    # function to check alert value against the current mesurement values from librato
    alertHandler = (firstStart) =>
      timestamp = Math.floor Date.now()/1000
      @librato.getAverageRegressions metric, source, timestamp, config.regressions, config.grouped_values, (error, result) =>
        return if error or not result?.last

        # update config
        config = @findAlerts metric, source
        if !config
          console.log "[#{metric} - #{source}] config not found"
          clearTimeout @alerts[incident].timeoutId
          delete @alerts[incident]
          @pagerduty.resolveIncident service_key, incident, description, result.last
          return

        alertTriggered  = false
        @alerts[incident].lastMeasurement= result.last
        @alerts[incident].lastCheck = Date.now()
        
        # trigger pagerduty immediately, if hard limit is exceeded
        if (!Statistic.inRange config.lower_limit, result.last.value, config.upper_limit)
          description = "[#{metric} - #{source}] - limits exceeded: #{config.lower_limit} < #{result.last.value} < #{config.upper_limit}"
          alertTriggered = true
          @alerts[incident].triggerType = 'exceeding'
        else if config.warn_time and config.warn_time?
        # Calculating the exceeded timelimit and current time in model using the linear regression model
          warn_time_value = (result.last.measure_time+config.warn_time)*result.slope+result.intercept
          if (!Statistic.inRange config.lower_limit, warn_time_value,  config.upper_limit)        
            description = "[#{metric} - #{source}] - limit will be exceeded within warn time: #{config.lower_limit} < #{warn_time_value } < #{config.upper_limit}"
            alertTriggered = true
            @alerts[incident].triggerType = 'prediction'

        if alertTriggered
          if (firstStart)
            data =  clone(@alerts[incident])
            data.timeoutId = data.timeoutId?
            @pagerduty.triggerIncident service_key, incident, description, data 
            @alerts[incident].timeoutId = setInterval alertHandler, interval , false if interval
            @alerts[incident].pagerDuty = true
        else
          # auto resolve incident if everything is ok
          description = "alert resolved: #{config.lower_limit} < #{result.last.value} < #{config.upper_limit}"
          console.log "alert [#{metric} - #{source}] resolved"
          clearTimeout @alerts[incident].timeoutId
          delete @alerts[incident]
          @pagerduty.resolveIncident service_key, incident, description, result.last 

    # setTimeout to ignore short peaks
    console.log "Processing incoming alarm [#{metric} - #{source}] ..."
    if timeout
      @alerts[incident].timeoutId = setTimeout alertHandler, timeout, true
    else
      alertHandler true
  
  findAlerts: (metric, source, alerts=@config.librato['alerts']) ->

    found = false
    defaultAlert = {}
    for config in alerts
      defaultAlert = config if config.alert == 'default'
      continue if config.alert != metric

      found = true
      if config.blacklist and source
        blacklisted = config.blacklist.split(',').some (value) ->
          new RegExp(value.trim(), "gi").test source;
        continue if blacklisted
      
      if config.whitelist and source
        whitelisted = config.whitelist.split(',').some (value) ->
          new RegExp(value.trim(), "gi").test source;
        continue unless whitelisted 

      if !config.lower_limit and !config.upper_limit and !config.warn_time
        console.log "missing limits"
        continue

      return config

    if found
      return false
    else
      return defaultAlert