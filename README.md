INSTALL
---------------------
- install [nodejs](http://nodejs.org/)
- install required nodejs packages with `npm install`
- install jake `npm install jake -g`

Running
--------------------
Create a new server and call `start()`.

    server = new Server config, port
    server.start()

Configuration
--------------------

The config json should have the following structure.

    librato:
      url: 'https://metrics-api.librato.com/v1'
      username: ''
      password: ''
      secret: ''
    pagerduty:
      service_key:
        '': '' 
      url: 'https://events.pagerduty.com/generic/2010-04-15/create_event.json'
    alerts:
      upper_limit: ''
      lower_limit: ''
      warn_time: ''
      timeout: ''
      interval: ''
      regressions: ''
      grouped_values: ''
      pagerduty_service: ''
      whitelist: ''
      blacklist: ''
    ,
      ...
    update: (callback) ->
      updateConfiguration callback

If you provide an optional update function in the configuration object, this function will be called if you get a request with `?secret=&refresh=1`. This is a way to update the configuration dynamically.

For Wooga purpose the config of the `lib/apis.yml` file has to be set for the evironment var: `CONFIG`. 
And the alert configuration is loaded from gums. You can update the gums configuration 
by [Google Docs](https://docs.google.com/a/wooga.net/spreadsheet/ccc?key=0AifOjKvdvPu_dC01NzlIbmRqOGhzWlhVZmlPcmREYXc#gid=0) 
([documentation](https://docs.google.com/a/wooga.net/spreadsheet/ccc?key=0AifOjKvdvPu_dC01NzlIbmRqOGhzWlhVZmlPcmREYXc#gid=1)).

Testing Locally
---------------------
- update CONFIG environment var with `export CONFIG="cat lib/apis.yml"`
- start the app with `coffee app/app.js` 
or with [`foreman start`](https://devcenter.heroku.com/articles/procfile#developing-locally-with-foreman)

You can use the jake task `jake start`

Deployment (Staging)
---------------------
    heroku config:add BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-nodejs.git
    heroku config:add CONFIG="`cat lib/apis.yml`" --app mops-alerts-staging
    git add remote git@heroku.com:mops-alerts-staging.git
    git commit -a -m 'made some local changes'
    git push staging
    
You can use the jake task `jake deploy:staging`.

Deployment (Production)
---------------------
    heroku config:add BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-nodejs.git
    heroku config:add CONFIG="`cat lib/apis.yml`" --app mops-alerts
    git add remote git@heroku.com:mops-alerts.git
    git commit -a -m 'made some local changes'
    git push staging

You can use the jake task `jake deploy:production`.

Tests
---------------------
    ./node_modules/vows/bin/vows test/*.coffee --spec

You can also use the jake task `jake tests`.

Status Information
---------------------
You can use the following jake task to get current status informations:

    # get current alert configuration
    jake info:staging:config
    jake info:production:config
    
    # get current alert configuration
    jake info:staging:alerts
    jake info:production:alerts
    
    # get current librato values jake info:value[metric,source?]
    jake info:value[mops.consumers.nanigans.visit.ok]
    jake info:value[mops.consumers.nanigans.visit.ok,dd.visit.ok]

    # compute regression based on current librato values jake info:value[metric,source?]
    jake info:regression[mops.consumers.nanigans.visit.ok]
    jake info:regression[mops.consumers.nanigans.visit.ok,dd.visit.ok]