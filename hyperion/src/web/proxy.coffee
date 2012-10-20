###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

logger = require('../logger').getLogger 'web'
express = require 'express'
path = require 'path'
url = require 'url'
fs = require 'fs'
http = require 'http'
coffee = require 'coffee-script'
utils = require '../utils'
stylus = require 'stylus'
notifier = require('../service/Notifier').get()

# Stores authorized tokens to avoid requesting to much playerService
authorizedTokens = {}
# Register handler on players connection and disconnection
notifier.on notifier.NOTIFICATION, (event, state, player) ->
  return unless event is 'players'
  if state is 'connect'
    if player.get 'isAdmin'
      logger.debug "allow static connection from player #{player.id}"
      # adds an entry to grant access on secured RIA 
      token = player.get 'token'
      authorizedTokens[token] = player.id 
  else if state is 'disconnect'
    logger.debug "deny static connection from player #{player.id}"
    # removes entry from the cache
    for token, id of authorizedTokens when id is player.id
      delete authorizedTokens[token]
      break

# creates a single server to serve static files
app = express()

# Register a specific route to return configuration file
# 
# @param base [String] base part of the RIA url. Files will be served under this url. Must not end with '/'
registerConf = (base) ->
  app.get "#{base}/conf.js", (req, res, next) ->
    staticPort = utils.confKey 'server.staticPort'
    host = utils.confKey 'server.host'
    baseUrl = "http://#{host}"
    # port 80 must be omitted, to allow images resolution on client side.
    if staticPort isnt 80
      baseUrl += ":#{staticPort}"
    # compute the client configuration
    conf = 
      separator: path.sep
      basePath: "#{base}/"
      baseUrl: "#{baseUrl}#{base}"
      apiBaseUrl: "https://#{host}:#{utils.confKey 'server.apiPort'}"
      imagesUrl: "#{baseUrl}/images/"

    res.header 'Content-Type', 'application/javascript; charset=UTF-8'
    res.send "window.conf = #{JSON.stringify conf}"


# Configure the proxy to serve a Rich Internet application on a given context
#
# @param base [String] base part of the RIA url. Files will be served under this url. Must not end with '/'
# Must not be a subpart of another RIA
# @param rootFolder [String] path to the local folder that contains the RIA files.
# @param isStatic [Boolean] No coffee or stylus compilation provided. Default to false.
# @param secured [Boolean] Access to this RIA is secured and need authentication. Default to false.
configureRIA = (base, rootFolder, isStatic = false secured = false) ->

  if secured
    # if RIA is secured, register first a security filter
    authentPage = utils.confKey 'authentication.success'
    app.get new RegExp("^#{base}"), (req, res, next) ->
      token = req.signedCookies?.token
      # redirect unless cookie exists
      return res.redirect "#{authentPage}redirect=#{encodeURIComponent req.url}" unless token?
      # proceed if cookie value is known
      return next() if token of authorizedTokens
      # removes the cookie and deny
      res.clearCookie 'token'
      res.redirect "#{authentPage}error=#{encodeURIComponent "#{base} not authorized"}"

  registerConf base

  unless isStatic
    # on-the-fly coffee-script compilation. Must be after static configuration to avoid compiling js external libraries
    app.get new RegExp("^#{base}/(.*)\.js$") , (req, res, next) ->
      # read the coffe corresponding file
      file = path.join rootFolder, "#{req.params[0]}.coffee"
      fs.readFile file, (err, content) => 
        # file not found.
        if err?
          return next if 'ENOENT' is err.code then null else err
        # try to compile it
        try 
          res.header 'Content-Type', 'application/javascript'
          res.send coffee.compile content.toString()
        catch exc
          logger.error "Failed to compile #{file}: #{exc}"
          res.send exc, 500

    # on-the-fly stylus compilation. Must be after static configuration to avoid compiling js external libraries
    app.get new RegExp("^#{base}/(.*)\.css$") , (req, res, next) ->
      # read the stylus corresponding file
      file = path.join rootFolder, "#{req.params[0]}.styl"
      parent = path.dirname file
      fs.readFile file, (err, content) => 
        # file not found.
        if err?
          return next if 'ENOENT' is err.code then null else err 
        # try to compile it
        stylus(content.toString(), {compress:true}).set('paths', [parent]).render (err, css) ->
          return res.send err, 500 if err?
          res.header 'Content-Type', 'text/css'
          res.send css
         
  # SPA root need to be treaten differently, because of pushState. Must be after compilation middleware.
  app.get new RegExp("^#{base}"), (req, res, next) ->
    # redirects with trailing slash to avoid relative path errors from browser
    return res.redirect "#{base}/" if req.url is "#{base}"

    pathname = url.parse(req.url).pathname.slice(base.length+1) or 'index.html'
    # If file exists, serve it statically
    fs.exists path.join(rootFolder, pathname), (exists) =>
      return next() if exists
      # not found: send root file or 404
      fs.createReadStream(path.join(rootFolder, 'index.html')).on('error', => res.send 404).pipe res
      res.header 'Content-Type', 'text/html; charset=UTF-8'

  # last resort: serve static files
  app.use "#{base}", express.static rootFolder

# serve commun static assets
app.use express.cookieParser utils.confKey 'server.cookieSecret'
app.use express.compress level:9
app.use '/images', express.static utils.confKey 'images.store'

# configure a game RIA and the administration RIA 
configureRIA '/game', utils.confKey 'game.production', true
configureRIA '/gamedev', utils.confKey('game.dev'), false, true

if process.NODE_ENV is 'buyvm'
  configureRIA '/rheia', './rheia-min', true
else
  configureRIA '/rheia', './rheia'

# Exports the application.
module.exports = http.createServer app