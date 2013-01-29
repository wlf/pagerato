restler = require 'restler'
Statistic = require './Statistic'

module.exports = class Librato
  
  constructor: (@baseUrl, @username, @password) ->
  
  # compute a average regression over a number of linear regressions
  getAverageRegressions: (metric, source, end_date, count, group_count,  cb) ->
    
    # TODO FIXME: support higher group count as fitting on one page
    if (100 % group_count!=0)
      throw "group value should be a integral factor of 100"
    
    query =
      end_time: end_date
      resolution: 1
    
    query['sources[]'] = [source] if source
    
    # request metrics from librato, callback may be called several times, regressions are collected in the regression var
    regressions = []
    @iterateMetrics metric, query, count * group_count, (error, metrics, completed) ->
      if error
        cb(error)
        return

      # compute regression on grouped metric values
      start = 0
      while start < metrics.length
        ranges = metrics[start + 1..start + group_count]
        ranges = ranges.map (metric) -> [metric.measure_time, metric.value]
        regressions.push Statistic.linearRegression ranges
        start  += group_count

      # compute average regression of all collected regressions
      if completed
        cb false,
          last: metrics[metrics.length-1]
          slope: Statistic.mean(regressions.map((regression) -> regression.slope))
          intercept: Statistic.mean(regressions.map((regression) -> regression.intercept))
          r_2: Statistic.mean(regressions.map((regression) -> regression.r_2))

  # iterate over Metric data with pagination, call callback with completed=true after all data is loaded
  iterateMetrics: (metric, query, count, cb, found=0) ->
    
    # supports only summarized metrics
    query['summarize_sources'] = 1
    query['count'] if count < 100 
    
    @request "metrics/#{metric}", query, (error, metrics) =>
      found += metrics?.measurements?.all?.length or 0
      completed = metrics?.query?.next_time is undefined or found >= count
      cb error, metrics?.measurements?.all or [], completed
      
      # recursive next page loading
      if not completed and not error
        query['start_time'] = metrics.query.next_time
        @iterateMetrics metric, query, count, cb, found
  
  # generic librato request method, handle request callbacks and basic auth
  request: (path, data, cb) ->
    # start request
    request = restler.get "#{@baseUrl}/#{path}",
      username: @username
      password: @password
      data: data

    # add request handlers
    request.on 'success', (data) ->
      cb(false, data)
    request.on 'fail', (data, response) ->
      cb(data)
    request.on 'error', (data, response) ->
      cb(data)
  
  # get librato alert by id
  getAlert: (id, cb) ->
    @request "alerts/#{id}", (error, alert) ->
      cb error, alert
      