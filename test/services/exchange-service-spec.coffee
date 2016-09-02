{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'
_ = require 'lodash'
fs = require 'fs'
path = require 'path'
shmock = require 'shmock'
enableDestroy = require 'server-destroy'

Exchange = require '../../src/services/exchange-service'
CHALLENGE = _.trim fs.readFileSync path.join(__dirname, '../fixtures/challenge.b64'), encoding: 'utf8'
NEGOTIATE = _.trim fs.readFileSync path.join(__dirname, '../fixtures/negotiate.b64'), encoding: 'utf8'

describe 'Exchange', ->
  beforeEach ->
    @server = shmock()
    enableDestroy @server
    {port} = @server.address()
    @sut = new Exchange url: "http://localhost:#{port}", username: 'foo', password: 'bar'

  afterEach (done) ->
    @server.destroy done

  describe 'whoami', ->
    beforeEach (done) ->
      @negotiate = @server
        .post '/EWS/Exchange.asmx'
        .set 'Authorization', NEGOTIATE
        .reply 401, '', {'WWW-Authenticate': CHALLENGE}

      @getUser = @server
        .post '/EWS/Exchange.asmx'
        .reply 204

      @sut.whoami done

    it 'should make a negotiate request to the exchange server', ->
      expect(@negotiate.isDone).to.be.true

    it 'should make a get user request to the exchange server', ->
      expect(@getUser.isDone).to.be.true
