_             = require 'lodash'
Bourse        = require 'bourse'
MeshbluHttp   = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'
SlurryStream  = require 'slurry-core/slurry-stream'
debug         = require('debug')('slurry-exchange:default:job')

PING_INTERVAL = 6 * 60 * 60 * 1000 # every 6 hours

class CalendarStream
  constructor: ({encrypted, @auth, @userDeviceUuid}) ->
    debug 'constructing stream', @auth.uuid, encrypted?.id
    meshbluConfig = new MeshbluConfig({@auth}).toJSON()
    meshbluHttp = new MeshbluHttp meshbluConfig
    @_throttledMessage = _.throttle meshbluHttp.message, 1000

    {hostname, domain} = encrypted.secrets
    {@username, password} = encrypted.secrets.credentials

    @bourse = new Bourse {hostname, domain, @username, password}

  do: ({}, callback) =>
    @bourse.getStreamingEvents distinguishedFolderId: 'calendar', (error, stream) =>
      if error? && error.message == 'ETIMEDOUT'
        debug 'ETIMEDOUT', @userDeviceUuid
        return callback null, null

      debug "Error for #{@username} [#{error.code}]:", error.stack if error?
      return callback error if error?

      @_pingInterval = setInterval =>
        message =
          devices: ['*']
          metadata: { hostname: process.env.HOSTNAME }
          data: ping: Date.now()

        @_throttledMessage message, as: @userDeviceUuid, (error) =>
          console.error error.stack if error?
      , PING_INTERVAL

      slurryStream = new SlurryStream

      slurryStream.on 'shutdown', =>
        debug 'on shutdown', @userDeviceUuid
        clearInterval @_pingInterval if @_pingInterval?
        stream.destroy()

      slurryStream.destroy = =>
        debug 'slurryStream.destroy', @userDeviceUuid
        clearInterval @_pingInterval if @_pingInterval?
        stream.destroy()

      stream.on 'end', =>
        debug 'on end', @userDeviceUuid
        clearInterval @_pingInterval if @_pingInterval?
        slurryStream.emit 'close'

      stream.on 'close', =>
        debug 'on close', @userDeviceUuid
        clearInterval @_pingInterval if @_pingInterval?
        slurryStream.emit 'close'

      stream.on 'data', (event) =>
        debug 'on data', @userDeviceUuid
        message =
          devices: ['*']
          metadata: { hostname: process.env.HOSTNAME }
          data: event

        @_throttledMessage message, as: @userDeviceUuid, (error) =>
          console.error error.stack if error?

      stream.on 'error', (error) =>
        debug 'on error', @userDeviceUuid, error.stack
        # @emit 'delay', error if error.message == 'ETIMEDOUT'
        slurryStream.emit 'delay', error

      return callback null, slurryStream

  _userError: (code, message) =>
    error = new Error message
    error.code = code
    return error

module.exports = CalendarStream
