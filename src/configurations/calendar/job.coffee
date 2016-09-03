_       = require 'lodash'
MeshbluHttp   = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'

Exchange = require '../services/exchange-service'

class PublicFilteredStream
  constructor: ({encrypted, @auth, @userDeviceUuid}) ->
    meshbluConfig = new MeshbluConfig({@auth}).toJSON()
    meshbluHttp = new MeshbluHttp meshbluConfig
    @_throttledMessage = meshbluHttp.message

    {hostname, domain} = encrypted
    {username, password} = encrypted.secrets

    @exchange = new Exchange {hostname, domain, username, password}


  do: ({slurry}, callback) =>
    metadata =
      track: _.join(slurry.track, ',')
      follow: _.join(slurry.follow, ',')

    @exchange.getStreamingEvents distinguisedFolderId: 'calendar', (error, stream) =>
      return callback error if error?
      stream.on 'data', (event) =>
        message =
          devices: ['*']
          metadata: metadata
          data: event

        @_throttledMessage message, as: @userDeviceUuid, (error) =>
          console.error error if error?

      stream.on 'error', (error) =>
        console.error error.stack

      return callback null, stream

  _userError: (code, message) =>
    error = new Error message
    error.code = code
    return error

module.exports = PublicFilteredStream
