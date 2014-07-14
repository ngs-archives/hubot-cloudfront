# Description:
#   Lists and invalidates Amazon CloudFront distributions
#
# Configuration:
#   HUBOT_AWS_ACCESS_KEY_ID
#   HUBOT_AWS_SECRET_ACCESS_KEY
#
# Commands:
#   hubot cloudfront list distributions - Lists distributions.
#   hubot cloudfront list invalidations <distribution id or index> - Lists invalidations.
#   hubot cloudfront invalidate <distribution id or index> <path0> <path1> ... - Invalidates objects.

cloudfront = require 'cloudfront'
BRAIN_KEY_INVALIDATIONS = 'cloudfront.invalidations'
BRAIN_KEY_DISTRIBUTIONS = 'cloudfront.distributions'

class Watcher
  constructor: (robot, client, interval = 60) ->
    @robot = robot
    @client = client
    @intervalId = null
    @interval = interval
    @reset()
  stop: ->
    clearInterval @intervalId if @intervalId?
    @intervalId = null
  reset: ->
    if @interval > 0
      @intervalId = setInterval @checkStatus.bind(@), @interval * 1000
    else
      @intervalId = 0
  checkStatus: ->
    invalidations = @robot.brain.get(BRAIN_KEY_INVALIDATIONS) || []
    len = invalidations.length
    @log 'info', "Checking #{len} invalidation#{ if len > 1 then 's' else '' }"
    invalidations.forEach @getInvalidation.bind(@)
  log: (type, msg)->
    @robot.logger[type] msg
  getInvalidation: ({ id, distribution, userId, room })->
    @log 'info', "Checking invalidation #{id} on distribution #{distribution} for #{userId}#{ if room then " at #{room}" else ''}"
    @client.getInvalidation distribution, id, (err, inv)=>
      unless inv?
        err ||= new Error 'No data received'
        @log 'error', "#{id}: #{err}"
        return
      @log 'info', "#{id}: status is #{inv?.status}"
      if inv?.status is 'Completed'
        msg = "Invalidation #{id} on distribution #{distribution} completed."
        invalidations = (@robot.brain.get(BRAIN_KEY_INVALIDATIONS) || []).filter (o)->
          !( o.id == id && o.distribution == o.distribution && o.userId == userId )
        @robot.brain.set BRAIN_KEY_INVALIDATIONS, invalidations
        if user = @robot.brain.users()?[userId]
          @robot.reply { user, room }, msg
        else
          @robot.send msg

module.exports = (robot) ->
  { HUBOT_AWS_ACCESS_KEY_ID, HUBOT_AWS_SECRET_ACCESS_KEY } = process.env
  if !HUBOT_AWS_ACCESS_KEY_ID or !HUBOT_AWS_ACCESS_KEY_ID
    return robot.logger.error """
      hubot-cloudfront is not loaded due to missing configuration.
      both HUBOT_AWS_ACCESS_KEY_ID and HUBOT_AWS_ACCESS_KEY_ID are required.
    """
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
      res = []
      distIds = []
      list.forEach ({ id, status, domainName, inProgressInvalidationBatches, config }, i)->
        res.push """
                 - #{i}: #{id} --------------------
                   domain: #{domainName}
                   status: #{status}
                 """
        if inProgressInvalidationBatches > 0
          res.push "  invalidations in progress: #{inProgressInvalidationBatches}"
        res.push "  comment: #{comment}" if comment = config?.comment
        res.push ""
        distIds.push id
      robot.brain.set BRAIN_KEY_DISTRIBUTIONS, distIds
      robot.brain.save()
      msg.send res.join '\n'

  robot.respond /\s*(?:cloudfront|cf)\s+(?:list|ls)\s+inv(?:alidat(?:e|ions?)|)\s+([a-z0-9]+)\s*$/i, (msg) ->
    id = msg.match[1]
    distIds = robot.brain.get BRAIN_KEY_DISTRIBUTIONS
    if /^\d+$/.test(id) && distIds?[parseInt(id)]
      id  = distIds[parseInt(id)]
    client.listInvalidations id, (err, list, info)->
      if err?
        msg.reply err.toString()
        return
      unless list?.length > 0
        msg.reply "No invalidations found."
        return
      res = []
      list.forEach ({ id, status })->
        res.push "#{id} - #{status}"
      msg.send res.join '\n'

  robot.respond /\s*(?:cloudfront|cf)\s+inv(?:alidate)?\s+([a-z0-9]+)\s+(.+)\s*$/i, (msg) ->
    [_, id, paths] = msg.match
    paths = paths.trim().split /\s+/
    distIds = robot.brain.get BRAIN_KEY_DISTRIBUTIONS
    if /^\d+$/.test(id) && distIds?[parseInt(id)]
      id  = distIds[parseInt(id)]
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
          room: msg.envelope.room
        robot.brain.set BRAIN_KEY_INVALIDATIONS, invalidations
        robot.brain.save()
      msg.reply """
      Invalidation #{inv.id} on distribution #{inv.distribution} created.
      It might take 10 to 15 minutes until all files are invalidated.
      """
