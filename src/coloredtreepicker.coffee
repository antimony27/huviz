
TreePicker = require('treepicker').TreePicker

# The states:
#   showing    everything is "shown"
#   mixed      some things are shown
#   unshowing  though there are things, none are shown
#   empty      a mid-level branch which itself has no direct instances
#              (motivated by the taxon_picker which often has levels
#               in its hierarchy which themselves have no direct instances)
#   hidden     a leaf or whole branch which (at the moment) has no instances
#              (motivated by the predicate_picker which needs to hide
#               whole branches which currently contain nothing)
#
# Non-leaf levels in a treepicker can have indirect states different
# from their direct states.  The direct state relates to the direct instances.
# The indirect state spans the direct state of a level and all its children.
# Leaf levels should always have equal direct and indirect states.

L_notshowing = 0.93
L_showing = 0.75
L_emphasizing = 0.5
S_all = 0.5
verbose = false

class ColoredTreePicker extends TreePicker
  constructor: (elem,root,extra_classes,@needs_expander) ->
    super(elem,root,extra_classes,@needs_expander)
    @id_to_colors = {}
    #console.log "ColorTreePicker(): root =",root
  add: (id,parent_id,name,listener) ->
    super(id,parent_id,name,listener)
    # FIXME @recolor_now() unless handled externally
  recolor_now: =>
    @id_to_colors = @recolor()
  recolor: ->
    recursor =
      count: Object.keys(@id_to_elem).length - @get_abstract_count()
      i: 0
    retval = {}
    if verbose
      console.log "RECOLOR" 
    branch = @elem[0][0].children[0]
    @recolor_recurse_DOM(retval, recursor, branch, "")
  recolor_recurse_DOM: (retval, recursor, branch, indent) ->
    branch_id = branch.getAttribute("id")
    class_str = branch.getAttribute("class")
    if verbose
      console.log indent+"-recolor_recurse(",branch_id,class_str,")",branch 
    if branch_id
      @recolor_node(retval, recursor, branch_id, branch, indent) # should this go after recursion so color range can be picked up?
    if branch.children.length > 0
      for elem in branch.children
        if elem?
          class_str = elem.getAttribute("class")
          if class_str.indexOf("treepicker-label") > -1
            continue
          @recolor_recurse_DOM(retval, recursor, elem, indent + " |")
    retval
  container_regex: new RegExp("container")
  contents_regex: new RegExp("contents")
  recolor_node: (retval, recursor, id, elem_raw, indent) ->
    elem = d3.select(elem_raw)
    if @is_abstract(id)
      retval[id] =
        notshowing:  hsl2rgb(0, 0, L_notshowing)
        showing:     hsl2rgb(0, 0, L_showing)
        emphasizing: hsl2rgb(0, 0, L_emphasizing)
    else
      # https://en.wikipedia.org/wiki/HSL_and_HSV#HSL
      recursor.i++        
      hue = recursor.i/recursor.count * 360
      retval[id] =
        notshowing:  hsl2rgb(hue, S_all, L_notshowing)
        showing:     hsl2rgb(hue, S_all, L_showing)
        emphasizing: hsl2rgb(hue, S_all, L_emphasizing)
    if verbose
      console.log(indent + " - - - recolor_node("+id+")",retval[id].notshowing)
    elem.style("background-color",retval[id].notshowing)

  get_color_forId_byName: (id, state_name) ->
    id = @uri_to_js_id(id)
    colors = @id_to_colors[id]
    if colors?
      return colors[state_name]
    else
      msg = "get_color_forId_byName(" + id + ") failed because @id_to_colors[id] not found"
  color_by_selected: (id, selected) ->
    elem = @id_to_elem[id]
    state_name = selected and 'showing' or 'notshowing'
    if elem?
      colors = @id_to_colors[id]
      if colors?
        elem.style("background","").style('background-color',colors[state_name])
      else
        if @id_is_abstract[id]? and not @id_is_abstract[id]
          msg = "id_to_colors has no colors for " + id
          console.debug msg
  set_branch_mixedness: (id, bool) ->
    #  when a div represents a mixed branch then color with a gradient of the two representative colors
    #    https://developer.mozilla.org/en-US/docs/Web/CSS/linear-gradient
    super(id,bool)
    if bool
      if @is_abstract(id) and false
        msg =  "set_branch_mixedness(" +id + "): " + bool + " for abstract"
        # FIXME these colors should come from first and last child of this abstraction
        sc = 'red'
        nc = 'green'
      else
        # these colors show the range from showing to notshowing for this predicate
        id2clr = @id_to_colors[id]
        if id2clr?
          sc = id2clr.showing
          nc = id2clr.notshowing
      if sc?
        @id_to_elem[id].
           style("background": "linear-gradient(45deg, #{nc}, #{sc}, #{nc}, #{sc}, #{nc}, #{sc}, #{nc}, #{sc})").
           style("background-color", "")
    else
      @id_to_elem[id]?style("")
  set_branch_pickedness: (id,bool) ->
    super(id, bool)
    #@color_by_selected(id, bool)
    @render(id,bool)
  render: (id,selectedness) ->
    #if @is_abstract(id)
    #  @set_branch_mixedness(id, selectedness)
    #else
    @color_by_selected(id, selectedness)
  onChangeState: (evt) =>
    super(evt)
    new_state = evt.detail.new_state
    target_id = evt.detail.target_id
    if new_state is "hidden" # means the whole branch has no instances, which is different from "empty" which meains no direct instances
      @set_branch_hiddenness(target_id, true)
    else
      @set_branch_hiddenness(target_id, false)
    if new_state is "showing" # rename allShowing
      @set_branch_pickedness(target_id, true)
    if new_state is "unshowing" # rename noneShowing
      @set_branch_pickedness(target_id, false)
    if new_state is "mixed" # rename partiallyShowing
      @set_branch_mixedness(target_id, true)
      #@set_branch_pickedness(target_id,false)
    else
      @set_branch_mixedness(target_id, false)
  collapse_by_id: (id) ->
    super(id)
    # recolor this node to summarize direct and indirect instances
    @color_node_by_id(id, false)
  expand_by_id: (id) ->
    super(id)
    # recolor this node to summarize just direct instances
    @color_node_by_id(id, true)
  color_node_by_id: (id, direct_only) ->
    # What is weird about this is that instead of an external event
    # telling us what the state should be, we are wanting to discover
    # the hierarchic state (ie if direct_only is false).
    # Since the ColorTreePicker is the View in MVC we do not want it
    # to have to call out to the Model (eg the Taxon) to gain access
    # to the hieraric state.
    # Hence we are tempted to maintain a proxy for the state by id
    # and also knowledge of the hierarchy so we can figure out the
    # hierarchic state.
    state = @get_state_by_id(id, direct_only)
    if state is "mixed"
      @set_branch_mixedness(id, true)
    else if state is "showing"
      @color_by_selected(id,true)
    else if state is "unshowing"
      @color_by_selected(id,true)
    else
      console.warn("color_node_by_id()",arguments,"is confused by", {state: state})
(exports ? this).ColoredTreePicker = ColoredTreePicker
