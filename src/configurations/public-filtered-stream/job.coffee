http    = require 'http'
_       = require 'lodash'
Twitter = require 'twitter'
MeshbluHttp = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'

class PublicFilteredStream
  constructor: ({@encrypted, @auth, @userDeviceUuid}) ->
    meshbluConfig = new MeshbluConfig({@auth}).toJSON()
    meshbluHttp = new MeshbluHttp meshbluConfig
    @twitter = new Twitter({
      consumer_key:        process.env.SLURRY_TWITTER_TWITTER_CLIENT_ID
      consumer_secret:     process.env.SLURRY_TWITTER_TWITTER_CLIENT_SECRET
      access_token_key:    @encrypted.secrets.credentials.token
      access_token_secret: @encrypted.secrets.credentials.secret
    })
    @_throttledMessage = _.throttle meshbluHttp.message, 500, leading: true, trailing: false

  do: ({slurry}, callback) =>
    metadata =
      track: _.join(slurry.track, ',')
      follow: _.join(slurry.follow, ',')

    @twitter.stream 'statuses/filter', metadata, (stream) =>
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
