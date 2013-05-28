# [Script Runner](http://neocotic.com/script-runner)  
# (c) 2013 Alasdair Mercer  
# Freely distributable under the MIT license

# Settings
# --------

# TODO: Document
bindSetting = (field) ->
  # Extract all setting data from `field`.
  area = field.data('setting-area') ? 'local'
  name = field.attr 'name'
  type = field.data('setting-type') ? 'text'

  # TODO: Comment
  convert = (value) ->
    switch type
      when 'json' then JSON.parse value ? null
      when 'text' then value ? ''

  value = convert field.data 'setting-default'

  # Ensure any previously bound settings-related events are removed first.
  field.off '.setting'

  # TODO: Comment
  store[area].get name, value, (value) ->
    if field.is ':checkbox, :radio'
      field.on 'change.setting', ->
        store[area].set name, field.is ':checked'

      field.prop('checked', value).trigger 'change'
    else if field.is 'input[type=number]'
      type = 'json'

      field.on 'input.setting', ->
        min = field.attr('min') ? 0
        store[area].set name, convert(field.val()) ? min

      field.val(value).trigger 'input'
    else if field.is ':text, :password, textarea'
      field.on 'input.setting', ->
        store[area].set name, convert field.val()

      field.val(value).trigger 'change'
    else if field.is 'select'
      field.on 'change.setting', ->
        store[area].set name, if field.is '[multiple]'
          (convert val for val in field.val() ? [])
        else
          convert field.val()

      field.find('option').each ->
        option = $ this

        option.prop 'selected', if _.isArray value
          _(value).contains option.val()
        else
          "#{value}" is option.val()
      field.trigger 'change'

# Editor
# ------

# TODO: Document
editor = null

# TODO: Document
loadEditor = ->
  config = options.config.editor
  editor = ace.edit 'editor'

  editor.setReadOnly yes
  editor.setShowPrintMargin no

  # TODO: Comment
  group = $ '[name=editorIndentSize] optgroup'
  group.remove 'option'
  _(config.indentSizes).each (size) ->
    group.append $ '<option/>', text: size

  # TODO: Comment
  group = $ '[name=editorTheme] optgroup'
  group.remove 'option'
  _(config.themes).each (theme) ->
    group.append $ '<option/>',
      html:  i18n.get "editor_theme_#{theme}"
      value: theme

  # TODO: Comment
  group = $ '#editor_modes optgroup'
  group.remove 'option'
  _(config.modes).each (mode) ->
    group.append $ '<option/>',
      html:  i18n.get "editor_mode_#{mode}"
      value: mode

  # TODO: Comment
  $('#editor_modes').on('change', ->
    mode = $(this).val()

    editor.getSession().setMode "ace/mode/#{mode}"
    # TODO: Update active script type
  ).val DEFAULT_MODE

  # TODO: Comment
  store.sync.onChanged 'editorSoftTabs', (soft) ->
    editor.getSession().setUseSoftTabs soft

  store.sync.onChanged 'editorIndentSize', (size) ->
    if _(config.indentSizes).contains size
      editor.getSession().setTabSize size

  store.sync.onChanged 'editorLineWrap', (wrap) ->
    editor.getSession().setUseWrapMode wrap

  store.sync.onChanged 'editorTheme', (theme) ->
    if _(config.themes).contains theme
      editor.setTheme "ace/theme/#{theme}"

# Feedback
# --------

# Indicate whether or not the user feedback feature has been added to the page.
feedbackAdded = no

