_ = require 'lodash'
moment = require 'moment'
stream = require 'stream'
xmlNodes = require 'xml-nodes'
xmlObjects = require 'xml-objects'
xml2js = require 'xml2js'

debug = require('debug')('slurry-exchange:exchange-stream')
AuthenticatedRequest = require '../services/authenticated-request'
getItemRequest = require '../templates/getItemRequest'

XML_OPTIONS = {
  tagNameProcessors: [xml2js.processors.stripPrefix]
  explicitArray: false
}

MEETING_RESPONSE_PATH = 'Envelope.Body.GetItemResponse.ResponseMessages.GetItemResponseMessage.Items'

class ExchangeStream extends stream.Readable
  constructor: ({connectionOptions, @request}) ->
    super objectMode: true

    {protocol, hostname, port, username, password} = connectionOptions
    @authenticatedRequest = new AuthenticatedRequest {protocol, hostname, port, username, password}

    debug 'connecting...'
    @request
      .pipe(xmlNodes('Envelope'))
      .pipe(xmlObjects(XML_OPTIONS))
      .on 'data', @_onData

  destroy: =>
    return @request.abort() if _.isFunction @request.abort
    @request.socket.destroy()
    @push null

  _normalizeDatetime: (datetime) =>
    moment(datetime).utc().format()

  _onData: (data) =>
    debug '_onData'
    responses = _.get data, 'Envelope.Body.GetStreamingEventsResponse.ResponseMessages'
    responses = [responses] unless _.isArray responses
    _.each responses, @_onResponse

  _onItemId: (itemId) =>
    @authenticatedRequest.doEws body: getItemRequest({itemId}), (error, response) =>
      return console.error error.message if error?

      @push @_parseItemResponse response

  _onNotification: (notification) =>
    events = _.get notification, 'Notification.ModifiedEvent'
    events = [events] unless _.isArray events

    itemIds = _.compact _.uniq _.map(events, 'ItemId.$.Id')
    _.each itemIds, @_onItemId

  _onResponse: (response) =>
    notifications = _.get response, 'GetStreamingEventsResponseMessage.Notifications'
    notifications = [notifications] unless _.isArray notifications
    _.each notifications, @_onNotification

  _parseAttendee: (requiredAttendee) =>
    {
      name: _.get requiredAttendee, 'Mailbox.Name'
      email: _.get requiredAttendee, 'Mailbox.EmailAddress'
    }

  _parseAttendees: (meetingRequest) =>
    requiredAttendees = _.get meetingRequest, 'RequiredAttendees.Attendee'
    _.map requiredAttendees, @_parseAttendee

  _parseItemResponse: (response) =>
    items = _.get response, MEETING_RESPONSE_PATH
    meetingRequest = _.first _.values items

    return {
      subject: _.get meetingRequest, 'Subject'
      startTime: @_normalizeDatetime _.get(meetingRequest, 'StartWallClock')
      endTime:   @_normalizeDatetime _.get(meetingRequest, 'EndWallClock')
      location: _.get meetingRequest, 'Location'
      attendees: @_parseAttendees(meetingRequest)
    }

  _read: =>
    # @request.startRead()

module.exports = ExchangeStream
