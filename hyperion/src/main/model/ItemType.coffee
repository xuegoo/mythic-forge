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
###
'use strict'

mongoose = require 'mongoose'
conn = require './connection'
logger = require('../logger').getLogger 'model'

# Define the schema for map item types
ItemTypeSchema = new mongoose.Schema
  # item name
  name: 
    type: String
    required: true

  # definition of item images, stored in an array
  # @example each images is a set of sprites
  #   image: {
  #     # file path
  #     file: {type: String, required: true}
  #     # image width, in pixel
  #     width: {type: Number, required: true}
  #     # image height, in pixel
  #     height: {type: Number, required: true}
  #     # different sprites inside the images, stored by name
  #     sprites: {type: {}, default: {}}
  # @example a sprite inside an image.
  #   sprite: {
  #     # number of sprites
  #     number: {type: Number, required: true}
  #     # duration in milliseconds. Null for infinite sprite.
  #     duration: {type:Number, default: null}
  #     # true to allow move
  #     move: {type:Boolean, default: false}
  images: 
    type: []
    default: -> []

  # item properties definition, stored by names
  # @example property definition include
  #   property: {
  #     # property type, within: string, text, boolean, integer, float, date, array or object
  #     type: {type: String, required: true}
  #     # default value applied
  #     def: {type: {}, required: true}
  properties: 
    type: {}
    default: -> {} # use a function to force instance variable

# local cache.
cache = {}

# setProperty() adds or updates a property.
#
# @param name [String] the unic name of the property.
# @param type [String] primitive type of the property's values. Could be: string, text, boolean, integer, float, date, array or object
# @param def [Object] default value affected to the type instances.
ItemTypeSchema.methods.setProperty = (name, type, def) ->
  @get('properties')[name] = {type: type, def: def}
  @markModified 'properties'
  switch type
    when 'array' then def = []
    when 'object' then def = null
  # Modifiy instances.
  require('./Item').find {type: @_id}, (err, items) =>
    logger.debug "Update property #{name} of #{items.length} item(s) for type #{@._id}"
    for item in items
      if not(name of item)
        item.set name, def
        item.save (err, saved) =>
          throw new Error "Unable to save item #{item._id} of type #{@_id} while setting property #{name}: #{err}" if err?

# unsetProperty() removes a property. All existing instances loose their own property value.
# Will throw an error if the property does not exists.
#
# @param name [String] the unic name of the property.
ItemTypeSchema.methods.unsetProperty = (name) ->
  throw new Error "Unknown property #{name} for item type #{@name}" unless @get('properties')[name]?
  delete @get('properties')[name]
  @markModified 'properties'
  # Modifiy instances.
  require('./Item').find {type: @_id}, (err, items) =>
    logger.debug "Remove property #{name} of #{items.length} item(s) for type #{@._id}"
    for item in items
      item.set name, undefined
      delete item._doc[name]
      item.save (err) =>
        throw new Error "Unable to save item #{item._id} of type #{@_id} while removing property #{name}: #{err}" if err?

# This special finder maintains an in-memory cache of types, to faster type retrieval by ids.
# If the id isn't found in cache, search in database.
#
# @param id [String] the type id.
# @param callback [Function] the callback function, that takes two parameters
# @option callback err [String] an error string, or null if no error occured
# @option callback type [ItemType] the found type, or null if no type found for the id
ItemTypeSchema.statics.findCached = (id, callback) ->
  # first look in the cache
  return callback null, cache[id] if id of cache
  # nothing in the cache: search in database
  @findOne {_id: id}, callback

# post-save middleware: now that the instance was properly saved, update the cache.
#
ItemTypeSchema.post 'save', ->
  # updates the cache
  cache[@_id] = this
  

# post-remove middleware: now that the instace was properly removed, update the cache.
#
ItemTypeSchema.post 'remove', ->
  # updates the cache
  delete cache[@_id]

# post-init middleware: populate the cache
#
ItemTypeSchema.post 'init', ->
  # Store in cache
  cache[@._id] = this

# Export the Class.
module.exports = conn.model 'itemType', ItemTypeSchema