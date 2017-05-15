_             = require 'lodash'
Bourse        = require 'bourse'
UUID          = require 'uuid'
MeshbluHttp   = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'
SlurryStream  = require 'slurry-core/slurry-stream'
debug         = require('debug')('slurry-exchange:default:job')

PING_INTERVAL = 60 * 60 * 1000 # every 1 hours
# PING_INTERVAL = 60 * 1000 # every 1 minute

class CalendarStream
  constructor: ({encrypted, @auth, @userDeviceUuid}) ->
    debug 'constructing stream', @auth.uuid, encrypted?.id
    meshbluConfig = new MeshbluConfig({@auth}).toJSON()
    meshbluHttp = new MeshbluHttp meshbluConfig
    @_throttledMessage = _.throttle meshbluHttp.message, 1000

    {hostname, domain} = encrypted.secrets
    {@username, password} = encrypted.secrets.credentials
    @id = UUID.v4()
    @bourse = new Bourse {hostname, domain, @username, password}

  _getMessage: (event) =>
    return {
      devices: ['*']
      metadata: { hostname: process.env.HOSTNAME, @id }
      data: event
    }

  do: ({}, callback) =>
    @bourse.authenticate (error, authenticated) =>
      if error?
        error.shouldRetry = true
        return callback error
      unless authenticated
        return callback @_unrecoverableError(401, "User #{@username} is unauthenticated")

      @bourse.getStreamingEvents distinguishedFolderId: 'calendar', (error, stream) =>
        if error?
          error.shouldRetry = true
          debug "Error for #{@username} [#{error.message}]:", error.message
          return callback error

        setTimeout (=> slurryStream.emit('close')), 29 * 1000
        @_pingInterval = setInterval @_ping, PING_INTERVAL
        @_ping()

        slurryStream = new SlurryStream

        slurryStream.destroy = =>
          debug 'slurryStream.destroy', @userDeviceUuid
          @shouldBeDead = 'destroy'
          clearInterval @_pingInterval if @_pingInterval?
          stream.destroy()

        stream.on 'end', =>
          debug 'on end', @userDeviceUuid
          @shouldBeDead = 'end'
          clearInterval @_pingInterval if @_pingInterval?
          slurryStream.emit 'close'

        stream.on 'close', =>
          debug 'on close', @userDeviceUuid
          @shouldBeDead = 'close'
          clearInterval @_pingInterval if @_pingInterval?
          slurryStream.emit 'close'

        stream.on 'data', (event) =>
          debug 'on data', @userDeviceUuid
          console.error "#{@userDeviceUuid} should be dead: #{@shouldBeDead}" if @shouldBeDead?
          message = @_getMessage event
          @_throttledMessage message, as: @userDeviceUuid, (error) =>
            console.error error.stack if error?

        stream.on 'error', (error) =>
          debug 'on error', @userDeviceUuid, error.stack
          error.shouldRetry = true
          slurryStream.emit 'delay', error

        return callback null, slurryStream

  _ping: =>
    message = @_getMessage ping: Date.now()
    @_throttledMessage message, as: @userDeviceUuid, (error) =>
      console.error error.stack if error?

  _unrecoverableError: (code, message) =>
    error = @_userError code, message
    error.shouldRetry = false
    error

  _userError: (code, message) =>
    error = new Error message
    error.code = code
    return error

module.exports = CalendarStream
