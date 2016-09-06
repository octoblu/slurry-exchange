_ = require 'lodash'

AuthenticatedRequest = require './authenticated-request'
ExchangeStream = require '../streams/exchange-stream'

getStreamingEventsRequest = require '../templates/getStreamingEventsRequest'
getSubscriptionRequest    = require '../templates/getSubscriptionRequest'
getUserSettingsRequest    = require '../templates/getUserSettingsRequest'

SUBSCRIPTION_ID_PATH = 'Envelope.Body.SubscribeResponse.ResponseMessages.SubscribeResponseMessage.SubscriptionId'

class Exchange
  constructor: ({protocol, hostname, port, @username, @password}) ->
    throw new Error 'Missing required parameter: hostname' unless hostname?
    throw new Error 'Missing required parameter: username' unless @username?
    throw new Error 'Missing required parameter: password' unless @password?

    protocol ?= 'https'
    port ?= 443

    @connectionOptions = {protocol, hostname, port, @username, @password}
    @authenticatedRequest = new AuthenticatedRequest @connectionOptions

  getStreamingEvents: ({distinguisedFolderId}, callback) =>
    @_getSubscriptionId {distinguisedFolderId}, (error, subscriptionId) =>
      return callback error if error?

      @authenticatedRequest.getOpenEwsRequest body: getStreamingEventsRequest({ subscriptionId }), (error, request) =>
        return callback error if error?
        return callback null, new ExchangeStream {@connectionOptions, request}

  whoami: (callback) =>
    @authenticatedRequest.doAutodiscover body: getUserSettingsRequest({@username}), (error, response) =>
      return callback error if error?
      @_parseUserSettingsResponse response, callback

  _getSubscriptionId: ({distinguisedFolderId}, callback) =>
    @authenticatedRequest.doEws body: getSubscriptionRequest({distinguisedFolderId}), (error, response) =>
      return callback error if error
      return callback null, _.get(response, SUBSCRIPTION_ID_PATH)

  _parseUserSettingsResponse: (response, callback) =>
    UserResponse = _.get response, 'Envelope.Body.GetUserSettingsResponseMessage.Response.UserResponses.UserResponse'
    UserSettings = _.get UserResponse, 'UserSettings.UserSetting'

    name = _.get _.find(UserSettings, Name: 'UserDisplayName'), 'Value'
    id   = _.get _.find(UserSettings, Name: 'UserDeploymentId'), 'Value'

    return callback null, { name, id }

module.exports = Exchange