# Add the user feedback feature to the page.
loadFeedback = ->
  # Only load and configure the feedback widget once.
  return if feedbackAdded

  {id, forum} = options.config.options.userVoice

  # Create a script element to load the UserVoice widget.
  uv       = document.createElement 'script'
  uv.async = 'async'
  uv.src   = "https://widget.uservoice.com/#{id}.js"
  # Insert the script element into the DOM.
  script = document.getElementsByTagName('script')[0]
  script.parentNode.insertBefore uv, script

  # Configure the widget as it's loading.
  UserVoice = window.UserVoice or= []
  UserVoice.push [
    'showTab'
    'classic_widget'
    {
      mode:          'full'
      primary_color: '#333'
      link_color:    '#08c'
      default_mode:  'feedback'
      forum_id:      forum
      tab_label:     i18n.get 'feedback_button'
      tab_color:     '#333'
      tab_position:  'middle-left'
      tab_inverted:  yes
    }
  ]

  # Ensure that the widget isn't loaded again.
  feedbackAdded = yes

# General
# -------

# TODO: Document
loadAnalytics = ->
  store.sync.onChanged 'analytics', (enabled) ->
    if enabled
      analytics.init()
      analytics.track 'General', 'Changed', 'Analytics', 1
    else
      analytics.track 'General', 'Changed', 'Analytics', 0
      analytics.remove()

# Scripts
# -------

# TODO: Document
DEFAULT_MODE = 'javascript'

# TODO: Document
Script = Backbone.Model.extend

  defaults:
    active: no
    code:   ''
    mode:   'javascript'

  validate: (attributes) ->
    {host, mode} = attributes

    unless host
      # TODO: Verify `host` is unique?
      'host is required'
    else unless mode
      'mode is required'
    else unless _(options.config.editor.modes).contains mode
      'mode is unrecognized'

# TODO: Document
Scripts = Backbone.Collection.extend

  chromeStorage: new Backbone.ChromeStorage 'Scripts', 'local'

  model: Script

# TODO: Document
ScriptItem = Backbone.View.extend

  tagName: 'li'

  template: _.template '<a><%= host %></a>'

  initialize: ->
    # TODO: Add link
    @listenTo @model, 'change', @render
    @listenTo @model, 'destroy', @remove

  remove: ->
    @$el.remove()

  render: ->
    @$el.html @template @model.attributes

    this

# TODO: Document
ScriptsList = Backbone.View.extend

  tagName: 'ul'

  className: 'nav nav-pills nav-stacked'

  addOne: (model) ->
    @$el.append new ScriptItem({model}).render().el

  addAll: ->
    _(@collection).each @addOne, this

  initialize: ->
    @listenTo @collection, 'add', @addOne
    @listenTo @collection, 'reset', @addAll
    @listenTo @collection, 'change', @render
    @listenTo @collection, 'destroy', @remove

  remove: ->
    @$el.remove()

  render: ->
    # TODO: Is `ul` tag generated and appended automatically?
    do @addAll

    this

# TODO: Documnet
ScriptsView = Backbone.View.extend

  initialize: ->
    @collection = new Scripts

  render: ->
    # TODO: Complete
    @list = new ScriptsList {@collection}
    @$('#scripts_nav').append @list.render().$el

    this

# TODO: Comment and/or move
scriptsView = new ScriptsView el: $ '#scripts_tab'

# TODO: Document
store.local.onChanged '*', (name, newValue, oldValue) ->
  domain = name.match(/script_(.+)/)?[1]
  return unless domain

  @trigger domain, @diff newValue, oldValue

# TODO: Document
getActiveDomain = ->
  $('#scripts li.active a').text() or null

# TODO: Document
getScript = (domain, callback) ->
  return do callback unless domain

  store.local.get "script_#{domain}", {}, (script) ->
    callback script

# TODO: Document
hasExistingDomain = (domain, callback) ->
  store.local.get 'domains', [], (domains) ->
    callback _(domains).contains domain

# TODO: Document
hasUnsavedChanges = (callback) ->
  getScript do getActiveDomain, (script) ->
    callback if script? and script.code isnt editor.getValue()

# TODO: Document
hideDomain = (domain) ->
  $('#scripts li a').each ->
    $this = $ this
    $this.remove() if $this.text() is domain

