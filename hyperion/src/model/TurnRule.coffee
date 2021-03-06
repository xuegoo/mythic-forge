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

# Turn rules are particular rules that provides two main functions:
#
#     select(callback)
# which is invoked to select a set of Element on which the rule will apply on.
#     execute(target, callback)
# which is invoked when the rule must be effectivly applied.
class TurnRule

  # All objects created or saved by the rule must be added to this array to be saved in database
  saved: []

  # All objects removed by the rule must be added to this array to be removed from database
  removed: []

  # Active status. true by default
  active: true

  # Turn rule rank inside existing rules
  rank: 0

  # Construct a rule, with a fthe rule rank
  constructor: (@rank = 0) ->
    @removed= []
    @saved= []
 
  # This method select a set of element on which execute will be applied.
  # Objects can be read directly from database, but modification is not allowed.
  # This method must be overloaded by sub-classes
  #
  # @param actor [Item] the concerned actor
  # @param target [Item] the concerned target
  # @param callback [Function] called when the rule is applied, with two arguments:
  #   @param err [String] error string. Null if no error occured
  #   @param targets [Array<Object>] list of targeted object, null or empty if the rule does not apply.
  select: (callback) =>
    throw new Error "#{module.filename}.select() is not implemented yet !"

  # This method execute the rule on a targeted object.
  # Nothing can be saved directly in database, but target and its linked objects could be modified and will
  # be saved at the end of the execution.
  # This method must be overloaded by sub-classes
  #
  # @param target [Object] the targeted object
  # @param callback [Function] called when the rule is applied, with two arguments:
  #   @param err [String] error string. Null if no error occured
  execute: (target, callback) =>
    throw new Error "#{module.filename}.execute() is not implemented yet !"

  # Notifications sent to players. 
  # Only available during execute()
  #
  # @param campaign [Object]for each campaign, send an object with properties:
  # @option campaign msg [String] notification message, with placeholders (use #{} delimiters) to use player's attributes
  # @option campaign players [Player|Array<Player>] an array of players to be notified 
  sendCampaign: (campaign) -> 
    throw new Error 'only available at execution'

module.exports = TurnRule