# Description:
#   Lists and invalidates Amazon CloudFront distributions
#
# Configuration:
#   HUBOT_AWS_ACCESS_KEY_ID
#   HUBOT_AWS_SECRET_ACCESS_KEY
#
# Commands:
#   hubot cloudfront list distributions - Lists distributions.
#   hubot cloudfront list invalidations <distribution id> - Lists invalidations.
#   hubot cloudfront invalidate <distribution id> <path0> <path1> ... - Invalidates objects.

cloudfront = require 'cloudfront'
AsciiTable = require 'ascii-table'
BRAIN_KEY_INVALIDATIONS = 'cloudfrontInvalidations'

class Watcher
  constructor: (robot, client, interval = 60) ->
    @robot = robot
    @client = client
    @intervalId = 0
    @interval = interval
    robot.on 'running', @reset.bind(@)
  reset: ->
    clearInterval @intervalId if @intervalId > 0
    if @interval > 0
      @intervalId = setInterval =>
        @checkStatus()
      , @interval * 1000
    else
      @intervalId = 0
  checkStatus: ->
    invalidations = @robot.brain.get(BRAIN_KEY_INVALIDATIONS) || []
    invalidations.forEach @getInvalidation.bind(@)
  getInvalidation: ({ id, distribution, userId })->
    @client.getInvalidation distribution, id, (err, inv)=>
      if inv?.status is 'Completed'
        msg = "Invalidation #{id} on distribution #{distribution} completed."
        invalidations = (@robot.brain.get(BRAIN_KEY_INVALIDATIONS) || []).filter (o)->
          !( o.id == id && o.distribution == o.distribution && o.userId == userId )
        @robot.brain.set BRAIN_KEY_INVALIDATIONS, invalidations
        if user = @robot.brain.users()[userId]
          @robot.reply user, msg
        else
          @robot.send msg

module.exports = (robot) ->
  { HUBOT_AWS_ACCESS_KEY_ID, HUBOT_AWS_SECRET_ACCESS_KEY } = process.env
  client = cloudfront.createClient HUBOT_AWS_ACCESS_KEY_ID, HUBOT_AWS_SECRET_ACCESS_KEY
  watcher = new Watcher robot, client
  robot.cloudfront = { client, watcher }

  robot.respond /\s*(?:cloudfront|cf)\s+(?:list|ls)\s+dist(?:ributions?)?\s*$/i, (msg) ->
    client.listDistributions { streaming: no }, (err, list, info)->
      if err?
        msg.reply err.toString()
        return
      unless list?.length > 0
        msg.reply "No distributions found."
        return
      table = new AsciiTable
      table.setHeading 'ID', 'Status', 'Domain Name', 'Invalidations'
      list.forEach ({ id, status, domainName, inProgressInvalidationBatches })->
        table.addRow id, status, domainName, inProgressInvalidationBatches
      msg.send table.toString()

  robot.respond /\s*(?:cloudfront|cf)\s+(?:list|ls)\s+inv(?:alidat(?:e|ions?)|)\s+([a-z0-9]+)\s*$/i, (msg) ->
    client.listInvalidations msg.match[1], (err, list, info)->
      if err?
        msg.reply err.toString()
        return
      unless list?.length > 0
        msg.reply "No invalidations found."
        return
      table = new AsciiTable
      table.setHeading 'ID', 'Status'
      list.forEach ({ id, status })->
        table.addRow id, status
      msg.send table.toString()

  robot.respond /\s*(?:cloudfront|cf)\s+inv(?:alidate)?\s+([a-z0-9]+)\s+(.+)\s*$/i, (msg) ->
    [_, id, paths] = msg.match
    paths = paths.trim().split /\s+/
    client.createInvalidation id, new Date().getTime(), paths, (err, inv)->
      if err?
        msg.reply err.toString()
        return
      invalidations = robot.brain.get(BRAIN_KEY_INVALIDATIONS) || []
      if invalidations.filter((o)-> o.id == inv.id).length == 0
        invalidations.push
          id: inv.id
          distribution: inv.distribution
          userId: msg.envelope.user.id
        robot.brain.set BRAIN_KEY_INVALIDATIONS, invalidations
        robot.brain.save()
      msg.reply "Invalidation #{inv.id} on distribution #{inv.distribution} created.\nIt might take 10 to 15 minutes until all files are invalidated."
