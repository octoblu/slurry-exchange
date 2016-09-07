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
    tee = @request
      .pipe(xmlNodes('Envelope'))
    tee
      .pipe(xmlObjects(XML_OPTIONS))
      .on 'data', @_onData

    # tee.on 'data', (data) => console.log data.toString()

  destroy: =>
    return @request.abort() if _.isFunction @request.abort
    @request.socket.destroy()
    @push null

  _itemIsNotFound: (response) =>
    responseCode = _.get response, 'Envelope.Body.GetItemResponse.ResponseMessages.GetItemResponseMessage.ResponseCode'
    return responseCode == 'ErrorItemNotFound'

  _normalizeDatetime: (datetime) =>
    moment(datetime).utc().format()

  _onData: (data) =>
    debug '_onData', JSON.stringify(data)
    responses = _.get data, 'Envelope.Body.GetStreamingEventsResponse.ResponseMessages'
    responses = [responses] unless _.isArray responses
    _.each _.compact(responses), @_onResponse

  _onDeletedItemId: (itemId) =>
    debug '_onDeletedItemId'
    @push {itemId, eventType: 'deleted'}

  _onItemId: (itemId) =>
    debug '_onItemId', itemId
    @authenticatedRequest.doEws body: getItemRequest({itemId}), (error, response) =>
      return console.error error.message if error?

      return if @_itemIsNotFound response
      @push @_parseItemResponse response

  _onModifiedEvents: (events) =>
    debug '_onModifiedEvents', events
    itemIds = _.uniq _.compact _.map(events, 'ItemId.$.Id')
    _.each itemIds, @_onItemId

  _onMovedEvents: (events) =>
    debug '_onMovedEvents', events
    itemIds = _.uniq _.compact _.map(events, 'OldItemId.$.Id')
    _.each itemIds, @_onDeletedItemId

  _onNotification: (notification) =>
    debug '_onNotification', notification

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
