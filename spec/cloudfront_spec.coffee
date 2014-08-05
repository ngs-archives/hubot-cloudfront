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
  robot = null
  user = null
  adapter = null

  afterEach ->
    robot.server.close()
    robot.shutdown()
    robot.cloudfront?.watcher.stop()
    process.removeAllListeners 'uncaughtException'

  describe 'ENV is not set', ->
    it 'should throw error', (done)->
      robot = new Robot null, 'mock-adapter', yes, 'TestHubot'
      sinon.spy robot.logger, 'error'
      robot.adapter.on 'connected', ->
        try
          delete process.env.HUBOT_AWS_ACCESS_KEY_ID
          delete process.env.HUBOT_AWS_SECRET_ACCESS_KEY
          robot.loadFile path.resolve('.', 'src', 'scripts'), 'cloudfront.coffee'
          expect(robot.logger.error).to.have.been.calledWith """
          hubot-cloudfront is not loaded due to missing configuration.
          both HUBOT_AWS_ACCESS_KEY_ID and HUBOT_AWS_ACCESS_KEY_ID are required.
          """
          expect(robot.cloudfront).not.to.be.defined
          do done
        catch e
          done e
      do robot.run

  describe 'ENV is set', ->
    beforeEach (done)->
      process.env.HUBOT_AWS_ACCESS_KEY_ID = 'fake-access-key-id'
      process.env.HUBOT_AWS_SECRET_ACCESS_KEY = 'fake-secret-access-key'
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
            TestHubot cloudfront invalidate <distribution id or index> <path0> <path1> ... - Invalidates objects.
            TestHubot cloudfront list distributions (<query>) - Lists distributions.
            TestHubot cloudfront list invalidations <distribution id or index> - Lists invalidations.
            TestHubot help - Displays all of the help commands that TestHubot knows about.
            TestHubot help <query> - Displays all help commands that match <query>.
            """]
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'TestHubot help'

    describe 'cloudfront', ->
      it 'assigns cloudfront client and watcher to robot', ->
        expect(robot.cloudfront.client).to.be.defined
        expect(robot.cloudfront.watcher).to.be.defined
        expect(robot.cloudfront.watcher.intervalId).not.to.be.null

      [
        'TestHubot  cloudfront   list   distributions  us  '
        'TestHubot  cf   ls   dist  us  '
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
            - 0: E2SO336F6AMQ08 --------------------
              domain: d1ood20dgya2ll.cloudfront.net
              status: InProgress
              comment: Distribution for static.liap.us
            """]
            expect(robot.brain.get('cloudfront.distributions')).to.deep.equal [
              'E2SO336F6AMQ08'
              'E29XRZTZN1VOAV'
            ]
          it 'replies if empty', ->
            sinon.stub robot.cloudfront.client, 'listDistributions', (options, callback)->
              callback.call robot.cloudfront.client, null, [], {}
            spy = sinon.spy()
            adapter.on 'reply', spy
            adapter.receive new TextMessage user, msg
            expect(spy).to.have.been.calledOnce
            expect(spy.getCall(0).args[0]).not.to.be.null
            expect(spy.getCall(0).args[1]).to.deep.equal ['No distributions found.']
      [
        'TestHubot  cloudfront   list   distributions  foo  '
        'TestHubot  cf   ls   dist  foo  '
      ].forEach (msg)->
        describe msg, ->
          it 'replies if query not match', ->
            sinon.stub robot.cloudfront.client, 'listDistributions', (options, callback)->
              callback.call robot.cloudfront.client, null, [], {}
            spy = sinon.spy()
            adapter.on 'reply', spy
            adapter.receive new TextMessage user, msg
            expect(spy).to.have.been.calledOnce
            expect(spy.getCall(0).args[0]).not.to.be.null
            expect(spy.getCall(0).args[1]).to.deep.equal ['No distributions found.']
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
            - 0: E2SO336F6AMQ08 --------------------
              domain: d1ood20dgya2ll.cloudfront.net
              status: InProgress
              comment: Distribution for static.liap.us

            - 1: E29XRZTZN1VOAV --------------------
              domain: d290rn73xc4vfg.cloudfront.net
              status: Deployed
              invalidations in progress: 10
            """]
            expect(robot.brain.get('cloudfront.distributions')).to.deep.equal [
              'E2SO336F6AMQ08'
              'E29XRZTZN1VOAV'
            ]
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
        'TestHubot  cloudfront   list   invalidate    0  '
        'TestHubot  cloudfront   list   invalidations   0   '
        'TestHubot  cloudfront   list   invalidation   0   '
        'TestHubot  cf  ls  inv   0    '
      ].forEach (msg)->
        describe msg, ->
          beforeEach ->
            robot.brain.set 'cloudfront.distributions', [
              'E2SO336F6AMQ08'
              'E29XRZTZN1VOAV'
            ]
            robot.brain.save()
          it 'lists if exists', ->
            sinon.stub robot.cloudfront.client, 'listInvalidations', (id, callback)->
              fixture = loadFixture 'invalidations'
              callback.call robot.cloudfront.client, null, fixture, {}
            spy = sinon.spy()
            adapter.on 'send', spy
            adapter.receive new TextMessage user, msg
            expect(robot.cloudfront.client.listInvalidations).to.have.been.calledOnce
            expect(robot.cloudfront.client.listInvalidations.getCall(0).args[0]).to.equal 'E2SO336F6AMQ08'
            expect(spy).to.have.been.calledOnce
            expect(spy.getCall(0).args[0]).not.to.be.null
            expect(spy.getCall(0).args[1]).to.deep.equal ["""
            I14NJQR76VVQAT - InProgress
            I3MAZE9OBGZ05X - Completed
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
            expect(robot.brain.get('cloudfront.invalidations')).to.deep.equal [
              id: 'I14NJQR76VVQAT'
              distribution: 'E2SO336F6AMQ08'
              room: '#mocha'
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
          robot.brain.set 'cloudfront.invalidations', [
            id: 'I14NJQR76VVQAT'
            distribution: 'E2SO336F6AMQ08'
            room: '#mocha'
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
            expect(spy.getCall(0).args[0]).to.deep.equal user: { id: '1', name: 'ngs', room: '#mocha' }, room: '#mocha'
            expect(spy.getCall(0).args[1]).to.deep.equal ["Invalidation I14NJQR76VVQAT on distribution E2SO336F6AMQ08 completed."]
            expect(robot.brain.get('cloudfront.invalidations')).to.deep.equal []
