###
  Copyright 2010~2014 Damien Feugas

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

_ = require 'lodash'
fs = require 'fs-extra'
path = require 'path'
async = require 'async'
coffee = require 'coffee-script'
cluster = require 'cluster'
pathUtils = require 'path'
linter = require('eslint').linter
modelWatcher = require('./ModelWatcher').get()
logger = require('../util/logger').getLogger 'model'
{enforceFolder, type, isA, confKey, relativePath, fromRule} = require '../util/common'
modelUtils = require '../util/model'
Rule = require '../model/Rule'
TurnRule = require '../model/TurnRule'

# Options used for js syntax checking with linter
lintOpts =
  rules:
    asi: true
    boss: true
    debug: false
    eqnull: true
    evil: true
    iterator: true
    laxcomma: true
    loopfunc: true
    multistr: true
    notypeof: true
    proto: true
    smarttabs: true
    shadow: true
    sub: true
    supernew: true
    validthis: true
  env:
    node: true

Item = null
root = path.resolve path.normalize confKey 'game.executable.source'
compiledRoot = path.resolve path.normalize confKey 'game.executable.target'
encoding = confKey 'game.executable.encoding', 'utf8'
supported = ['.coffee', '.js']
requirePrefix = 'hyperion'
pathToHyperion = relativePath(compiledRoot, path.join(__dirname, '..').replace 'src', 'lib').replace /\\/g, '/' # for Sumblime text highligth bug /'
pathToNodeModules = relativePath(compiledRoot, path.join(__dirname, '..', '..', '..', 'node_modules').replace 'src', 'lib').replace /\\/g, '/' # for Sumblime text highligth bug /'

# when receiving a change from another worker, update the executable cache
modelWatcher.on 'change', (operation, className, changes, wId) ->
  return unless wId? and className is 'Executable'
  # update the executable cache
  switch operation
    when 'creation'
      executables[changes.id] = changes
    when 'update'
      return unless changes.id of executables
      # partial update
      executables[changes.id][attr] = value for attr, value of changes when !(attr in ['id'])
      # clean require cache.
      cleanNodeCache()
    when 'deletion'
      return unless changes.id of executables
      # clean require cache.
      cleanNodeCache()
      delete executables[changes.id]

# hashmap to differentiate creations from updates
wasNew= {}

# Clean nodejs internal require cache when an executable has been updated or deleted, to allow new
# exported value to be available during next require
cleanNodeCache = ->
  delete require.cache[path.resolve path.normalize executable.compiledPath] for id, executable of executables

# Do a single compilation of a source file.
#
# @param executable [Executable] the executable to compile
# @param silent [Boolean] disable change propagation if true
# @param callback [Function] end callback, invoked when the compilation is done with the following parameters
# @option callback err [String] an error message. Null if no error occured
# @option callback executable [Executable] the compiled executable
compileFile = (executable, callback) ->
  # replace requires with references to hyperion
  content = executable.content.replace new RegExp("(require\\s*\\(?\\s*[\"'])#{requirePrefix}", 'g'), "$1#{pathToHyperion}"
  # replace requires with references to node_modules
  content = content.replace new RegExp("(require\\s*\\(?\\s*[\"'])(?!\\.)", 'g'), "$1#{pathToNodeModules}/"
  # compile results
  try
    switch executable.lang
      when 'coffee'
        content = coffee.compile content, bare: true
      when 'js'
        # Only takes in account first error
        report = linter.verify content, lintOpts
        throw "#{report[0].line}:#{report[0].column}, #{report[0].message}" if report.length
  catch exc
    return callback "Error while compilling executable #{executable.id}: #{exc}"

  # Eventually, write a copy with a js extension
  fs.writeFile executable.compiledPath, content, (err) =>
    return callback "Error while saving compiled executable #{executable.id}: #{err}" if err?
    logger.debug "executable #{executable.id} successfully compiled"
    # store it in local cache.
    executables[executable.id] = executable
    # clean require cache.
    cleanNodeCache()
    callback null

# Require an executable, and populate its meta datas
#
# @param executable [Executable] the executable to require
# @param silent [Boolean] disable change propagation if true
# @param callback [Function] end callback, invoked when the compilation is done with the following parameters
# @option callback err [String] an error message. Null if no error occured
# @option callback executable [Executable] the compiled executable
requireExecutable = (executable, silent, callback) ->
  previousMeta = _.clone executable.meta
  try
    executable.meta =
      kind: 'Script'
    # CAUTION ! we need to use relative path. Otherwise, require inside rules will not use the module cache,
    # and singleton (like ModuleWatcher) will be broken.
    obj = require pathUtils.relative __dirname, executable.compiledPath
    if obj? and isA obj, TurnRule
      executable.meta.active = obj.active
      executable.meta.rank = obj.rank
      executable.meta.kind = 'TurnRule'
    else if obj? and isA obj, Rule
      executable.meta.active = obj.active
      executable.meta.category = obj.category
      executable.meta.kind = 'Rule'
    else
      executable.meta.kind = 'Script'
  catch err
    return callback "failed to require executable #{executable.id}: #{err}"

  # propagate change
  unless silent
    modelWatcher.change (if wasNew[executable.id] then 'creation' else 'update'), "Executable", executable
    delete wasNew[executable.id]
  # and invoke final callback
  callback null, executable

