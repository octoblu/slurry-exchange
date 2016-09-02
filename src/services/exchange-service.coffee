_ = require 'lodash'
{challengeHeader, responseHeader} = require 'ntlm'
request = require 'request'
url = require 'url'
xml2js = require 'xml2js'

getUserSettingsRequest = require './getUserSettingsRequest'

# EWS_PATH = '/EWS/Exchange.asmx'
AUTODISCOVER_PATH = '/autodiscover/autodiscover.svc'

class Exchange
  constructor: ({protocol, hostname, port, @username, @password}) ->
    throw new Error 'Missing required parameter: hostname' unless hostname?
    throw new Error 'Missing required parameter: username' unless @username?
    throw new Error 'Missing required parameter: password' unless @password?

    protocol ?= 'https'
    port ?= 443

    @url = url.format {protocol, hostname, port, pathname: AUTODISCOVER_PATH}

  whoami: (callback) =>
    @_getRequest (error, authenticatedRequest) =>
      return callback error if error?

      authenticatedRequest.post {body: getUserSettingsRequest({@username})}, (error, response, body) =>
        return callback error if error?

        @_parseUserSettingsResponse body, callback

  _getRequest: (callback) =>
    options = {
      url: @url
      forever: true
      headers:
        'Authorization': challengeHeader('', 'citrite.net')
    }

    request.post options, (error, response) =>
      return callback error if error?
      unless response.statusCode == 401
        return callback new Error("Expected status: 401, received #{response.statusCode}")

      headers = {
        'Authorization': responseHeader(response, @url, '', @username, @password)
        'Content-Type': 'text/xml; charset=utf-8'
      }

      callback null, request.defaults(_.defaults({ headers }, options))

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
