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
utils = require '../utils'

host = utils.confKey 'mongo.host', 'localhost'
port = utils.confKey 'mongo.port', 27017
db = utils.confKey 'mongo.db' 

# Connect to the 'mythic-forge' database. Will be created if necessary.
# The connection is exported.
module.exports = mongoose.createConnection "mongodb://#{host}:#{port}/#{db}"