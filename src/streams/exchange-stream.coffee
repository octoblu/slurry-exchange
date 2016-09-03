stream = require 'stream'
xmlNodes = require 'xml-nodes'
xmlObjects = require 'xml-objects'
xml2js = require 'xml2js'

XML_OPTIONS = {
  tagNameProcessors: [xml2js.processors.stripPrefix]
  explicitArray: false
}

class ExchangeStream extends stream.Readable
  constructor: ({@request}) ->
    super objectMode: true


    @request
      .pipe(xmlNodes('m:Notification'))
      .pipe(xmlObjects(XML_OPTIONS))
      .on 'data', @_onData

  _onData: (data) =>
    console.log JSON.stringify(data, null, 2)

  _read: =>
    # @request.startRead()


module.exports = ExchangeStream
