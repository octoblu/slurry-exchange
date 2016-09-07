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

CONNECTION_STATUS_PATH = 'Envelope.Body.GetStreamingEventsResponse.ResponseMessages.GetStreamingEventsResponseMessage.ConnectionStatus'
MEETING_RESPONSE_PATH = 'Envelope.Body.GetItemResponse.ResponseMessages.GetItemResponseMessage.Items'

class ExchangeStream extends stream.Readable
  constructor: ({connectionOptions, @request, timeout}) ->
    super objectMode: true

    timeout ?= 60 * 1000

    {protocol, hostname, port, username, password} = connectionOptions
    @authenticatedRequest = new AuthenticatedRequest {protocol, hostname, port, username, password}

    debug 'connecting...'
    @request
      .pipe(xmlNodes('Envelope'))
      .pipe(xmlObjects(XML_OPTIONS))
      .on 'data', @_onData

    @_pushBackTimeout = _.debounce @_onTimeout, timeout
    @_pushBackTimeout()

    # @request
    #   .pipe(xmlNodes('Envelope'))
    #   .on 'data', (data) => console.log data.toString()

  destroy: =>
    debug 'destroy'
    @_pushBackTimeout.cancel()
    @request.abort?()
    @request.socket?.destroy?()
    @_isClosed = true
    @push null

  _itemIsNotFound: (response) =>
    responseCode = _.get response, 'Envelope.Body.GetItemResponse.ResponseMessages.GetItemResponseMessage.ResponseCode'
    return responseCode == 'ErrorItemNotFound'

  _normalizeDatetime: (datetime) =>
    moment(datetime).utc().format()

  _onData: (data) =>
    debug '_onData'

    return @destroy() if 'Closed' == _.get data, CONNECTION_STATUS_PATH
    @_pushBackTimeout()

    responses = _.get data, 'Envelope.Body.GetStreamingEventsResponse.ResponseMessages'
    responses = [responses] unless _.isArray responses
    _.each _.compact(responses), @_onResponse

  _onDeletedItemId: (itemId) =>
    debug '_onDeletedItemId', itemId
    return if @_isClosed
    @push {itemId, eventType: 'deleted'}

  _onItemId: (itemId) =>
    debug '_onItemId', itemId
    @authenticatedRequest.doEws body: getItemRequest({itemId}), (error, response, extra) =>
      return console.error 'oh geez', error.message if error?
      debug '_onItemId:response', JSON.stringify(extra), JSON.stringify(response)

      return unless response?
      return if @_itemIsNotFound response
      return if @_isClosed
      @push @_parseItemResponse response

  _onModifiedEvents: (events) =>
    debug '_onModifiedEvents'
    itemIds = _.uniq _.compact _.map(events, 'ItemId.$.Id')
    _.each itemIds, @_onItemId

  _onMovedEvents: (events) =>
    debug '_onMovedEvents'
    itemIds = _.uniq _.compact _.map(events, 'OldItemId.$.Id')
    _.each itemIds, @_onDeletedItemId

  _onNotification: (notification) =>
    debug '_onNotification'

    modifiedEvents = _.get(notification, 'ModifiedEvent')
    modifiedEvents = [modifiedEvents] unless _.isArray modifiedEvents
    movedEvents    = _.get(notification, 'MovedEvent')
    movedEvents    = [movedEvents] unless _.isArray movedEvents

    @_onModifiedEvents modifiedEvents
    @_onMovedEvents movedEvents

  _onResponse: (response) =>
    debug '_onResponse'
    notifications = _.get response, 'GetStreamingEventsResponseMessage.Notifications.Notification'
    notifications = [notifications] unless _.isArray notifications
    _.each _.compact(notifications), @_onNotification

  _onTimeout: =>
    @destroy()

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
      accepted: "Accept" == _.get(meetingRequest, 'ResponseType')
      eventType: 'modified'
      itemId: _.get meetingRequest, 'ItemId.$.Id'
      recipient:
        name: _.get meetingRequest, 'ReceivedBy.Mailbox.Name'
        email: _.get meetingRequest, 'ReceivedBy.Mailbox.EmailAddress'
      attendees: @_parseAttendees(meetingRequest)
    }

  _read: =>
    # @request.startRead()

module.exports = ExchangeStream
