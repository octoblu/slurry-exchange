_                = require 'lodash'
MeshbluConfig    = require 'meshblu-config'
path             = require 'path'
Slurry           = require 'slurry-core'
OctobluStrategy  = require 'slurry-core/octoblu-strategy'
MessageHandler   = require 'slurry-core/message-handler'
ConfigureHandler = require 'slurry-core/configure-handler'
SlurrySpreader   = require 'slurry-spreader'
SigtermHandler   = require 'sigterm-handler'

ApiStrategy      = require './src/api-strategy'

MISSING_SERVICE_URL         = 'Missing required environment variable: SLURRY_EXCHANGE_SERVICE_URL'
MISSING_MANAGER_URL         = 'Missing required environment variable: SLURRY_EXCHANGE_MANAGER_URL'
MISSING_APP_OCTOBLU_HOST    = 'Missing required environment variable: APP_OCTOBLU_HOST'
MISSING_SPREADER_REDIS_URI  = 'Missing required environment variable: SLURRY_SPREADER_REDIS_URI'
MISSING_SPREADER_NAMESPACE  = 'Missing required environment variable: SLURRY_SPREADER_NAMESPACE'
MISSING_MESHBLU_PRIVATE_KEY = 'Missing required environment variable: MESHBLU_PRIVATE_KEY'

class Command
  getOptions: =>
    throw new Error MISSING_SPREADER_REDIS_URI if _.isEmpty process.env.SLURRY_SPREADER_REDIS_URI
    throw new Error MISSING_SPREADER_NAMESPACE if _.isEmpty process.env.SLURRY_SPREADER_NAMESPACE
    throw new Error MISSING_SERVICE_URL if _.isEmpty process.env.SLURRY_EXCHANGE_SERVICE_URL
    throw new Error MISSING_MANAGER_URL if _.isEmpty process.env.SLURRY_EXCHANGE_MANAGER_URL
    throw new Error MISSING_APP_OCTOBLU_HOST if _.isEmpty process.env.APP_OCTOBLU_HOST
    throw new Error MISSING_MESHBLU_PRIVATE_KEY if _.isEmpty process.env.MESHBLU_PRIVATE_KEY

    meshbluConfig   = new MeshbluConfig().toJSON()
    apiStrategy     = new ApiStrategy process.env
    octobluStrategy = new OctobluStrategy process.env, meshbluConfig
    meshbluConfig   = new MeshbluConfig().toJSON()
    apiStrategy     = new ApiStrategy process.env
    octobluStrategy = new OctobluStrategy process.env, meshbluConfig
    @slurrySpreader  = new SlurrySpreader
      redisUri: process.env.SLURRY_SPREADER_REDIS_URI
      namespace: process.env.SLURRY_SPREADER_NAMESPACE
      privateKey: process.env.MESHBLU_PRIVATE_KEY

    jobsPath = path.join __dirname, 'src/jobs'
    configurationsPath = path.join __dirname, 'src/configurations'

    return {
      apiStrategy:     apiStrategy
      deviceType:      'slurry:exchange'
      disableLogging:  process.env.DISABLE_LOGGING == "true"
      meshbluConfig:   meshbluConfig
      messageHandler:   new MessageHandler {jobsPath}
      configureHandler: new ConfigureHandler {@slurrySpreader, configurationsPath, meshbluConfig}
      octobluStrategy: octobluStrategy
      port:            process.env.PORT || 80
      appOctobluHost:  process.env.APP_OCTOBLU_HOST
      serviceUrl:      process.env.SLURRY_EXCHANGE_SERVICE_URL
      userDeviceManagerUrl: process.env.SLURRY_EXCHANGE_MANAGER_URL
      staticSchemasPath: process.env.SLURRY_EXCHANGE_STATIC_SCHEMAS_PATH
      skipRedirectAfterApiAuth: true
    }

  run: =>
    server = new Slurry @getOptions()
    @slurrySpreader.start (error) =>
      console.error "SlurrySpreader Error", error.stack if error?
      throw error if error?
      server.run (error) =>
        console.error "Server.run Error", error.stack if error?
        throw error if error?

        {address,port} = server.address()
        console.log "Server listening on #{address}:#{port}"

    sigtermHandler = new SigtermHandler { events: ['SIGTERM', 'SIGINT'] }
    sigtermHandler.register @slurrySpreader?.stop
    sigtermHandler.register server?.stop

command = new Command()
command.run()
