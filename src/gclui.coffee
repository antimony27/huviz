###
# verbs: choose,label,discard,shelve,unlabel
# classes: writers,others,people,orgs # places,titles
# like:
# ids:
#
#  choose,label/unlabel,discard,shelve,expand
#
###
angliciser = require('angliciser').angliciser
gcl = require('graphcommandlanguage')
TreePicker = require('treepicker').TreePicker
ColoredTreePicker = require('coloredtreepicker').ColoredTreePicker
class CommandController
  constructor: (@huviz,@container,@hierarchy) ->
    document.addEventListener 'dataset-loaded', @on_dataset_loaded
    d3.select(@container).html("")
    @init_indices()
    @comdiv = d3.select(@container).append("div")
    #@gclpane = @comdiv.append('div').attr('class','gclpane')
    @cmdlist = @comdiv.append('div').attr('class','commandlist')
    @title_bar_controls()        
    @oldcommands = @cmdlist.append('div').attr('class','commandhistory')
    @nextcommandbox = @comdiv.append('div')
    @verbdiv = @comdiv.append('div').attr('class','verbs')
    @likediv = @comdiv.append('div')
    #@taxdiv = @comdiv.append('div').attr('class','taxonomydiv')
    @add_clear_both(@comdiv)
    @build_nodeclasspicker()
    @add_clear_both(@comdiv)
    @build_predicatepicker()
    @init_editor_data()
    @build_form()
    @update_command()
    @install_listeners()

  install_listeners: () ->
    window.addEventListener 'changePredicate', @onChangePredicate

  onChangePredicate: (evt) =>
    new_state = evt.detail.new_state
    pred_id = evt.detail.predicate.lid
    console.debug pred_id,new_state,evt.detail.predicate
    if new_state is "hidden"
      @predicate_picker.set_branch_hiddenness(pred_id, true)
    else
      @predicate_picker.set_branch_hiddenness(pred_id, false)
    if new_state is "showing"
      @predicate_picker.set_branch_pickedness(pred_id, true)
    if new_state is "unshowing"
      @predicate_picker.set_branch_pickedness(pred_id, false)
    if new_state is "mixed"
      @predicate_picker.set_branch_mixedness(pred_id, true)
    else
      @predicate_picker.set_branch_mixedness(pred_id, false)
      
  on_dataset_loaded: (evt) =>
    if not evt.done?
      @pick_everything()
      @recolor_edges()
      # FIXME is there a standards-based way to prevent this happening three times?
      evt.done = true

  pick_everything: =>
    @onnodeclasspicked 'everything',true

  init_editor_data: ->
    # operations common to the constructor and reset_editor
    @shown_edges_by_predicate = {}
    @unshown_edges_by_predicate = {}
    @node_classes_chosen = [] # new SortedSet()
    #@subjects = [] # FIXME remove as part of switch to @huviz.picked_set
        
  reset_editor: ->
    @disengage_all_verbs()
    @deselect_all_node_classes()
    @init_editor_data()
    @clear_like()
    @update_command()

  add_clear_both: (target) ->
    # keep taxonomydiv from being to the right of the verbdiv
    target.append('div').attr('style','clear:both') 

  title_bar_controls: ->
    @show_comdiv_button = d3.select(@container).
         append('div').classed('show_comdiv_button',true)
    #@show_comdiv_button.text('oink')
    @show_comdiv_button.classed('display_none',true)
    #@comdiv.classed('display_none',true)
    @cmdlistbar = @cmdlist.append('div').attr('class','cmdlistbar')
    @cmdlist.append('div').attr('style','clear:both')    
    @cmdlistbarcontent = @cmdlistbar.append('div').
         attr('class','cmdlisttitlebarcontent')
    @cmdlistbarcontent.append('div').attr('class','cmdlisttitle')
    @toggle_comdiv_button = @cmdlistbar.append('div').
        attr('class','hide_comdiv')
    @toggle_history_button = @cmdlistbar.append('div').
        attr('class','hide_history')
    @clear_history_button = @cmdlistbar.append('div').
        attr('class','clear_history')
    @cmdlist.append('div').style('clear:both')

    @toggle_history_button.on 'click', () =>
      shown = not @toggle_history_button.classed('hide_history')
      @toggle_history_button.classed('hide_history',shown)
      @toggle_history_button.classed('show_history',not shown)
      @oldcommands.classed('display_none',not shown)

    @clear_history_button.on 'click', () =>
      @oldcommands.html("")

    @show_comdiv_button.on 'click', () =>
      @show_comdiv_button.classed('display_none',true)
      @comdiv.classed('display_none',false)
      
    @toggle_comdiv_button.on 'click', () =>
      shown = not @toggle_comdiv_button.classed('hide_comdiv')
      "setting toggle_comdiv:"+shown
      #@toggle_comdiv_button.classed('hide_comdiv',shown)
      #@toggle_comdiv_button.classed('show_comdiv',not shown)
      @comdiv.classed('display_none',not shown)
      @show_comdiv_button.classed('display_none',false)
      
    @toggle_commands_button = @cmdlistbar.append('div').
        attr('class','close_commands')

  ignore_predicate: (pred_id) ->
    @predicates_ignored.push(pred_id)

  handle_newpredicate: (e) =>
    parent = 'anything'
    pred_id = e.detail.sid
    unless pred_id in @predicates_ignored
      #pred_name = pred_id
      pred_name = pred_id.match(/([\w\d\_\-]+)$/g)[0]
      @add_newpredicate(pred_id,parent,pred_name)

  build_predicatepicker: ->
    id = 'predicates'
    @predicatebox = @comdiv.append('div').classed('container',true).attr('id',id)
    @predicatebox.attr('class','scrolling')
    @predicates_ignored = []
    @predicate_picker = new ColoredTreePicker(@predicatebox,'anything')
    @predicate_hierarchy = {'anything':['Anything']}
    @predicate_picker.show_tree(@predicate_hierarchy,@predicatebox,@onpredicateclicked)

  add_newpredicate: (pred_id,parent,pred_name) =>
    @predicate_picker.add(pred_id,parent,pred_name,@onpredicateclicked)

  onpredicateclicked: (pred_id,selected,elem) =>
    @predicate_picker.color_by_selected(pred_id,selected)
    if selected
      verb = 'show'
    else
      verb = 'suppress'
    #console.clear()
    cmd = new gcl.GraphCommand
      verbs: [verb]
      regarding: [pred_id]
      sets: [@huviz.picked_set]
      
    @prepare_command cmd
    @huviz.gclc.run(@command)

  recolor_nodes: =>
    # The nodes needing recoloring are all but the embryonic.
    for node in @huviz.nodes
      node.color = @huviz.color_by_type(node)

  recolor_edges: (evt) =>
    count = 0
    for node in @huviz.nodes
      for edge in node.links_from
        count++
        pred_n_js_id = edge.predicate.id
        edge.color = @predicate_picker.get_color_forId_byName(pred_n_js_id,'showing')

  build_nodeclasspicker: ->
    id = 'classes'
    @nodeclassbox = @comdiv.append('div').classed('container',true).attr('id',id)
    @node_class_picker = new ColoredTreePicker(@nodeclassbox,'everything')
    @node_class_picker.show_tree(@hierarchy,@nodeclassbox,@onnodeclasspicked)

  add_newnodeclass: (class_id,parent,class_name) =>
    @node_class_picker.add(class_id,parent,class_name,@onnodeclasspicked)
    @recolor_nodes()

  onnodeclasspicked: (id,selected,elem) =>
    # Mixed —> On
    # On —> Off
    # Off —> On
    # When we pick "everything" we mean:
    #    all nodes except the embryonic and the discarded
    #    OR rather, the hidden, the graphed and the unlinked
    console.log("onnodeclasspicked('" + id + ", " + selected + "')")
    @node_class_picker.color_by_selected(id,selected)
    if selected
      if not (id in @node_classes_chosen)
        @node_classes_chosen.push(id)
      # PICK all members of the currently chosen classes
      cmd = new gcl.GraphCommand
        verbs: ['pick']
        classes: (class_name for class_name in @node_classes_chosen)
      @huviz.gclc.run(cmd)
    else
      @deselect_node_class(id)
      # UNPICK
      cmd = new gcl.GraphCommand
        verbs: ['unpick']
        classes: [id]
      @huviz.gclc.run(cmd)
      
    @update_command()
    # ////////////////////////////////////////
    # FIXME this is just for testing
    # @predicate_picker.set_branch_mixedness('anything',true)
    # ////////////////////////////////////////

  deselect_node_class: (node_class) ->
    @node_classes_chosen = @node_classes_chosen.filter (eye_dee) ->
      eye_dee isnt node_class

  XXX_toggle_picked: (subject) => # FIXME rename subject to node
    if not (subject in @subjects)
      adding = true
      @subjects.push(subject)
      subject.color = @node_class_picker.get_color_forId_byName(subject.type,'emphasizing')
    else
      subject.color = @node_class_picker.get_color_forId_byName(subject.type,'showing')
      adding = false
      @subjects = @subjects.filter (member) ->
        subject isnt member
    @update_predicate_visibility(adding, subject)
    @update_command()

  update_class_picker: (node, picked) =>
    # Maintain the nodeclass picker
    # 
    # # Elements may be in one of these states:
    #   hidden     - TBD: not sure when hidden is appropriate
    #   notshowing - a light color indicating nothing of that type is picked
    #   showing    - a medium color indicating all things of that type are picked
    #   emphasized - mark the class of the focused_node
    #   mixed      - some instances of the node class are picked, but not all
    #   abstract   - the element represents an abstract superclass, presumably containing concrete node classes

    node.color = @node_class_picker.get_color_forId_byName(node.type, picked and 'emphasizing' or 'showing')
    if not node.color
      console.error "update_node_visibility", adding, node.name,"==> a null node.color"

    @node_class_picker
    classes_newly_identified_as_having_all_nodes = []
    classes_newly_identified_as_having_no_nodes = []
    classes_newly_identified_as_having_some_nodes = []
    classes_newly_identified_as_having_neither = []

  add_shown: (pred_id, edge) =>
    #alert "add_shown(" + pred_id + ", " + edge.id + ")"
    # This edge is shown, so the associated predicate has at least one shown edge.
    console.log "  adding shown",pred_id, edge.context.id
    if not @shown_edges_by_predicate[pred_id]?
      console.log("shown_edges_by_predicate[" + pred_id + "]")
      @shown_edges_by_predicate[pred_id] = []
      # this predicate is newly identified as being shown
      @predicates_newly_identified_as_having_shown_edges.push(edge.predicate)
      console.log("SET shown_edge_count: " + pred_id + " " + @predicates_newly_identified_as_having_shown_edges.length)
    @shown_edges_by_predicate[pred_id].push(edge)

  remove_shown: (pred_id, edge) =>
    # The node with this edge is being removed from consideration so the
    # predicate used by this edge has one fewer (or now possibly no) uses.
    console.log "  removing shown",pred_id      
    if @shown_edges_by_predicate[pred_id]?
      @shown_edges_by_predicate[pred_id] = @shown_edges_by_predicate[pred_id].filter (member) ->
        edge isnt member
      if not @shown_edges_by_predicate[pred_id].length
        delete @shown_edges_by_predicate[pred_id]
        @predicates_newly_identified_as_having_neither.push(edge.predicate)
          
  add_unshown: (pred_id, edge) =>
    # This edge is not shown, so the associated predicate has at least one unshown edge
    console.log "  adding unshown",pred_id
    if not @unshown_edges_by_predicate[pred_id]?
      @unshown_edges_by_predicate[pred_id] = []
      @predicates_newly_identified_as_having_unshown_edges.push(edge.predicate)
    @unshown_edges_by_predicate[pred_id].push(edge)

  remove_unshown: (pred_id, edge) =>
    # The node with this edge is being removed from consideration so the predicate
    # associated with this edge has one fewer (or now possibly no) uses.
    console.log "  removing unshown",pred_id
    if @unshown_edges_by_predicate[pred_id]?
      @unshown_edges_by_predicate[pred_id] = @unshown_edges_by_predicate[pred_id].filter (member) ->
        edge isnt member
      if not @unshown_edges_by_predicate[pred_id].length
        delete @unshown_edges_by_predicate[pred_id]
        if not @shown_edges_by_predicate[pred_id]?
          @predicates_newly_identified_as_having_neither.push(edge.predicate)

  update_pickers: (node, picked, shown) =>
    # There appear to be two considerations:
    #   has the picked-ness of the node changed?
    #   has the shown-ness of any edges changed?
    # If pick or unpick then both treepickers could be affected
    # If show or unshow (edges) then only the pred-picker will be affected
    # Should all huviz effectors call update_visibility as their point of entry?
    #   with a list (max length, pair) of changes, eg: (node, ['picked','unshow'])
    #   or with two tristate args (node, pick, show) YES
    if picked isnt null
      # changes in edge shown-ness to the node-picker
      @update_class_picker(node, picked) 
    @update_predicate_picker(node, picked, shown)
    @update_command()
    #@huviz.force.start()
    #alert "update_visibility() " + node.name

  init_indices: ->
    @predicates_newly_identified_as_having_shown_edges = []    
    @predicates_newly_identified_as_having_unshown_edges = []
    @predicates_newly_identified_as_having_some = []
    @predicates_newly_identified_as_having_neither = []

  update_predicate_picker: (node, picked, shown) =>
    return # see the event listener onChangePredicate
    # This method translates from operations in the node and edge frame
    # of reference to the predicate frame of reference.
    # 
    # The purpose of this method is to perform maintenance operations
    # on the predicate picker after external actions have altered the
    # picked_set (adding or removing nodes) or have altered the shown
    # or unshown status of the edges associated with the nodes in the
    # picked_set.
    #
    #                     |  picked  | not picked | picked is null
    #    -----------------+---------------+----------------
    #    edge.shown       | add_shown()   | remove_shown()
    #    -----------------+---------------+----------------
    #    not edge.shown   |               |
    #
    #    Where add_shown means
    #     "an instance of edge which representing some predicate
    #      where that edge is showing has been added to the picked set"
    # 
    # 
    # removed nodes from the picked_set or 
    # Maintain per-predicate lists of shown and unshown edges
    # and the list of predicates which have predicates of either
    # kind among the set of nodes which are the current subject set.
    # This collection of data is used to determine the state of
    # the elements in the predicate_picker, wrt the current @picked_set:
    #  * hidden for those predicates with no edges
    #  * showing-colored for those with edges showing
    #  * notshowing-colored for those with edges but none showing
    #  * more-styled for those with some edges showing and some not

    # Glossary:
    #   'adding' a subject means that all its predicates will become visible in the colorpicker
    #   'removing' is the opposite of adding: all 
    #   'shown' means 
    #   'unshown' means 

    # Elements may be in one of these states:
    #   hidden     - the predicate is not used at all by the current node selection
    #   notshowing - that predicate is used by selected nodes but no such edges are currently shown
    #   showing    - that predicate is used by selected nodes and all such edges are currently shown
    #   emphasized - varies in meaning, but used to hilight, say, the focused node
    #   mixed      - the predicate is used by selected nodes and some edges are showing but not all
    #   abstract   - the element in the tree is not a predicate but is an abstract superclass of some

    adding = picked  # FIXME refactor away from adding/removing??
    if @huviz.LOGGING?
      alert "update_predicate_visibility() " + adding + " node.id:" + node.id
    uri_to_js_id = @predicate_picker.uri_to_js_id
    #console.clear()
    # alert "update_predicate_visibility()"
    console.log "update_predicate_visibility()"
    console.log "adding:",adding,"id:",node.id,"name:",node.name
    
    consider_edge_significance = (edge, i) =>
      # FIXME perhaps we should exclude edges where edge.subject isnt subject
      #if edge.subject isnt subject
      #  # Consider only those edge which eminate from the subject.
      #  # Doing this means that only the writers in the Orlando data
      #  # will be respected for consideration
      #  return
         
      # To discover which predicates are available but not yet displayed
      # we must find those links_from which are not links_shown

      pred_id = uri_to_js_id(edge.predicate.id)
      msg = "consider_edge_significance() adding:" + adding + " edge:" +edge.id + " i:" + i      
      console.log msg
      if edge.shown?
        console.error "edge.shown? is true",edge
      if adding # ie the edge is being added to the graph
        #console.log '  adding'
        if edge.shown?
          #console.log '    edge.shown'
          eg = "User picked a graphed node (or graphed a picked node?)"
          @add_shown(pred_id, edge)
        else
          #console.log '    not edge.shown'
          eg = "User picked a node on the shelf (or shelved a picked node?)"
          @add_unshown(pred_id, edge)
      else # the edge has been removed from the graph
        #console.error 'removing from graph:',edge.id
        if edge.shown?
          console.debug '    edge.shown'
          eg = "User unpicked a now graphed node."
          @remove_shown(pred_id, edge)
        else
          eg = "User unpicked a now ungraphed node."
          @remove_unshown(pred_id, edge)

      # update predicates_to_newly_{hide,show}
      console.debug eg,edge

    # Consider all the edges for which node is subject or the object
    REVERSEDLY = false # this can be destructive, so go backwards
    if REVERSEDLY
      for i in [node.links_from.length-1..0] by -1
        consider_edge_significance(node.links_from[i],i)
      for i in [node.links_to.length-1..0] by -1
        consider_edge_significance(node.links_to[i],i)
    else
      node.links_to.forEach consider_edge_significance   # node is the object
      node.links_from.forEach consider_edge_significance # node is the subject

    console.log "newly shown: to be picked ============"
    console.log "GET shown_edge_count: " + @predicates_newly_identified_as_having_shown_edges.length
    @predicates_newly_identified_as_having_shown_edges.forEach (predicate, i) =>
      console.log(predicate + " newly identified as having shown edges")
      pred_js_id = uri_to_js_id(predicate.id)
      #pred_js_id = predicate.id
      console.debug " ",pred_js_id, "newly showing"
      unshown_idx = @predicates_newly_identified_as_having_unshown_edges.indexOf(predicate)
      if unshown_idx > -1
        @predicates_newly_identified_as_having_unshown_edges.splice(unshown_idx)
        # We could remove this predicate from ...having_shown_edges but will not bother
        # because that list will not be used again
        @predicates_newly_identified_as_having_some.push(predicate)
        return
      @predicate_picker.set_branch_hiddenness(pred_js_id, false)
      #@predicate_picker.color_by_selected(pred_js_id, true)
      @predicate_picker.set_branch_pickedness(pred_js_id, true)

    console.log "newly unshown: to be unpicked ============ ============"
    @predicates_newly_identified_as_having_unshown_edges.forEach (predicate, i) =>
      # no need to compare with ...having_shown_edges because that is done above
      pred_js_id = uri_to_js_id(predicate.id)
      console.debug " ",pred_js_id, "unshowing"
      @predicate_picker.set_branch_hiddenness(pred_js_id, false)
      @predicate_picker.set_branch_pickedness(predicate.id, false)

    console.log "newly both AKA mixed: to be marked mixed ============ ============ ============"
    @predicates_newly_identified_as_having_some.forEach  (predicate, i) =>
      pred_js_id = uri_to_js_id(predicate.id)
      console.debug " ",pred_js_id,"mixed"
      @predicate_picker.set_branch_hiddenness(pred_js_id, false)
      @predicate_picker.set_branch_mixedness(predicate.id,true)

    console.log "newly neither: to be hidden ============ ============ ============ ============"
    @predicates_newly_identified_as_having_neither.forEach (predicate, i) =>
      pred_js_id = uri_to_js_id(predicate.id)
      console.debug " ",pred_js_id,"hiding"
      @predicate_picker.set_branch_hiddenness(pred_js_id, true)

    console.log "RESET shown_edge_count: []", "adding:",adding,"id:",node.id,"name:",node.name
    @init_indices()

    predicates_to_newly_hide = []
    predicates_to_newly_show = []
    

  verb_sets: [ # mutually exclusive within each set
      choose: 'choose'
      shelve: 'shelve'
      hide:   'hide'
    ,
      label:   'label'
      unlabel: 'unlabel'
    ,
      discard: 'discard'
      undiscard: 'retrieve'
    ,
      print: 'print'
      redact: 'redact'
    ,
      show: 'reveal'
      suppress: 'suppress'
      specify: 'specify'
      #emphasize: 'emphasize'
    ]

  verbs_requiring_regarding:
    ['show','suppress','emphasize','deemphasize']
    
  verbs_override: # when overriding ones are selected, others are deselected
    choose: ['discard','unchoose']
    discard: ['choose','retrieve','hide']
    hide: ['discard','undiscard','label']

  verb_descriptions:
    choose: "Put nodes in the graph."
    shelve: "Remove nodes from the graph and put them on the shelf
             (the circle of nodes around the graph) from which they
             might return if called back into the graph by "
    hide: "Remove nodes from the grpah and don't display them anywhere,
           though they might be called back into the graph when some
           other node calls it back in to show an edge."
    label: "Show the node's labels."
    unlabel: "Stop showing the node's labels."
    discard: "Put nodes in the discard bin (the small red circle) from
              which they do not get called back into the graph unless
              they are retrieved."
    undiscard: "Retrieve nodes from the discard bin (the small red circle)
                and put them back on the shelf."
    print: "Print associated snippets."
    redact: "Hide the associated snippets."
    show: "Show edges: 'Show (nodes) regarding (edges).'
           Add to the existing state of the graph edges from nodes of
           the classes indicated edges of the types indicated."
    suppress: "Stop showing: 'Suppress (nodes) regarding (edges).'
               Remove from the existing sate of the graph edges of the types
               indicated from nodes of the types classes indicated."
    specify: "Immediately specify the entire state of the graph with
              the constantly updating set of edges indicated from nodes
              of the classes indicated."
    load: "Load knowledge from the given uri."

  build_form: () ->
    @build_verb_form()
    @build_like()
    @nextcommand = @nextcommandbox.append('div').
        attr('class','nextcommand command')
    @nextcommandstr = @nextcommand.append('span')
    @build_submit()        
  build_like: () ->
    @likediv.text('like:')
    @like_input = @likediv.append('input')
    @like_input.on 'input',@update_command
  build_submit: () ->
    @doit_butt = @nextcommand.append('span').append("input").
           attr("style","float:right").
           attr("type","submit").
           attr('value','Do it')
    @doit_butt.on 'click', () =>
      if @update_command()
        @huviz.gclc.run(@command)
        @push_command(@command)
        @reset_editor()
  disengage_all_verbs: ->
    for vid in @engaged_verbs
      @disengage_verb(vid)
  deselect_all_node_classes: ->
    for nid in @node_classes_chosen
      @deselect_node_class(nid)
      @node_class_picker.set_branch_pickedness(nid,false)
  clear_like: ->
    @like_input[0][0].value = ""
  old_commands: []
  push_command: (cmd) ->
    if @old_commands.length > 0
      prior = @old_commands[@old_commands.length-1]
      if prior.cmd.str is cmd.str
        return  # same as last command, ignore
    cmd_ui = @oldcommands.append('div').attr('class','command')
    record =
      elem: cmd_ui
      cmd: cmd
    @old_commands.push(record)
    cmd_ui.text(cmd.str)
  build_command: ->
    args = {}
    # if @subjects.length > 0
    #   args.subjects = (s for s in @subjects)
    if @huviz.picked_set.length > 0      
      args.subjects = (s for s in @huviz.picked_set)
    if @engaged_verbs.length > 0
      args.verbs = (v for v in @engaged_verbs)
    if @node_classes_chosen.length > 0
      args.classes = (class_name for class_name in @node_classes_chosen)
    like_str = (@like_input[0][0].value or "").trim()
    if like_str
      args.like = like_str
    @command = new gcl.GraphCommand(args)
  update_command: () =>
    @prepare_command @build_command()
  prepare_command: (cmd) ->
    @command = cmd
    @nextcommandstr.text(@command.str)
    if @command.ready
      @doit_butt.attr('disabled',null)
    else
      @doit_butt.attr('disabled','disabled')
    return @command.ready
  build_verb_form: () ->
    for vset in @verb_sets
      alternatives = @verbdiv.append('div').attr('class','alternates')
      for id,label of vset
        @append_verb_control(id,label,alternatives)
  get_verbs_overridden_by: (verb_id) ->
    override = @verbs_override[verb_id] || []
    for vset in @verb_sets
      if vset[verb_id]
        for vid,label of vset
          if not (vid in override) and verb_id isnt vid
            override.push(vid)
    return override
  engaged_verbs: []
  engage_verb: (verb_id) ->
    overrides = @get_verbs_overridden_by(verb_id)
    for vid in @engaged_verbs
      if vid in overrides
        @disengage_verb(vid)
    if not (verb_id in @engaged_verbs)
      @engaged_verbs.push(verb_id)
  disengage_verb: (verb_id) ->
    @engaged_verbs = @engaged_verbs.filter (verb) -> verb isnt verb_id
    @verb_control[verb_id].classed('engaged',false)
  verb_control: {}
  append_verb_control: (id,label,alternatives) ->
    vbctl = alternatives.append('div').attr("class","verb")
    if @verb_descriptions[id]
      vbctl.attr("title",@verb_descriptions[id])
    @verb_control[id] = vbctl
    vbctl.text(label)
    that = @
    vbctl.on 'click', () ->
      elem = d3.select(this)
      newstate = not elem.classed('engaged')
      elem.classed('engaged',newstate)
      if newstate
        that.engage_verb(id)
      else
        that.disengage_verb(id)
      that.update_command()    
  run_script: (script) ->
    @huviz.gclc.run(script)
    
(exports ? this).CommandController = CommandController
