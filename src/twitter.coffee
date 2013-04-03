{Robot, Adapter, TextMessage} = require 'hubot'
{EventEmitter}                = require 'events'

HTTPS                         = require 'https'
oauth                         = require 'oauth'

class Twitter extends Adapter
  send: (envelope, strings...) ->
     console.log "Sending strings to user: " + envelope.user.name
     strings.forEach (str) =>
       text = str
       tweetsText = str.split('\n')
       tweetsText.forEach (tweetText) =>
         @bot.speak(envelope.user.name,tweetText)

  run: ->
    self = @

    options =
      key         : process.env.HUBOT_TWITTER_KEY
      secret      : process.env.HUBOT_TWITTER_SECRET
      token       : process.env.HUBOT_TWITTER_TOKEN
      tokensecret : process.env.HUBOT_TWITTER_TOKEN_SECRET 

    bot = new TwitterStreaming(options, @robot)

    bot.on "TextMessage", (id, room, user, body) ->
        reg = new RegExp('@'+self.robot.name,'i')
        body = body.replace reg, self.robot.name
        author = self.userForId(id, user)
        author.room = room
        self.receive new TextMessage author, body, id

    bot.listen(self.robot.name)

    @bot = bot
   
    self.emit "connected"

exports.use = (robot) ->
  new Twitter robot

class TwitterStreaming extends EventEmitter
  
  constructor: (options, @robot) ->
    if options.token? and options.secret? and options.key? and options.tokensecret?
      @token         = options.token
      @secret        = options.secret
      @key           = options.key
      @host          = 'stream.twitter.com'
      @tokensecret   =  options.tokensecret
      @consumer = new oauth.OAuth "https://twitter.com/oauth/request_token",
                           "https://twitter.com/oauth/access_token",
                           @key,
                           @secret,
                           "1.0",
                           "",
                           "HMAC-SHA1"
    else
      throw new Error("Not enough parameters provided. I need a key, a secret, a token, a secret token")
 
  # Convenience HTTP Methods for posting on behalf of the token"d user
  get: (path, callback) ->
   @request "GET", path, null, callback

  post: (path, body, callback) ->
   @request "POST", path, body, callback

  request: (method, path, body, callback) ->
    console.log "https://#{@host}#{path}, #{@token}, #{@tokensecret}, null"

    request = @consumer.get "https://#{@host}#{path}", @token, @tokensecret, null
    console.log request
    request.on "response",(response) ->
      response.on "data", (chunk) ->
        console.log chunk+''
        parseResponse chunk+'',callback

      response.on "end", (data) ->
        console.log 'end request'

      response.on "error", (data) ->
        console.log 'error '+data

    request.end()

    parseResponse = (data,callback) ->
      while ((index = data.indexOf('\r\n')) > -1)
        json = data.slice(0, index)
        data = data.slice(index + 2)
        if json.length > 0
          try
             callback JSON.parse(json), null
          catch err
             console.log "error parse"+json

  listen: (track) ->
    self = @
    path = "/1/statuses/filter.json?track=#{track}"
    request = @consumer.get "https://#{@host}#{path}", @token, @tokensecret, null
    console.log request
    request.on "response",(response) ->
      response.on "data", (chunk) ->
        console.log chunk+''
        parseResponse chunk+''

      response.on "end", (data) ->
        console.log 'end request'

      response.on "error", (data) ->
        console.log 'error '+data

    request.end()

    parseResponse = (data) ->
      while ((index = data.indexOf('\r\n')) > -1)
        json = data.slice(0, index)
        data = data.slice(index + 2)
        if json.length > 0
          try
            dataset = JSON.parse json
            self.emit(
              "TextMessage",
              dataset.user.screen_name,
              'Twitter',
              dataset.user.name,
              dataset.text
            )
          catch err
            console.log "Twitter error: #{err}\n#{err.stack}"

  speak : (user,tweetText) ->
    console.log "send twitt to #{user} with text #{tweetText}"
    @consumer.post "https://api.twitter.com/1/statuses/update.json", @token, @tokensecret, { status: "@#{user} #{tweetText}" },'UTF-8',  (error, data, response) ->
      if error
        console.log "twitter send error: #{error} #{data}"
      console.log "Status #{response.statusCode}"