# Search inside existing executables. The following searches are supported:
# - {id: String,RegExp]}: search by ids
# - {content: String,RegExp}: search inside executable content
# - {rank: Number}: search inside executable's exported rank attribute
# - {active: Boolean}: search inside executable's exported active attribute
# - {category: String,RegExp}: search inside executable's exported category attribute
# - {and: []}: logical AND between terms inside array
# - {or: []}: logical OR between terms inside array
# Error can be thrown if query isn't valid
#
# @param query [Object] the query object, which structure is validated
# @param all [Array] array of all executable to search within
# @param _operator [String] **inner usage only** operator used for recursion.
# @return a list (that may be empty) of matching executables
search = (query, all, _operator = null) ->
  if Array.isArray query
    return "arrays must contains at least two terms" if query.length < 2

    # we found an array inside a boolean term
    results = []
    for term, i in query
      # search each term
      tmp = search term, all
      if _operator is 'and' and i isnt 0
        # logical AND: retain only global results that match current results
        results = results.filter (result) -> -1 isnt tmp.indexOf result
      else
        # logical OR: concat to global results, and avoid duplicates
        results = results.concat tmp.filter (result) -> -1 is results.indexOf result
    return results

  if 'object' is type query
    # we found a term:  `{or: []}`, `{and: []}`, `{toto:1}`, `{toto:''}`, `{toto://}`
    keys = Object.keys query
    throw new Error "only one attribute is allowed inside query terms" if keys.length isnt 1

    field = keys[0]
    value = query[field]
    # special case of regexp strings that must be transformed
    if 'string' is type(value)
      match = /^\/(.*)\/(i|m)?(i|m)?$/.exec value
      value = new RegExp match[1], match[2], match[3] if match?

    if field is 'and' or field is 'or'
      # this is a boolean term: search inside
      return search value, all, field
    else
      candidates = all.concat()
      if field is 'category' or field is 'rank' or field is 'active'
        # We must replace executables by their exported object.
        candidates = all.map (candidate) ->
          # CAUTION ! we need to use relative path. Otherwise, require inside rules will not use the module cache,
          # and singleton (like ModuleWatcher) will be broken.
          return require path.relative __dirname, candidate.compiledPath
      # matching candidates ids
      ids = []
      # this is a terminal term, validates value's type
      switch type value
        when 'string', 'number', 'boolean'
          # performs exact match
          candidates.forEach (candidate, i) -> ids.push i if candidate[field] is value
        when 'regexp'
          # performs regexp match
          candidates.filter (candidate, i) -> ids.push i if value.test candidate[field]
        else throw new Error "#{field}:#{value} is not a valid value"
      # return the matching executable. Do not use candidates array because it may contains exported rules,
      # not executables
      return all.filter (executable, i) -> i in ids
  else
    throw new Error "'#{query}' is nor an array, nor an object"

# local cache of executables
executables = {}

