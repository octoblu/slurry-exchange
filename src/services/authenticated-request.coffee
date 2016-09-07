_ = require 'lodash'
{challengeHeader, responseHeader} = require 'ntlm'
request = require 'request'
url = require 'url'
xml2js = require 'xml2js'

EWS_PATH = '/EWS/Exchange.asmx'
AUTODISCOVER_PATH = '/autodiscover/autodiscover.svc'

class AuthenticatedRequest
  constructor: ({@protocol, @hostname, @port, @username, @password}) ->
    throw new Error 'Missing required parameter: hostname' unless @hostname?
    throw new Error 'Missing required parameter: username' unless @username?
    throw new Error 'Missing required parameter: password' unless @password?

    @protocol ?= 'https'
    @port ?= 443

  do: ({pathname, body}, callback) =>
    @_getRequest {pathname}, (error, request) =>
      return callback error if error?

      request.post {body}, (error, response) =>
        return callback error if error?

        @_xml2js response.body, (error, obj) =>
          return callback error if error?
          return callback null, obj, {statusCode: response.statusCode}

  doAutodiscover: ({body}, callback) =>
    @do {body, pathname: AUTODISCOVER_PATH}, callback

  doEws: ({body}, callback) =>
    @do {body, pathname: EWS_PATH}, callback

  getOpenEwsRequest: ({body}, callback) =>
    @_getRequest pathname: EWS_PATH, (error, authenticatedRequest) =>
      return callback error if error?
      return callback null, authenticatedRequest.post({body})

  _getRequest: ({pathname}, callback) =>
    urlStr = url.format {@protocol, @hostname, @port, pathname}
    hostname = _.last _.split(@username, '@')
    options = {
      url: urlStr
      forever: true
      headers:
        'Authorization': challengeHeader('', hostname)
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

  _xml2js: (xml, callback) =>
    options = {
      tagNameProcessors: [xml2js.processors.stripPrefix]
      explicitArray: false
    }
    xml2js.parseString xml, options, callback

module.exports = AuthenticatedRequest
