path = require 'path'
fs = require 'fs'
Robot = require("hubot/src/robot")
TextMessage = require("hubot/src/message").TextMessage
chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
{ expect } = chai

loadFixture = (name)->
  JSON.parse fs.readFileSync "spec/fixtures/#{name}.json"

describe 'hubot-cloudfront', ->
  process.env.HUBOT_AWS_ACCESS_KEY_ID = 'fake-access-key-id'
  process.env.HUBOT_AWS_SECRET_ACCESS_KEY = 'fake-secret-access-key'
  robot = null
  user = null
  adapter = null
  beforeEach (done)->
    robot = new Robot null, 'mock-adapter', yes, 'TestHubot'
    robot.adapter.on 'connected', ->
      robot.loadFile path.resolve('.', 'src', 'scripts'), 'cloudfront.coffee'
      hubotScripts = path.resolve 'node_modules', 'hubot', 'src', 'scripts'
      robot.loadFile hubotScripts, 'help.coffee'
      user = robot.brain.userForId '1', {
        name: 'ngs'
        room: '#mocha'
      }
      adapter = robot.adapter
      waitForHelp = ->
        if robot.helpCommands().length > 0
          do done
        else
          setTimeout waitForHelp, 100
      do waitForHelp
    do robot.run

  afterEach ->
    robot.server.close()
    robot.shutdown()
    robot.brain.remove('cloudfrontInvalidations')
    process.removeAllListeners 'uncaughtException'

  describe 'help', ->
    it 'should have 5', (done)->
      expect(robot.helpCommands()).to.have.length 5
      do done

    it 'should parse help', (done)->
      adapter.on 'send', (envelope, strings)->
        ## Prefix bug with parseHelp
        ## https://github.com/github/hubot/pull/712
        try
          expect(strings).to.deep.equal ["""
          TestTestHubot cloudfront invalidate <distribution id> <path0> <path1> ... - Invalidates objects.
          TestTestHubot cloudfront list distributions - Lists distributions.
          TestTestHubot cloudfront list invalidations <distribution id> - Lists invalidations.
          TestTestHubot help - Displays all of the help commands that TestHubot knows about.
          TestTestHubot help <query> - Displays all help commands that match <query>.
          """]
          do done
        catch e
          done e
      adapter.receive new TextMessage user, 'TestHubot help'

  describe 'cloudfront', ->
    it 'assigns cloudfront client to robot', ->
      expect(robot.cloudfront.client).to.be.defined

    [
      'TestHubot  cloudfront   list   distributions  '
      'TestHubot  cf   ls   dist  '
    ].forEach (msg)->
      describe msg, ->
        it 'lists if exists', ->
          sinon.stub robot.cloudfront.client, 'listDistributions', (options, callback)->
            fixture = loadFixture 'distributions'
            callback.call robot.cloudfront.client, null, fixture, {}
          spy = sinon.spy()
          adapter.on 'send', spy
          adapter.receive new TextMessage user, msg
          expect(spy).to.have.been.calledOnce
          expect(spy.getCall(0).args[0]).not.to.be.null
          expect(spy.getCall(0).args[1]).to.deep.equal ["""
          .-----------------------------------------------------------------------------.
          |       ID       |   Status   |          Domain Name          | Invalidations |
          |----------------|------------|-------------------------------|---------------|
          | E2SO336F6AMQ08 | InProgress | d1ood20dgya2ll.cloudfront.net |             0 |
          | E29XRZTZN1VOAV | Deployed   | d290rn73xc4vfg.cloudfront.net |            10 |
          '-----------------------------------------------------------------------------'
          """]
        it 'replies if empty', ->
          sinon.stub robot.cloudfront.client, 'listDistributions', (options, callback)->
            callback.call robot.cloudfront.client, null, [], {}
          spy = sinon.spy()
          adapter.on 'reply', spy
          adapter.receive new TextMessage user, msg
          expect(spy).to.have.been.calledOnce
          expect(spy.getCall(0).args[0]).not.to.be.null
          expect(spy.getCall(0).args[1]).to.deep.equal ['No distributions found.']
        it 'replies if it has an error', ->
          sinon.stub robot.cloudfront.client, 'listDistributions', (options, callback)->
            callback.call robot.cloudfront.client, new Error('Foo'), null, {}
          spy = sinon.spy()
          adapter.on 'reply', spy
          adapter.receive new TextMessage user, msg
          expect(spy).to.have.been.calledOnce
          expect(spy.getCall(0).args[0]).not.to.be.null
          expect(spy.getCall(0).args[1]).to.deep.equal ['Error: Foo']
    [
      'TestHubot  cloudfront   list   invalidate   E2SO336F6AMQ08   '
      'TestHubot  cloudfront   list   invalidations   E2SO336F6AMQ08   '
      'TestHubot  cloudfront   list   invalidation   E2SO336F6AMQ08   '
      'TestHubot  cf  ls  inv  E2SO336F6AMQ08     '
    ].forEach (msg)->
      describe msg, ->
        it 'lists if exists', ->
          sinon.stub robot.cloudfront.client, 'listInvalidations', (id, callback)->
            fixture = loadFixture 'invalidations'
            callback.call robot.cloudfront.client, null, fixture, {}
          spy = sinon.spy()
          adapter.on 'send', spy
          adapter.receive new TextMessage user, msg
          expect(spy).to.have.been.calledOnce
          expect(spy.getCall(0).args[0]).not.to.be.null
          expect(spy.getCall(0).args[1]).to.deep.equal ["""
          .-----------------------------.
          |       ID       |   Status   |
          |----------------|------------|
          | I14NJQR76VVQAT | InProgress |
          | I3MAZE9OBGZ05X | Completed  |
          '-----------------------------'
          """]
        it 'replies if empty', ->
          sinon.stub robot.cloudfront.client, 'listInvalidations', (id, callback)->
            callback.call robot.cloudfront.client, null, [], {}
          spy = sinon.spy()
          adapter.on 'reply', spy
          adapter.receive new TextMessage user, msg
          expect(spy).to.have.been.calledOnce
          expect(spy.getCall(0).args[0]).not.to.be.null
          expect(spy.getCall(0).args[1]).to.deep.equal ['No invalidations found.']
        it 'replies if it has an error', ->
          sinon.stub robot.cloudfront.client, 'listInvalidations', (id, callback)->
            callback.call robot.cloudfront.client, new Error('Foo'), null, {}
          spy = sinon.spy()
          adapter.on 'reply', spy
          adapter.receive new TextMessage user, msg
          expect(spy).to.have.been.calledOnce
          expect(spy.getCall(0).args[0]).not.to.be.null
          expect(spy.getCall(0).args[1]).to.deep.equal ['Error: Foo']
    [
      'TestHubot  cloudfront   invalidate   E2SO336F6AMQ08  foo.js  bar/*.gif  /buz/qux.xml  '
      'TestHubot  cf   inv  E2SO336F6AMQ08  foo.js  bar/*.gif  /buz/qux.xml   '
    ].forEach (msg)->
      describe msg, ->
        it 'replies if success', ->
          sinon.stub robot.cloudfront.client, 'createInvalidation', (id, callerReference, paths, callback)->
            fixture = loadFixture 'invalidation'
            callback.call robot.cloudfront.client, null, fixture, {}
          adapter.receive new TextMessage user, msg
          spy = sinon.spy()
          adapter.on 'reply', spy
          adapter.receive new TextMessage user, msg
          expect(spy).to.have.been.calledOnce
          expect(robot.cloudfront.client.createInvalidation.getCall(0).args[2])
            .to.deep.equal ['foo.js', 'bar/*.gif', '/buz/qux.xml']
          expect(spy.getCall(0).args[0]).not.to.be.null
          expect(spy.getCall(0).args[1]).to.deep.equal ["""
          Invalidation I14NJQR76VVQAT on distribution E2SO336F6AMQ08 created.
          It might take 10 to 15 minutes until all files are invalidated.
          """]
          expect(robot.brain.get('cloudfrontInvalidations')).to.deep.equal [
            id: 'I14NJQR76VVQAT'
            distribution: 'E2SO336F6AMQ08'
            userId: '1'
          ]
        it 'replies if it has an error', ->
          sinon.stub robot.cloudfront.client, 'createInvalidation', (id, callerReference, paths, callback)->
            callback.call robot.cloudfront.client, new Error('Foo'), null, {}
          spy = sinon.spy()
          adapter.on 'reply', spy
          adapter.receive new TextMessage user, msg
          expect(spy).to.have.been.calledOnce
          expect(spy.getCall(0).args[0]).not.to.be.null
          expect(spy.getCall(0).args[1]).to.deep.equal ['Error: Foo']

    describe 'watcher', ->
      spy = null
      beforeEach ->
        spy = sinon.spy()
        robot.brain.set 'cloudfrontInvalidations', [
          id: 'I14NJQR76VVQAT'
          distribution: 'E2SO336F6AMQ08'
          userId: '1'
        ]
        robot.brain.save()
      describe 'not completed', ->
        beforeEach ->
          adapter.on 'reply', spy
          adapter.on 'send', spy
        it 'does nothing while it is in progress', ->
          sinon.stub robot.cloudfront.client, 'getInvalidation', (distribution, id, callback)->
            fixture = loadFixture 'invalidation'
            callback.call robot.cloudfront.client, null, fixture, {}
          robot.cloudfront.watcher.checkStatus()
          expect(spy).not.to.have.been.called
        it 'does nothing if callback is null', ->
          sinon.stub robot.cloudfront.client, 'getInvalidation', (distribution, id, callback)->
            callback.call robot.cloudfront.client, null, null, {}
          robot.cloudfront.watcher.checkStatus()
          expect(spy).not.to.have.been.called
      describe 'completed', ->
        it 'mentions user when completed', ->
          adapter.on 'reply', spy
          sinon.stub robot.cloudfront.client, 'getInvalidation', (distribution, id, callback)->
            fixture = loadFixture 'invalidation'
            fixture.status = 'Completed'
            callback.call robot.cloudfront.client, null, fixture, {}
          robot.cloudfront.watcher.checkStatus()
          expect(spy).to.have.been.calledOnce
          expect(spy.getCall(0).args[0]).not.to.be.null
          expect(spy.getCall(0).args[0]).to.deep.equal id: '1', name: 'ngs', room: '#mocha'
          expect(spy.getCall(0).args[1]).to.deep.equal ["Invalidation I14NJQR76VVQAT on distribution E2SO336F6AMQ08 completed."]
          expect(robot.brain.get('cloudfrontInvalidations')).to.deep.equal []
