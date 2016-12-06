Bourse        = require 'bourse'
MeshbluHttp   = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'
SlurryStream  = require 'slurry-core/slurry-stream'
debug         = require('debug')('slurry-exchange:default:job')

PING_INTERVAL = 6 * 60 * 60 * 1000 # every 6 hours

class CalendarStream
  constructor: ({encrypted, @auth, @userDeviceUuid}) ->
    debug 'constructing stream', @auth.uuid, encrypted
    meshbluConfig = new MeshbluConfig({@auth}).toJSON()
    meshbluHttp = new MeshbluHttp meshbluConfig
    @_throttledMessage = meshbluHttp.message

    {hostname, domain} = encrypted.secrets
    {username, password} = encrypted.secrets.credentials

    @bourse = new Bourse {hostname, domain, username, password}

  do: ({}, callback) =>
    @bourse.getStreamingEvents distinguishedFolderId: 'calendar', (error, stream) =>
      return callback null, null if error? && error.message == 'ETIMEDOUT'
      return callback error if error?

      slurryStream = new SlurryStream
      slurryStream.destroy = =>
        debug 'slurryStream.destroy'
        clearInterval @_pingInterval if @_pingInterval?
        stream.destroy()

      stream.on 'end', =>
        clearInterval @_pingInterval if @_pingInterval?
        slurryStream.emit 'close'

      stream.on 'close', =>
        clearInterval @_pingInterval if @_pingInterval?
        slurryStream.emit 'close'

      @_pingInterval = setInterval =>
        message =
          devices: ['*']
          metadata: {}
          data: ping: Date.now()

        @_throttledMessage message, as: @userDeviceUuid, (error) =>
          slurryStream.emit 'error', error if error?
      , PING_INTERVAL

      stream.on 'data', (event) =>
        message =
          devices: ['*']
          metadata: {}
          data: event

        @_throttledMessage message, as: @userDeviceUuid, (error) =>
          return slurryStream.emit 'delay', error if error? && error.code > 499
          slurryStream.emit 'error', error if error?

      stream.on 'error', (error) =>
        @emit 'delay', error if error.message == 'ETIMEDOUT'
        slurryStream.emit 'error', error

      return callback null, slurryStream

  _userError: (code, message) =>
    error = new Error message
    error.code = code
    return error

module.exports = CalendarStream
