_ = require 'lodash'
PassportStrategy = require 'passport-strategy'


class ExchangeStrategy extends PassportStrategy
  constructor: (env) ->
    env ?= process.env
    throw new Error('Missing required environment variable: SLURRY_EXCHANGE_EXCHANGE_CLIENT_ID')     if _.isEmpty env.SLURRY_EXCHANGE_EXCHANGE_CLIENT_ID
    throw new Error('Missing required environment variable: SLURRY_EXCHANGE_EXCHANGE_CLIENT_SECRET') if _.isEmpty env.SLURRY_EXCHANGE_EXCHANGE_CLIENT_SECRET
    throw new Error('Missing required environment variable: SLURRY_EXCHANGE_EXCHANGE_CALLBACK_URL')  if _.isEmpty env.SLURRY_EXCHANGE_EXCHANGE_CALLBACK_URL

    options = {
      clientID:     env.SLURRY_EXCHANGE_EXCHANGE_CLIENT_ID
      clientSecret: env.SLURRY_EXCHANGE_EXCHANGE_CLIENT_SECRET
      callbackUrl:  env.SLURRY_EXCHANGE_EXCHANGE_CALLBACK_URL
    }

    super options, @onAuthorization

  onAuthorization: (accessToken, refreshToken, profile, callback) =>
    callback null, {
      id: profile.id
      username: profile.username
      secrets:
        credentials:
          secret: accessToken
          refreshToken: refreshToken
    }

module.exports = ExchangeStrategy
