# Description:
#   A fork of hubot-markov which models not just all messages, but all messages
#   sent by each particular user. Hubot can now mimic users on command.
#
# Dependencies:
#   hubot-mimic
#
# Configuration:
#   See configuration of hubot-markov 1.3.0
#
# Commands:
#   hubot mimic <id> [<seed>] - Generate a markov chain, optionally seeded with the provided phrase, in the style of user with id <id>. Use 'all' to use a model trained on all users' messages.
#
# Author:
#   jfhamlin (who merely made slight tweaks to the markov.coffee file in the hubot-markov script)

Url = require 'url'
Redis = require 'redis'

MarkovModel = require './model'
RedisStorage = require './redis-storage'

module.exports = (robot) ->

  # Configure redis the same way that redis-brain does.
  info = Url.parse process.env.REDISTOGO_URL or
    process.env.REDISCLOUD_URL or
    process.env.BOXEN_REDIS_URL or
    'redis://localhost:6379'
  client = Redis.createClient(info.port, info.hostname)

  if info.auth
    client.auth info.auth.split(":")[1]

  # Read markov-specific configuration from the environment.
  ply = process.env.HUBOT_MARKOV_PLY or 1
  min = process.env.HUBOT_MARKOV_LEARN_MIN or 1
  max = process.env.HUBOT_MARKOV_GENERATE_MAX or 50

  all_storage = new RedisStorage(client)
  console.log("ln 41")
  console.log(all_storage)
  all_model = new MarkovModel(all_storage, ply, min)
  console.log("ln 44")
  console.log(all_model)

  makeNewModel = (user_id) ->
    console.log(user_id)
    storage = new RedisStorage(client, "markov_#{user_id}:")
    console.log("ln 50")
    console.log(storage)
    return new MarkovModel(storage, ply, min)

  models = {}

  # NSAbot
  robot.catchAll (msg) ->
    # Return on empty messages
    return if !msg.message.text

    user = msg.message.user
    console.log("ln 61")
    console.log(user)
    models[user.id] = models[user.id] or makeNewModel(user.id)
    model = models[user.id]
    console.log("ln 66")
    console.log(model)

    model.learn msg.message.text
    all_model.learn msg.message.text

  # Generate markov chains on demand, optionally seeded by some initial state.
  robot.respond /mimic\s+(\w+)(\s+(.+))?$/i, (msg) ->
    user_id = msg.match[1]
    if user_id == 'all'
      model = all_model
    else
      model = models[user_id]
    if not model
      msg.send 'Derp'
    else
      model.generate (msg.match[3] or ''), max, (text) ->
        console.log("ln 83")
        console.log(text)
        msg.send text