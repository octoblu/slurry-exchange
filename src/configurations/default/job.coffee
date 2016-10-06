MeshbluHttp   = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'
SlurryStream  = require 'slurry-core/slurry-stream'
# Exchange      = require '../../services/exchange-service'
debug = require('debug')('slurry-exchange:default:job')
Bourse        = require 'bourse'

class CalendarStream
  constructor: ({encrypted, @auth, @userDeviceUuid}) ->
    debug 'constructing stream', @auth.uuid
    meshbluConfig = new MeshbluConfig({@auth}).toJSON()
    meshbluHttp = new MeshbluHttp meshbluConfig
    @_throttledMessage = meshbluHttp.message

    {hostname, domain} = encrypted.secrets
    {username, password} = encrypted.secrets.credentials

    @bourse = new Bourse {hostname, domain, username, password}

  do: ({}, callback) =>
    @bourse.getStreamingEvents distinguishedFolderId: 'calendar', (error, stream) =>
      return callback error if error?

      slurryStream = new SlurryStream
      slurryStream.destroy = =>
        stream.destroy()

      stream.on 'end', =>
        slurryStream.emit 'close'

      stream.on 'close', =>
        slurryStream.emit 'close'

      stream.on 'data', (event) =>
        message =
          devices: ['*']
          metadata: {}
          data: event

        @_throttledMessage message, as: @userDeviceUuid, (error) =>
          slurryStream.emit 'error', error if error?

      stream.on 'error', (error) =>
        slurryStream.emit 'error', error

      return callback null, slurryStream

  _userError: (code, message) =>
    error = new Error message
    error.code = code
    return error

module.exports = CalendarStream
