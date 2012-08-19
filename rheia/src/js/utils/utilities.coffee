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

define [
  'jquery'
  'underscore'
], ($, _) ->

  classToType = {}
  for name in "Boolean Number String Function Array Date RegExp Undefined Null".split(" ")
    classToType["[object " + name + "]"] = name.toLowerCase()

  generateId = () ->
    return "#{parseInt(Math.random()*1000000000)}" 

  return {

    # This method is intended to replace the broken typeof() Javascript operator.
    #
    # @param obj [Object] any check object
    # @return the string representation of the object type. One of the following:
    # object, boolean, number, string, function, array, date, regexp, undefined, null
    #
    # @see http://arcturo.github.com/library/coffeescript/07_the_bad_parts.html
    type: (obj) ->
      strType = Object::toString.call(obj)
      return classToType[strType] or "object"

    # Generates a pseudo random id.
    #
    # @return a string id. 
    generateId: generateId 

    # Sort alphabetically sort attributes of an object.
    #
    # @param object [Object] object which attributes are sorted
    # @return the main object with its attributes sorted.
    sortAttributes: (object) ->
      result= {}
      names= _.keys(object).sort()
      result[name] = object[name] for name in names
      return result


    # Displays a popup window, with relevant title, message and buttons.
    # Button handler can be specified
    #
    # @param title [String] the popup title
    # @param message [String] the popup message
    # @param messageIcon [String] if not null, an icon displayed next to the popup message
    # @param buttons [Array] an array (order is significant) or buttons:
    # @option buttons text [String] the button text
    # @option buttons icon [String] the button icon classes
    # @option buttons click [Function] the button handler
    # @param closeIndex [Number] index in the buttons array of the handler invoked when using the popup close button, 0 by default
    # @return the generated popup dialog
    popup: (title, message, messageIcon, buttons, closeIndex = 0) ->
      # parameter validations
      throw new Error('popup() must be called with at least one button') unless Array.isArray(buttons) and buttons.length > 0
      throw new Error("closeIndex #{closeIndex} is not a valid index in the buttons array") unless closeIndex >= 0 and closeIndex < buttons.length
      id = generateId()

      buttonSpec = []
      for spec in buttons
        buttonSpec.push( 
          text: spec.text
          click: ((handler)-> (event) -> 
            # remove popup and invoke possible handler
            $("##{id}").remove()
            handler() if handler?
          )(spec.click)
        )
        buttonSpec[buttonSpec.length-1].icons = {primary: "small #{spec.icon}"} if spec.icon?

      html = "<div id='#{id}' title='#{title}'>"
      html += "<span class='ui-icon #{messageIcon}'></span>" if messageIcon?
      html += "#{message}</div>"
      $(html).dialog(
          modal: true
          close: (event) -> buttonSpec[closeIndex].click()
          buttons: buttonSpec
        )

    # Transforms a ccmel case string into a dash separated lower case string
    #
    # @param string [String] the processed string
    # @return the dash version of the string.
    dashSeparated: (string) ->
      return string unless string?
      result = ''
      for char,i in string
        if char is char.toUpperCase() and i > 0
          result += '-'  
        result += char.toLowerCase()
      return result
  }