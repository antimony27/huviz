TaxonBase = require('taxonbase').TaxonBase

class TaxonAbstract extends TaxonBase
  # These are containers for Taxons or Predicates.  There is a tree structure
  # of AbstractTaxons and Taxons and Predicates comprise the leaves.
  # seq message   meaning     styling
  #   0 hidden    noneToShow  hidden/nocolor
  #   1 unshowing noneShowing lowcolor
  #   2 mixed     someShowing stripey
  #   3 showing   allShowing  medcolor
  #   4 selected  emphasized  hicolor
  constructor: (@id) ->
    super()
    @kids = SortedSet().sort_on("id").named(@id).isState("_mom")
  register: (kid) ->
    kid.mom = this
    @addSub(kid)
  addSub: (kid) ->
    @kids.add(kid)
  get_instances: () ->
    retval = []
    for kid in @kids
      for i in kid.get_instances()
        retval.push(i)
    return retval
  recalc_state: () ->
    summary =
      showing: false
      hidden: false
      unshowing: false
      mixed: false
    different_states = 0
    for k in @kids
      if typeof k.get_state() is 'undefined'
        console.debug k
      if not summary[k.state]
        summary[k.state] = true
        different_states++
    if different_states > 1  # no consensus
      @state = 'mixed'
    else  # return consensus
      for k,v of summary
        if v
          @state = k
          break
    return @state
  recalc_english: (in_and_out) ->
    if @state is 'showing'
      # ie this level contributes no detail
      in_and_out.include.push @id
    else if @state is "unshowing"
      # twiddle thumbs violently
      # what goes here?     
    else if @state is "mixed"
      for kid in @kids
        kid.recalc_english(in_and_out)
    
(exports ? this).TaxonAbstract = TaxonAbstract