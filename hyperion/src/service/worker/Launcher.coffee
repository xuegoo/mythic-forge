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

cluster = require 'cluster'
# Not a master worker. Only usable in cluster mode as a worker
return if cluster.isMaster

pathUtils = require 'path'
modelWatcher = require('../../model/ModelWatcher').get()
notifier = require('../Notifier').get()
Executable = require '../../model/Executable'
logger = require('../../logger').getLogger 'worker'

ready = false

# init worker's rule cache
Executable.resetAll false, (err) -> 
  unless err?
    ready = true
    return process.emit 'rulesInitialized' 
  logger.error "Failed to initialize worker's executable cache: #{err}"
  process.exit 1

# manage worker unexpected failure
process.on 'uncaughtException', (err) ->
  err = if worker._errMsg? then worker._errMsg + err.stack else err.stack
  # an exception has been caught:
  logger.info "worker #{process.pid} caught unexpected exception: #{err}"
  process.send method: worker._method, results: [err]
  # let it fail: master will respawn it
  process.exit 0

# now that the latest uncaughtException handler have been registered, requires the worker
# that may intercept himself its own failures
worker = require pathUtils.resolve __dirname, process.env.module

# manage events received from master
process.on 'message', (msg) ->
  # do not proceed if still initializing
  if !ready
    process.send method: msg.method, results: ['worker not ready'] if msg?.method of worker
    return
  if msg?.event is 'change'
    # trigger the change as if it comes from the worker's own modelWatcher
    modelWatcher.emit.apply modelWatcher, ['change'].concat msg.args or []
  else if msg?.event is 'executableReset'
    ready = false
    # reloads the executable cache
    Executable.resetAll false, (err) -> 
      return ready = true unless err?
      logger.error "Failed to initialize worker's executable cache: #{err}"
      process.exit 1
  else if msg?.method of worker
    worker._method = msg.method
    # invoke the relevant worker method, adding a callback
    worker[msg.method].apply worker, (msg.args or []).concat (args...) ->
      # callback send back results to cluster master
      process.send method: msg.method, results: args

# on change events, send them back to master
modelWatcher.on 'change', (operation, className, changes, wId) ->
  # do not relay to master changes that comes from another worker !
  return if wId?
  try
    process.send event: 'change', args: [operation, className, changes, process.pid]
  catch err
    # master probably dead.
    console.error "worker #{process.pid}, module #{process.env.module} failed to relay change due to: #{err}"
    process.exit 1

# on notification, send them back to master
notifier.on notifier.NOTIFICATION, (args...) ->
  try 
    process.send event: notifier.NOTIFICATION, args: args, from: process.pid
  catch err
    # master probably dead.
    console.error "worker #{process.pid}, module #{process.env.module} failed to relay notification due to: #{err}"
    process.exit 1
  