_                = require 'lodash'
PassportStrategy = require 'passport-strategy'
url              = require 'url'
Bourse           = require 'bourse'
async            = require 'async'

class ExchangeStrategy extends PassportStrategy
  constructor: (env) ->
    env ?= process.env
    if _.isEmpty env.SLURRY_EXCHANGE_EXCHANGE_CALLBACK_URL
      throw new Error('Missing required environment variable: SLURRY_EXCHANGE_EXCHANGE_CALLBACK_URL')
    if _.isEmpty env.SLURRY_EXCHANGE_EXCHANGE_AUTH_URL
      throw new Error('Missing required environment variable: SLURRY_EXCHANGE_EXCHANGE_AUTH_URL')
    if _.isEmpty env.SLURRY_EXCHANGE_EXCHANGE_SCHEMA_URL
      throw new Error('Missing required environment variable: SLURRY_EXCHANGE_EXCHANGE_SCHEMA_URL')
    if _.isEmpty env.SLURRY_EXCHANGE_EXCHANGE_FORM_SCHEMA_URL
      throw new Error('Missing required environment variable: SLURRY_EXCHANGE_EXCHANGE_FORM_SCHEMA_URL')

    @_authorizationUrl = env.SLURRY_EXCHANGE_EXCHANGE_AUTH_URL
    @_callbackUrl      = env.SLURRY_EXCHANGE_EXCHANGE_CALLBACK_URL
    @_schemaUrl        = env.SLURRY_EXCHANGE_EXCHANGE_SCHEMA_URL
    @_formSchemaUrl    = env.SLURRY_EXCHANGE_EXCHANGE_FORM_SCHEMA_URL

    super

  authenticate: (req) -> # keep this skinny
    {bearerToken} = req.meshbluAuth
    {hostname, domain, username, password} = req.body
    return @redirect @authorizationUrl({bearerToken}) unless password?
    @_retry @getUserFromExchange, {hostname, domain, username, password}, (error, user) =>
      return @fail 401 if error? && error.code < 500
      return @error error if error?
      return @fail 404 unless user?
      @success {
        id:       user.id
        username: user.name
        secrets:
          hostname: hostname
          domain:   domain
          credentials:
            username: username
            password: password
      }

  authorizationUrl: ({bearerToken}) ->
    {protocol, hostname, port, pathname} = url.parse @_authorizationUrl
    query = {
      postUrl: @postUrl()
      schemaUrl: @schemaUrl()
      formSchemaUrl: @formSchemaUrl()
      bearerToken: bearerToken
    }
    return url.format {protocol, hostname, port, pathname, query}

  formSchemaUrl: ->
    @_formSchemaUrl

  getUserFromExchange: ({hostname, domain, username, password}, callback) =>
    bourse = new Bourse({ hostname, domain, username, password })
    bourse.whoami (error, user) =>
      return callback error if error?
      callback null, {
        id: "#{username}@#{hostname}"
        name: user.name
      }

  postUrl: ->
    {protocol, hostname, port} = url.parse @_callbackUrl
    return url.format {protocol, hostname, port, pathname: '/auth/api/callback'}

  schemaUrl: ->
    @_schemaUrl

  _retry: (fn, options, callback) =>
    async.retry 5, async.apply(fn, options), callback

  _userError: (code, message) =>
    error = new Error message
    error.code = code
    return error

module.exports = ExchangeStrategy
