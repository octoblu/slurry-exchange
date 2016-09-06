{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'

fs            = require 'fs'
_             = require 'lodash'
path          = require 'path'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
{PassThrough} = require 'stream'

ExchangeStream = require '../../src/streams/exchange-stream'

CALENDAR_EVENT = fs.readFileSync path.join(__dirname, '../fixtures/calendarEvent.xml')
CALENDAR_EVENT2 = fs.readFileSync path.join(__dirname, '../fixtures/calendarEvent2.xml')
GET_ITEM_CALENDAR_RESPONSE = fs.readFileSync path.join(__dirname, '../fixtures/getItemCalendarResponse.xml')
CHALLENGE = _.trim fs.readFileSync path.join(__dirname, '../fixtures/challenge.b64'), encoding: 'utf8'
NEGOTIATE = _.trim fs.readFileSync path.join(__dirname, '../fixtures/negotiate.b64'), encoding: 'utf8'

describe 'ExchangeStream', ->
  beforeEach ->
    @server = shmock()
    enableDestroy @server
    {port} = @server.address()

    @request = new PassThrough objectMode: true
    @sut = new ExchangeStream {
      request: @request
      connectionOptions:
        protocol: 'http'
        hostname: 'localhost'
        port: port
        username: 'foo@biz.biz'
        password: 'bar'
    }

  afterEach (done) ->
    @server.destroy done

  describe 'when the request emits a calendar event', ->
    beforeEach (done) ->
      @server
        .post '/EWS/Exchange.asmx'
        .set 'Authorization', NEGOTIATE
        .reply 401, '', {'WWW-Authenticate': CHALLENGE}

      @getUser = @server
        .post '/EWS/Exchange.asmx'
        .reply 200, GET_ITEM_CALENDAR_RESPONSE

      @request.write CALENDAR_EVENT
      @sut.on 'readable', done

    it 'should have a calendar event readable', ->
      event = @sut.read()
      expect(event).to.deep.equal {
        subject: '1 vs 1'
        startTime: '2016-09-03T02:30:00Z'
        endTime: '2016-09-03T03:00:00Z'
        itemId: 'AAMkADYxNGJmNGNmLTIxYTctNDlkOC1hZWRmLTJjMTMzZmI5YmUxNABGAAAAAAACtVr7DjkQQ4cFx7dwBexwBwD9KrxseohjTIFhVu2R9k27AAAAAAEKAAD9KrxseohjTIFhVu2R9k27AAAS/1nWAAA='
        accepted: true
        recipient:
          name: 'Conf. Octoblu (Tempe)'
          email: 'octobluconf@citrix.com'
        attendees: [{
          name: "Roy Zandewager"
          email: "Roy.Zandewager@citrix.com"
        }, {
          name: "Aaron Heretic"
          email: "Aaron.Heretic@citrix.com"
        }]
      }

  describe 'when the request emits another calendar event', ->
    beforeEach (done) ->
      @server
        .post '/EWS/Exchange.asmx'
        .set 'Authorization', NEGOTIATE
        .reply 401, '', {'WWW-Authenticate': CHALLENGE}

      @getUser = @server
        .post '/EWS/Exchange.asmx'
        .reply 200, GET_ITEM_CALENDAR_RESPONSE

      @request.write CALENDAR_EVENT2
      @sut.on 'readable', done

    it 'should have a calendar event readable', ->
      event = @sut.read()
      expect(event).to.deep.equal {
        subject: '1 vs 1'
        startTime: '2016-09-03T02:30:00Z'
        endTime: '2016-09-03T03:00:00Z'
        itemId: 'AAMkADYxNGJmNGNmLTIxYTctNDlkOC1hZWRmLTJjMTMzZmI5YmUxNABGAAAAAAACtVr7DjkQQ4cFx7dwBexwBwD9KrxseohjTIFhVu2R9k27AAAAAAEKAAD9KrxseohjTIFhVu2R9k27AAAS/1nWAAA='
        recipient:
          name: 'Conf. Octoblu (Tempe)'
          email: 'octobluconf@citrix.com'
        accepted: true
        attendees: [{
          name: "Roy Zandewager"
          email: "Roy.Zandewager@citrix.com"
        }, {
          name: "Aaron Heretic"
          email: "Aaron.Heretic@citrix.com"
        }]
      }