# Executable are Javascript executable script, defined at runtime and serialized on the file-system
class Executable

  # Reset the executable local cache. It recompiles all existing executables
  #
  # @param clean [Boolean] true to clean the compilation folder and recompile everything.
  # False to only popuplate the local executable cache.
  # @param callback [Function] invoked when the reset is done.
  # @option callback err [String] an error callback. Null if no error occured.
  @resetAll: (clean, callback) ->
    return if fromRule callback
    # to avoid circular dependency
    Item = require '../model/Item'
    # clean local files, and compiled scripts
    cleanNodeCache()
    removed = _.keys executables
    executables = {}
    enforceFolder compiledRoot, clean, logger, (err) ->
      return callback err if err?

      fs.readdir root, (err, files) ->
        return callback "Error while listing executables: #{err}" if err?

        readFile = (file, end) ->
          # only take coffeescript in account
          ext = path.extname file
          return end() unless ext in supported
          # creates an empty executable
          executable = new Executable {id:file.replace(ext, ''), lang: ext[1..]}

          fs.stat executable.path, (err, stat) ->
            if err?
              return end() if err.code is 'ENOENT'
              return callback "Error while reading executable '#{executable.id}': #{err}"

            # keep last update time
            executable.updated = stat.mtime
            executable.updated.setMilliseconds 0

            fs.readFile executable.path, encoding, (err, content) ->
              if err?
                return callback "Error while reading executable '#{executable.id}': #{err}"

              # complete the executable content, and add it to the array.
              executable.content = content
              compileFile executable, (err) ->
                return callback "Compilation failed: #{err}" if err?
                end()

        # each individual file must be read
        async.each files, readFile, (err) ->
          return callback err if err?

          # know, require files
          async.each _.values(executables), (executable, next) ->
            requireExecutable executable, true, next
          , (err) ->
            logger.debug 'Local executables cached successfully reseted' unless err?
            # ask to all worker to reload also
            if cluster.isMaster
              # to remove ids from idCache
              modelWatcher.emit 'executableReset', removed
              worker.send event: 'executableReset' for id, worker of cluster.workers
            callback err

  # Find existing executables.
  #
  # @param query [Object|String] optionnal condition to select relevant executables. Same syntax as MongoDB queries, supports:
  # - $and
  # - $or
  # - 'id' field (search by id) with string
  # - 'content' field (search in content) with string or regexp
  # - 'category' field (search rules' category) with string or regexp
  # - 'rank' field (search turn rules' rank) with number
  # - 'active' field (search (turn) rules' active) with boolean
  # Regexp values are supported in String version: "/.*/i" will be parsed into /.*/i
  # @param callback [Function] invoked when all executables were retrieved
  # @option callback err [String] an error message if an error occured. null otherwise
  # @option callback executables [Array<Executable>] list (may be empty) of executables
  @find: (query, callback) ->
    if 'function' is type query
      callback = query
      query = null

    results = []
    # just take the local cache and transforms it into an array.
    results.push executable for id, executable of executables
    # and perform search if relevant
    results = search query, results if query?
    callback null, results

  # Find existing executable by id, from the cache.
  #
  # @param ids [Array] the executable ids
  # @param callback [Function] optionnal callback invoked when all executables were retrieved
  # @option callback err [String] an error message if an error occured. null otherwise
  # @option callback executables [Executable] list of corresponding executable, may be empty
  # @return if no callback provided, list of corresponding executable, may be empty
  @findCached: (ids, callback = null) ->
    found = (executables[id] for id in ids when id of executables)
    return found unless callback?
    callback null, found

  # The unic file name of the executable, which is also its id.
  id: null

  # The executable language (Coffee-Script by default)
  lang: 'coffee'

  # Executable metadatas, depending on the content.
  # At least, meta contains the kind property, that might be 'Rule', 'TurnRule' or 'Script'
  # For rules, meta contains also `category` and `active` properties, and for turn rules `active` and `rank`.
  meta: {}

  # The executable content (Utf-8 string encoded).
  content: ''

  # Date of last update, populated when content is read
  updated: null

  # Absolute path to the executable source.
  path: ''

  # Absolute aath to the executable compiled script
  compiledPath: ''

  # Create a new executable, with its file name.
  #
  # @param attributes object raw attributes, containing:
  # @option attributes id [String] its file name (without it's path).
  # @option attributes content [String] the file content. Empty by default.
  constructor: (attributes) ->
    @id = attributes.id
    @content = attributes.content or ''
    @lang = attributes.lang or 'coffee'
    @path = path.join root, "#{@id}.#{@lang}"
    @compiledPath = path.join compiledRoot, @id+'.js'

  # Save (or update) a executable and its content.
  #
  # @param callback [Function] called when the save is finished, with two arguments:
  #   @param err [String] error string. Null if save succeeded
  #   @param item [Item] the saved item
  save: (callback) =>
    return if fromRule callback
    wasNew[@id] = !(@id of executables)
    # check id unicity and validity
    return callback new Error "id #{@id} for model Executable is invalid" unless modelUtils.isValidId @id
    return callback new Error "id #{@id} for model Executable is already used" if wasNew[@id] and Item.isUsed @id
    fs.writeFile @path, @content, encoding, (err) =>
      return callback "Error while saving executable #{@id}: #{err}" if err?
      logger.debug "executable #{@id} successfully saved"
      # Trigger the compilation.
      compileFile @, (err) =>
        return callback err if err?
        # update last access date
        @updated = new Date()
        @updated.setMilliseconds 0

        # and require immediately
        requireExecutable @, false, callback

  # Remove an existing executable.
  #
  # @param callback [Function] called when the removal is finished, with two arguments:
  #   @param err [String] error string. Null if save succeeded
  #   @param item [Item] the removed item
  remove: (callback) =>
    return if fromRule callback
    fs.exists @path, (exists) =>
      return callback "Error while removing executable #{@id}: this executable does not exists" if not exists
      cleanNodeCache()
      delete executables[@id]
      fs.unlink @path, (err) =>
        return callback "Error while removing executable #{@id}: #{err}" if err?
        fs.unlink @compiledPath, (err) =>
          logger.debug "executable #{@id} successfully removed"
          # propagate change
          modelWatcher.change 'deletion', "Executable", @
          callback null, @

  # Provide the equals() method to check correctly the equality between ids.
  #
  # @param other [Object] other object against which the current object is compared
  # @return true if both objects have the same id, false otherwise
  equals: (object) =>
    return false unless 'object' is type object
    @id is object?.id

module.exports = Executable
