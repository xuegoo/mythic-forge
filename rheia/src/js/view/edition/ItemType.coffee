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

define [
  'i18n!nls/edition'
  'text!view/edition/template/ItemType.html'
  'utils/utilities'
  'utils/Milk'
  'model/ItemType'
  'widget/loadableImage'
  'widget/property'
], (i18n, template, utilities, Milk, ItemType) ->

  i18n = _.extend {}, i18n

  addImageClass = 'add-image'

  # Displays and edit an ItemType on edition perspective
  # Triggers the following events:
  # - change: when the model save and remove status changed
  class ItemTypeView extends Backbone.View

    # the edited object
    model: null

    # **private**
    # flag that indicates the savable state of the model
    _canSave: false

    # **private**
    # flag that indicates the removable state of the model
    _canRemove: false

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeItemTypeConfirm
    
    # **private**
    # close popup confirmation text, that can take the edited object's name in parameter
    _confirmCloseMessage: i18n.msgs.closeConfirm

    # **private**
    # flag that allow to differentiate external and triggered saves
    _saveInProgress: false

    # **private**
    # flag that indicates that a closure is in progress, and that disable validations
    _isClosing: false

    # **private**
    # flag that allow to differentiate external and triggered removal
    _removeInProgress: false

    # **private**
    # while the edited object is still not saved on server, we need an id.
    _tempId: null

    # **private**
    # array of files that needs to be uploaded
    _pendingUploads: []

    # ** private**
    # the action bar with save, remove and addProperty buttons
    _actionBar: null

    # **private**
    # save button widget
    _saveButton: null

    # **private**
    # remove button widget
    _removeButton: null

    # **private**
    # widget that displays the model's name
    _nameWidget: null

    # **private**
    # widget that displays the model's description
    _descWidget: null

    # **private**
    # description image widget
    _descImageWidget: null

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param id [String] the edited object's id, of null for a creation.
    constructor: (id) ->
      super {tagName: 'div', className:'item-type view'}
      # creation of a new item type if necessary
      if id?
        @model = ItemType.collection.get id
      else 
        @model = new ItemType()
        @model.set 'name', i18n.labels.newName
        @model.set 'descImage', null
        @_tempId = utilities.generateId()

      @_canSave = false
      @_pendingUploads = []
      @_canRemove = @_tempId is null
      # bind change event to the update of action button bar
      @on 'change', =>
        return unless @_actionBar?
        if @canSave() then @_saveButton.enable() else @_saveButton.disable()
        if @canRemove() then @_removeButton.enable() else @_removeButton.disable()

      # bind to server events
      @bindTo ItemType.collection, 'add', @_onCreated
      @bindTo ItemType.collection, 'update', @_onSaved
      @bindTo ItemType.collection, 'remove', @_onRemoved

      console.log "creates item type edition view for #{if id? then @model.id else 'a new object'}"

    # Returns a unique id. 
    #
    # @return If the edited object is persisted on server, return its id. Otherwise, a temporary unic id.
    getId: =>
      (if @_tempId isnt null then @_tempId else @model.id)

    # Returns the view's title
    #
    # @return the edited object name.
    getTitle: =>
      if @_nameWidget? then @_nameWidget.options.value else @model.get 'name'

    # Indicates wether or not this object can be removed.
    # When status changed, a `change` event is triggered on the view.
    #
    # @return the removable status of this object
    canRemove: =>
      @_canRemove

    # Indicates wether or not this object can be saved.
    # When status changed, a `change` event is triggered on the view.
    #
    # @return the savable status of this object
    canSave: =>
      @_canSave and @_pendingUploads.length is 0

    # Returns the view's action bar, and creates it if needed.
    #
    # @return the action bar rendering.
    getActionBar: =>
      return @_actionBar if @_actionBar?
      # creates the rendering
      @_actionBar = $('<div><a class="save"></a><a class="remove"></a></div>')
      # wire the save button
      @_saveButton = $('.save', @_actionBar)
        .attr('title', i18n.tips.save)
        .button(
          icons: 
            primary: 'save small'
          text: false
        )
        .click(@saveModel)
        .data('button')
      # wire the remove button
      @_removeButton = $('.remove', @_actionBar)
        .attr('title', i18n.tips.remove)
        .button(
          icons:
            primary: 'remove small'
          text: false
          disabled: true
        )
        .click(@removeModel)
        .data('button')
      return @_actionBar

    # Method invoked when the view must be closed.
    # @return true if the view can be closed, false to cancel closure
    canClose: =>
      # allow if we are closing, or if no change found
      return true if @_isClosing or !@canSave()
      $("""<div id="confirmClose-#{@getId()}" title="#{i18n.titles.closeConfirm}">
              <span class="ui-icon question"></span>#{_.sprintf(@_confirmCloseMessage, @model.get 'name')}
            </div>""").dialog(
        modal: true
        close: ->
          $(this).remove()
        buttons: [{
          text: i18n.labels.yes,
          icons:
            primary: 'valid small'
          click: =>
            # close dialog
            $("#confirmClose-#{@getId()}").dialog 'close'
            # and save
            @_isClosing = true
            @saveModel()
        },{
          text: i18n.labels.no,
          icons: {
            primary: 'invalid small'
          }
          click: =>
            # close dialog
            $("#confirmClose-#{@getId()}").dialog 'close'
            # and close
            @_isClosing = true
            @trigger 'close'
        },{
          text: i18n.labels.cancel
          icons:
            primary: 'cancel small'
          click: =>
            # just close dialog
            $("#confirmClose-#{@getId()}").dialog 'close'
        }]
      )
      # stop closure
      return false

    # The `render()` method is invoked by backbone to display view content at screen.
    render: =>
      # data needed by the template
      data = 
        title: _.sprintf(i18n.titles.itemType, if @_tempId? then i18n.labels.newType else @model.id)
        i18n: i18n
      # template rendering
      @$el.empty().append Milk.render template, data

      # creates property for name and description
      @_nameWidget = @$el.find('.name.field').property(
        type: 'string'
        allowNull: false
        change: @_onChange
      ).data 'property'

      @_descWidget = @$el.find('.desc.field').property(
        type: 'text'
        allowNull: false
        tooltipFct: i18n.tips.desc
        change: @_onChange
      ).data 'property'

      # first rendering filling
      @_fillRendering()

      # for chaining purposes
      return @

    # Saves the view, by filling edited object with rendering values and asking the server.
    #
    # @param event [event] optionnal click event on the save button
    saveModel: (event = null) =>
      return unless @canSave()
      console.debug "save asked for #{@getId()}"
      event?.preventDefault()
      # fill the model and save it
      @_saveInProgress = true
      @_fillModel()
      if @model.get('descImage') isnt @_descImageWidget.options.source
        spec = {file: @_descImageWidget.options.source}
        if @_descImageWidget.options.source is null
          spec.oldName = @model.get('descImage')  
        @_pendingUploads.push spec

      # first, save model
      @model.save() 
 
    # Removes the view, after displaying a confirmation dialog. (the `remove` methods already exists)
    #
    # @param event [event] optional click event on the remove button
    removeModel: (event = null) =>
      event?.preventDefault()
      return unless @canRemove()
      $("""<div id="confirmRemove-#{@getId()}" title="#{i18n.titles.removeConfirm}">
          <span class="ui-icon question"></span>#{_.sprintf @_confirmRemoveMessage, @model.get 'name'}</div>""").dialog
        modal: true,
        close: ->
          $(this).remove()
        buttons: [{
          text: i18n.labels.no
          showText:false
          icons:
            primary: 'invalid small'
          click: ->
            # simply close the dialog
            $(this).dialog 'close'
        },{
          text: i18n.labels.yes 
          icons:
            primary: 'valid small'
          click: =>
            # close the dialog and remove the model
            $("\#confirmRemove-#{@getId()}").dialog 'close'
            @_removeInProgress = true
            @model.destroy()
        }]

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      @model.set 'name', @_nameWidget.options.value
      @model.set 'desc', @_descWidget.options.value

      # we only are concerned by setting to null, because image upload is managed by `_onSave`
      @model.set 'descImage', null if @_descImageWidget.options.source is null
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      @_nameWidget.setOption 'value', @model.get 'name'
      @_descWidget.setOption 'value', @model.get 'desc'
      @_createImages()
      # first validation
      @_onChange()
    
    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: =>
      comparable = []
      # adds name and description
      comparable.push 
        name: 'name'
        original: @model.get 'name'
        current: @_nameWidget.options.value
      comparable.push 
        name: 'description'
        original: @model.get 'desc'
        current: @_descWidget.options.value
      # adds images
      comparable.push 
        name: 'descImage'
        original: @model.get 'descImage'
        current: @_descImageWidget.options.source
      return comparable;
    
    # **private**
    # Allows to compute the rendering's validity.
    # 
    # @return true if all rendering's fields are valid
    _validate: =>
      isValid = true;
      # todo (isValid = false; break) for validator in @_validators when validator.validate().length isnt 0
      isValid

    # **private**
    # Creates LoadableImage for each images of the edited object
    _createImages: =>
      # the description image
      unless @_descImageWidget?
        @_descImageWidget = @$el.find('.desc.image').loadableImage(
          source: @model.get 'descImage'
          change: @_onChange
        ).data 'loadableImage'
      else 
        @_descImageWidget.setOption 'source', @model.get 'descImage'

    _notifyExternalRemove: =>
      console.trace()
      #todo

    _notifyExternalChange: =>
      console.trace()
      #todo

    # **private**
    # Change handler, wired to any changes from the rendering.
    # Checks if the edited object effectively changed, and update if necessary the action bar state.
    _onChange: =>
      # first, rendering validity
      isValid = @_validate()
      hasChanged = false

      if isValid
        # compares rendering and model values
        comparableFields = @_getComparableFields()
        console.dir comparableFields
        for field in comparableFields
          hasChanged = !(_.isEqual(field.original, field.current))
          if hasChanged
            console.log "field #{field.name} modified"
            break;

      console.log "is valid ? #{isValid} is modified ? #{hasChanged} is new ? #{@_tempId?}"
      @_canSave = isValid and hasChanged
      @_canRemove = @_tempId is null
      # trigger change
      @trigger 'change', @

    # **private**
    # Invoked when a ItemType is created on the server.
    # Triggers the `affectId` event and then call `_onSaved`
    #
    # @param created [Object] the created model
    _onCreated: (created) =>
      return unless @_saveInProgress
      # update the id to allow _onSaved to perform
      @model.id = created.id
      # indicates to perspective that we affected the id.
      @trigger 'affectId', @_tempId, @model.id
      @_tempId = null
      @_onSaved(created)

    # **private**
    # Invoked when a ItemType is saved from the server.
    # Refresh internal and rendering if the saved object corresponds to the edited one.
    #
    # @param saved [Object] the saved model
    _onSaved: (saved) =>
      # takes in account if we updated the edited objet
      return unless saved.id is @model.id
      # if it was a close save, trigger close once again
      if @_isClosing
        console.log "go on with closing #{@getId()}"
        return @trigger 'close'

      console.log "object #{@getId()} saved !"
      @_notifyExternalChange() unless @_saveInProgress
      @_saveInProgress = false;

      # updates edited object
      @model = saved

      # rfresh rendering and exiti, or proceed with changes
      return @_fillRendering() unless @_pendingUploads.length > 0

      spec = @_pendingUploads.splice(0, 1)[0]
      @_saveInProgress = true
      
      if 'oldName' of spec.file
        # removes existing data
        rheia.imagesService.remove 'ItemType', @model.id, spec.oldName, if spec.idx then spec.idx
      else
        # upload new file data
        rheia.imagesService.upload 'ItemType', @model.id, spec, if spec.idx then spec.idx
      
        
    # **private**
    # Invoked when a ItemType is removed from the server.
    # Close the view if the removed object corresponds to the edited one.
    #
    # @param removed [Object] the removed model
    _onRemoved: (removed) =>
      # takes in account if we removed the edited objet,
      return unless removed.id is @model.id
      @_notifyExternalRemove() unless @_removeInProgress
      @_removeInProgress = false;

      @_isClosing = true
      console.log "close the view of #{@getId()} because removal received"
      @trigger 'close'

  return ItemTypeView