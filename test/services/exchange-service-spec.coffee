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
USER_SETTINGS_RESPONSE = fs.readFileSync path.join(__dirname, '../fixtures/userSettingsResponse.xml'), encoding: 'utf8'


describe 'Exchange', ->
  beforeEach ->
    @server = shmock()
    enableDestroy @server
    {port} = @server.address()
    @sut = new Exchange protocol: 'http', hostname: "localhost", port: port, username: 'foo@biz.biz', password: 'bar'

  afterEach (done) ->
    @server.destroy done

  describe 'whoami', ->
    beforeEach (done) ->
      @negotiate = @server
        .post '/autodiscover/autodiscover.svc'
        .set 'Authorization', NEGOTIATE
        .reply 401, '', {'WWW-Authenticate': CHALLENGE}

      @getUser = @server
        .post '/autodiscover/autodiscover.svc'
        .reply 200, USER_SETTINGS_RESPONSE

      @sut.whoami (error, @user) => done error

    it 'should make a negotiate request to the exchange server', ->
      expect(@negotiate.isDone).to.be.true

    it 'should make a get user request to the exchange server', ->
      expect(@getUser.isDone).to.be.true

    it 'should yield a user', ->
      expect(@user).to.deep.equal {
        name: 'Foo Hampton'
        id:   'ada48c41-66c9-407b-bf2a-a7880e611435'
      }
