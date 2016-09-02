_ = require 'lodash'
request = require 'request'
{challengeHeader, responseHeader} = require 'ntlm'

EXCHANGE_PATH = '/EWS/Exchange.asmx'

class Exchange
  constructor: ({url, @username, @password}) ->
    throw new Error 'Missing required parameter: url' unless url?
    throw new Error 'Missing required parameter: username' unless @username?
    throw new Error 'Missing required parameter: password' unless @password?
    @url = "#{url}#{EXCHANGE_PATH}"

  whoami: (callback) =>
    @getRequest (error, authenticatedRequest) =>
      return callback error if error?

      authenticatedRequest.post {}, callback

  getRequest: (callback) =>
    options = {
      url: @url
      forever: true
      headers:
        'Authorization': challengeHeader('', 'citrite.net')
    }

    request.post options, (error, response) =>
      return callback error if error?
      console.log response.statusCode, response.headers, response.body

      headers = {
        'Authorization': responseHeader(response, @url, '', @username, @password)
        'Content-Type': 'text/xml; charset=utf-8'
      }

      callback null, request.defaults(_.defaults({ headers }, options))

module.exports = Exchange