# TODO: Document
loadScripts = ->
  # TODO: Comment
  store.local.get 'domains', [], (domains) ->
    _(domains).each showDomain

  # TODO: Comment
  $('#add_button, #clone_button').popover(
    html:      yes
    placement: 'bottom'
    trigger:   'manual'
    content:   """
      <form class="form-inline" id="new_script">
        <div class="control-group">
          <input type="text" placeholder="yourdomain.com">
        </div>
      </form>
    """
  ).on('shown', ->
    button = $ this

    # TODO: Comment
    $('#new_script').on('submit', ->
      $this  = $ this
      group  = $this.find '.control-group'
      domain = $this.find(':text').val().replace /\s+/g, ''

      hasExistingDomain domain, (exists) ->
        if not domain or exists
          group.addClass 'error'
        else
          group.removeClass 'error'

          if button.is '#add_button'
            updateScript domain, {
              code: ''
              mode: DEFAULT_MODE
            }, ->
              # TODO: Make new script active in editor

              analytics.track 'Scripts', 'Added', domain

              button.popover 'hide'
          else
            clonedDomain = do getActiveDomain

            getScript clonedDomain, (script) ->
              updateScript domain, _.clone(script), ->
                # TODO: Make cloned script active in editor

                analytics.track 'Scripts', 'Cloned', clonedDomain, domain

                button.popover 'hide'

      false
    ).find(':text').focus().on 'keydown', (e) ->
      # TODO: Comment
      button.popover 'hide' if e.keyCode is 27
  ).on 'click', ->
    # TODO: Comment
    $this = $ this
    $this.popover 'toggle' unless $this.is '.disabled'

  # TODO: Comment
  $('#delete_button').on 'click', ->
    return if $(this).is '.disabled'

    domain = do getActiveDomain

    # TODO: Prompt user to confirm action
    removeScript domain, ->
      analytics.track 'Scripts', 'Deleted', domain

  # TODO: Comment
  $('#scripts li a').on 'click', (e) ->
    $this  = $ this
    item   = $this.parent()
    active = item.hasClass 'active'

    if active and e.ctrlKey
      # TODO: Comment
      item.removeClass 'active'

      # TODO: Clear editor
    else if not active
      # TODO: Comment
      item.addClass('active').siblings().removeClass 'active'

      # TODO: Change editor to reflect newly select script

  # TODO: Comment
  store.local.onChanged 'domains', (newValue = [], oldValue = []) ->
    activeDomain = do getActiveDomain

    if newValue.length > oldValue.length
      # One or more domains have been added so they need to be displayed.
      newDomains  = _(newValue).difference oldValue
      swapContext = no

      if activeDomain
        # TODO: If the active script has unsaved changes, ask user if they want to save or discard
        # them and switch to the newest (last) domain, or stay put.
        # TODO: See `hasUnsavedChanges`
        # TODO: Only change `swapContext` to `yes` **if** user confirmed action, but after saving
        # **if** they requested to do so.
        swapContext = yes

      for domain, i in newDomains
        activate = swapContext and i is newDomains.length - 1

        showDomain domain, activate
        # TODO: Change editor context **if** `activate`
    else
      removedDomains = _(oldValue).difference newValue

      for domain in removedDomains
        hideDomain domain
        # TODO: Clear editor context **if** `domain is activeDomain`

# TODO: Document
removeScript = (domain, callback) ->
  store.local.get 'domains', [], (domains) ->
    return unless _(domains).contains domain

    domains = _(domains).without domain
    name    = "script_#{domain}"

    store.local.remove name, ->
      store.local.set 'domains', domains, ->
        callback?()

# TODO: Document
showDomain = (domain, active) ->
  item = $ '<li/>'
  item.append $ '<a/>', text: domain
  item.appendTo $ '#scripts'
  item.addClass('active').siblings().removeClass 'active' if active

