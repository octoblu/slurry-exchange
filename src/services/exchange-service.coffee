_ = require 'lodash'
{challengeHeader, responseHeader} = require 'ntlm'
request = require 'request'
url = require 'url'
xml2js = require 'xml2js'

ExchangeStream = require '../streams/exchange-stream'

getStreamingEventsRequest = require './getStreamingEventsRequest'
getSubscriptionRequest    = require './getSubscriptionRequest'
getUserSettingsRequest    = require './getUserSettingsRequest'

EWS_PATH = '/EWS/Exchange.asmx'
AUTODISCOVER_PATH = '/autodiscover/autodiscover.svc'
SUBSCRIPTION_ID_PATH = 'Envelope.Body.SubscribeResponse.ResponseMessages.SubscribeResponseMessage.SubscriptionId'

class Exchange
  constructor: ({@protocol, @hostname, @port, @username, @password}) ->
    throw new Error 'Missing required parameter: hostname' unless @hostname?
    throw new Error 'Missing required parameter: username' unless @username?
    throw new Error 'Missing required parameter: password' unless @password?

    @protocol ?= 'https'
    @port ?= 443

  getStreamingEvents: ({distinguisedFolderId}, callback) =>
    @_getSubscriptionId {distinguisedFolderId}, (error, subscriptionId) =>
      return callback error if error?

      @_getRequest pathname: EWS_PATH, (error, authenticatedRequest) =>
        return callback error if error?

        req = authenticatedRequest.post body: getStreamingEventsRequest({ subscriptionId })
        return callback null, new ExchangeStream {request: req}

  whoami: (callback) =>
    @_getRequest pathname: AUTODISCOVER_PATH, (error, authenticatedRequest) =>
      return callback error if error?

      authenticatedRequest.post {body: getUserSettingsRequest({@username})}, (error, response, body) =>
        return callback error if error?

        @_parseUserSettingsResponse body, callback

  _getRequest: ({pathname}, callback) =>
    urlStr = url.format {@protocol, @hostname, @port, pathname}
    options = {
      url: urlStr
      forever: true
      headers:
        'Authorization': challengeHeader('', 'citrite.net')
    }

    request.post options, (error, response) =>
      return callback error if error?
      unless response.statusCode == 401
        return callback new Error("Expected status: 401, received #{response.statusCode}")

      headers = {
        'Authorization': responseHeader(response, urlStr, '', @username, @password)
        'Content-Type': 'text/xml; charset=utf-8'
      }

      callback null, request.defaults(_.defaults({ headers }, options))

  _getSubscriptionId: ({distinguisedFolderId}, callback) =>
    @_getRequest pathname: EWS_PATH, (error, authenticatedRequest) =>
      return callback error if error?

      body = getSubscriptionRequest({distinguisedFolderId})
      authenticatedRequest.post {body}, (error, response, body) =>
        return callback error if error

        @_xml2js body, (error, obj) =>
          return callback error if error
          return callback null, _.get(obj, SUBSCRIPTION_ID_PATH)

  _parseUserSettingsResponse: (xml, callback) =>
    @_xml2js xml, (error, obj) =>
      return callback error if error?

      UserResponse = _.get obj, 'Envelope.Body.GetUserSettingsResponseMessage.Response.UserResponses.UserResponse'
      UserSettings = _.get UserResponse, 'UserSettings.UserSetting'

      name = _.find(UserSettings, Name: 'UserDisplayName').Value
      id   = _.find(UserSettings, Name: 'UserDeploymentId').Value

      return callback null, { name, id }

  _xml2js: (xml, callback) =>
    options = {
      tagNameProcessors: [xml2js.processors.stripPrefix]
      explicitArray: false
    }
    xml2js.parseString xml, options, callback

module.exports = Exchange
