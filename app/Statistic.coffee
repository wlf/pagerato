module.exports = class Statistic

  @mean: (values) ->
    return 0 if values.length == 0
    values.reduce((t, s) -> t + s)/values.length

  @inRange: (lower, value, upper) ->
    if lower? and lower!="" and value <= lower
      return false
    if upper? and upper!="" and value >= upper
      return false
    return true

  @linearRegression: (values) ->
    
    # compute the arithmetic mean for x and y
    avg = (values).reduce (prevValue, curValue) ->
      return [prevValue[0] + curValue[0], prevValue[1] + curValue[1]]
    , [0,0]
    avg = avg.map (value) -> value/values.length

    # compute variance, covariance
    covariance = variance = s_yy = 0
    for value in values
      covariance += (value[0]-avg[0]) * (value[1]-avg[1])
      s_yy += Math.pow value[1]-avg[1], 2
      variance += Math.pow value[0]-avg[0], 2

    # compute and return intercept, slope and coefficient of determination
    slope = covariance/variance
    intercept = avg[1]-slope*avg[0]
  
    return {
      intercept: intercept 
      slope : slope
      r_2: Math.pow(covariance,2)/(variance*s_yy)
    }