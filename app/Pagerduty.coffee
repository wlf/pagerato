restler = require 'restler'

module.exports = class Pagerduty
  
  constructor: (@url) ->
  
  triggerIncident: (service_key, incident_key, description="", details={}) ->
    
    data =
      service_key: service_key
      incident_key: incident_key
      event_type: 'trigger'
      description: description
      details: details

    @request data

  resolveIncident: (service_key, incident_key, description="", details={}) ->

    data =
      service_key: service_key
      incident_key: incident_key
      event_type: 'resolve'
      description: description
      details: details

    @request data

  request: (data) ->

    restler.post @url,
      data: JSON.stringify(data)
      headers: 
        'Content-Type': 'application/json'