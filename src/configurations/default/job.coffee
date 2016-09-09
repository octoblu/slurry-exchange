MeshbluHttp   = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'
SlurryStream  = require 'slurry-core/slurry-stream'
Exchange      = require '../../services/exchange-service'

class CalendarStream
  constructor: ({encrypted, @auth, @userDeviceUuid}) ->
    meshbluConfig = new MeshbluConfig({@auth}).toJSON()
    meshbluHttp = new MeshbluHttp meshbluConfig
    @_throttledMessage = meshbluHttp.message

    {hostname, domain} = encrypted.secrets
    {username, password} = encrypted.secrets.credentials

    @exchange = new Exchange {hostname, domain, username, password}

  do: ({}, callback) =>
    @exchange.getStreamingEvents distinguisedFolderId: 'calendar', (error, stream) =>
      return callback error if error?

      slurryStream = new SlurryStream
      slurryStream.destroy = =>
        stream.destroy()

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