# TODO: Document
updateScript = (domain, properties, callback) ->
  store.local.get 'domains', [], (domains) ->
    name = "script_#{domain}"

    domains.push domain unless _(domains).contains domain

    store.local.get name, {}, (script) ->
      _(script).extend properties

      changes = {domains}
      changes[name] = script

      store.local.set changes, ->
        callback?()

# User interface
# --------------

# TODO: Document
class UI extends utils.Class

  # TODO: Complete

# Miscellaneous
# -------------

# Activate tooltip effects, optionally only within a specific context.
activateTooltips = (selector) ->
  base = $ selector or document

  # Reset all previously treated tooltips.
  base.find('[data-original-title]').each ->
    $this = $ this

    $this.tooltip 'destroy'
    $this.attr 'title', $this.attr 'data-original-title'
    $this.removeAttr 'data-original-title'

  # Apply tooltips to all relevant elements.
  base.find('[title]').each ->
    $this = $ this

    $this.tooltip
      container: $this.attr('data-container') ? 'body'
      placement: $this.attr('data-placement') ? 'top'

# Options page setup
# ------------------

options = window.options = new class Options extends utils.Class

  # Create a new instance of `Options`.
  constructor: ->
    @config  = {}
    @version = ''

  # Public functions
  # ----------------

  # Initialize the options page.  
  # This will involve inserting and configuring the UI elements as well as loading the current
  # settings.
  init: ->
    # Add support for analytics if the user hasn't opted out.
    analytics.init()

    # It's nice knowing what version is running.
    {@version} = chrome.runtime.getManifest()

    # Load the configuration data from the file before storing it locally.
    $.getJSON utils.url('configuration.json'), (@config) =>
      # Add the user feedback feature to the page.
      do loadFeedback

      # Begin initialization.
      i18n.traverse()

      # Ensure the current year is displayed throughout, where appropriate.
      $('.year-repl').html "#{new Date().getFullYear()}"

      # Bind tab selection event to all tabs.
      initialTabChange = yes
      $('a[data-tabify]').on 'click', ->
        target = $(this).data 'tabify'
        nav    = $ "#navigation a[data-tabify='#{target}']"
        parent = nav.parent 'li'

        unless parent.hasClass 'active'
          parent.addClass('active').siblings().removeClass 'active'
          $(target).show().siblings('.tab').hide()

          id = nav.attr 'id'
          store.sync.set 'activeTab', id, ->
            unless initialTabChange
              id = utils.capitalize id.match(/(\S*)_nav$/)[1]
              analytics.track 'Tabs', 'Changed', id

            initialTabChange = no
            $(document.body).scrollTop 0

      # Reflect the previously persisted tab initially.
      store.sync.get 'activeTab', 'general_nav', (activeTab) ->
        $("##{activeTab}").trigger 'click'

      # Ensure that form submissions don't reload the page.
      $('form:not([target="_blank"])').on 'submit', ->
        # Return `false` to ensure default behaviour is prevented.
        false

      # Bind analytical tracking events to key footer buttons and links.
      $('footer a[href*="neocotic.com"]').on 'click', ->
        analytics.track 'Footer', 'Clicked', 'Homepage'

      # Setup and configure the donation button in the footer.
      $('#donation input[name="hosted_button_id"]').val @config.options.payPal
      $('#donation').on 'submit', ->
        analytics.track 'Footer', 'Clicked', 'Donate'

      do activateTooltips

      do loadAnalytics
      do loadEditor
      do loadScripts

      # TODO: Remove debug
      for area in ['local', 'sync']
        store[area].onChanged '*', (name, newValue, oldValue) ->
          newValue = JSON.stringify newValue if _.isObject newValue
          oldValue = JSON.stringify oldValue if _.isObject oldValue
          console.log "#{name} setting has been changed in #{area} from '#{oldValue}' to '#{newValue}'"

      # TODO: Comment
      $('[name][data-setting-area]').each ->
        bindSetting $ this

# Initialize `options` when the DOM is ready.
$ -> options.init()
