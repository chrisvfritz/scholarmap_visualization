window.ScholarMapViz = {}

class ScholarMapViz.Map

  constructor: ->
    @draw()

  # draws the map
  draw: ->
    ScholarMapViz.$container.html ''
    @initialize_drawing_area()
    @set_colors()
    @initialize_force_layout()
    @initialize_tooltips()
    ScholarMapViz.$container.fadeOut 0
    @get_data()

  # sets up the SVG to fill its container
  initialize_drawing_area: ->
    @width  = ScholarMapViz.$container.outerWidth()
    @height = ScholarMapViz.$window.height()

    @svg = d3.select(ScholarMapViz.container).append 'svg'
      .attr 'width',  @width
      .attr 'height', @height

  # https://github.com/mbostock/d3/wiki/Ordinal-Scales#categorical-colors
  set_colors: ->
    @color = d3.scale.category10();

  # https://github.com/mbostock/d3/wiki/Force-Layout
  initialize_force_layout: ->
    @force = d3.layout.force()
      .size [@width, @height]
      .linkDistance (d) =>
        base     = 150
        grouping = if @group_by(d.source) == @group_by(d.target) then 40 else 0
        weight   = @link_weight(d) * 10
        base - grouping - weight
      .linkStrength (d) =>
        if @group_by(d.source) == @group_by(d.target) then 1 else .05
      .charge (d) =>
        -2 ** d.weight
      .gravity 0.02

  # https://github.com/Caged/d3-tip/blob/master/docs/index.md#d3tip-api-documetation
  initialize_tooltips: ->
    @node_tip = d3.tip()
      .attr 'class', 'd3-tip'
      .offset [-10, 0]
      .html @node_tip_html

    @link_tip = d3.tip()
      .attr 'class', 'd3-tip'
      .offset -> [@.getBBox().height / 2 - 5, 0]
      .html @link_tip_html

    @svg.call @node_tip
    @svg.call @link_tip

  get_data: ->

    # fetch data of the appropriate type from the API
    d3.json "/api/v1/#{@type}/graphs/force-directed.json?#{window.location.search.substring(1)}", (error, graph) =>

      ScholarMapViz.$container.fadeIn 500

      @graph = graph

      # sets up the force layout with our API data
      @force
        .nodes @graph.nodes
        .links @graph.links
        .start()

      # sets up link hover area, with a minimum stroke-width
      hover_link = @svg.selectAll '.hover-link'
        .data @graph.links
        .enter().append 'line'
          .attr 'class', 'hover-link'
          .style 'stroke-width', (d) => d3.max [ 15, @link_width(d) ]

      # sets up link styles
      visible_link = @svg.selectAll '.visible-link'
        .data @graph.links
        .enter().append 'line'
          .attr 'class', 'visible-link'
          .style 'stroke-width', @link_width

      # sets up node background, so that transparency doesn't reveal link tips
      node_background = @svg.selectAll '.node-background'
        .data @graph.nodes
        .enter().append 'circle'
          .attr 'class', 'node-background'
          .attr 'r', @node_size

      # sets up node style and behavior
      node = @svg.selectAll '.node'
        .data @graph.nodes
        .enter().append 'circle'
          .attr 'class', 'node'
          .attr 'r', @node_size
          .style 'fill', (d) => @color @group_by(d)
          .on 'mouseover', @node_tip.show
          .on 'mouseout',  @node_tip.hide
          .call @force.drag

      # groups nodes by the group_by function
      groups = d3.nest()
        .key @group_by
        .entries @graph.nodes

      # removes any groups with only a one or two nodes
      groups = groups.filter (group) ->
        group.values.length > 2

      # calculates dimensions of hulls surrounding node groups
      group_path = (d) ->
        "M#{ d3.geom.hull( d.values.map (i) -> [i.x, i.y] ).join('L') }Z"

      # colors groups by their key
      group_fill = (d) => @color d.key

      # sets a state-SOMETHING class on visible link
      set_link_status = (d, status) ->
        # get the visible-link of the currently hovered hover-link
        $active_link = $(".visible-link[data-id='#{d.source.index}->#{d.target.index}']")
        # remove any existing state classes
        $active_link.attr 'class', $active_link.attr('class').replace(/(^|\s)state-\S+/g, '')
        # add a new state class
        $active_link.attr 'class', $active_link.attr('class') + " state-#{status}"

      # constantly redraws the graph, with the following items
      @force.on 'tick', (e) =>

        node_binding_x = (d) =>
          Math.max @node_size(d), Math.min(@width -  @node_size(d), d.x)

        node_binding_y = (d) =>
          Math.max @node_size(d), Math.min(@height - @node_size(d), d.y)

        # the hulls surrounding node groups
        @svg.selectAll 'path'
          .data groups
          .attr 'd', group_path
          .enter().insert 'path', 'circle'
            .attr 'class', 'node-group'
            .style 'fill', group_fill
            .style 'stroke', group_fill
            .style 'stroke-width', (d) =>
              d3.max d.values.map( (p) => @node_size(p) * 2 + 20 )
            .attr 'd', group_path

        # the hover areas around links to show tooltips
        hover_link
          .attr 'x1', (d) -> node_binding_x d.source
          .attr 'y1', (d) -> node_binding_y d.source
          .attr 'x2', (d) -> node_binding_x d.target
          .attr 'y2', (d) -> node_binding_y d.target
          .on 'mouseover', @link_tip.show
          .on 'mouseenter', (d) ->
             set_link_status d, 'active'
          .on 'mouseout', (d) =>
            @link_tip.hide()
            set_link_status d, 'inactive'

        # the links that users see between nodes
        visible_link
          .attr 'x1', (d) -> node_binding_x d.source
          .attr 'y1', (d) -> node_binding_y d.source
          .attr 'x2', (d) -> node_binding_x d.target
          .attr 'y2', (d) -> node_binding_y d.target
          .attr 'data-id', (d) -> "#{d.source.index}->#{d.target.index}"

        # the background of nodes (so that transparency doesn't reveal link tips)
        node_background
          .attr 'cx', (d) -> d.x
          .attr 'cy', (d) -> d.y

        # the nodes
        node
          .attr 'cx', node_binding_x
          .attr 'cy', node_binding_y

  # calculates communities with the Louvain algorithm
  louvain_communities: ->
    louvain_nodes = [0..@graph.nodes.length]
    louvain_edges = @graph.links.map (link) =>
      source: link.source.index,
      target: link.target.index,
      weight: @link_weight(link)
    communities = jLouvain().nodes(louvain_nodes).edges(louvain_edges)()
    @louvain_communities = -> communities

  # groups by Louvain communities
  group_by: (d) =>
    @louvain_communities()[d.index]

  # returns all original node attributes (not including generated attributes)
  node_attributes: (nodes) ->
    attributes = []
    for key of nodes[0]
      return attributes if key == 'index'
      attributes.push key

  # link tooltips list node similarities by type
  link_tip_html: (d) ->
    d.similarities.filter (similarity) ->
      similarity.list.length > 0
    .map (similarity) ->
      "<span class=\"d3-tip-label\">#{similarity.type}:</span> #{similarity.list.join(', ')}"
    .join '<br>'

  # link weight is determined by number of similarities between nodes
  link_weight: (d) ->
    d.similarities.map (similarity) ->
      similarity.list.length
    .reduce (a, b) ->
      a + b

  # link width is a modified log of the calculated link weight
  link_width: (d) =>
    Math.log( d3.max([2, @link_weight(d)]) ) * 5

class ScholarMapViz.PeopleMap extends ScholarMapViz.Map

  constructor: ->
    @type = 'people'
    super

  # node tooltips should display people's name
  node_tip_html: (d) ->
    d.name

  # constant node size of 20
  node_size: (d) ->
    5


class ScholarMapViz.ReferencesMap extends ScholarMapViz.Map

  constructor: ->
    @type = 'references'
    super

  # node tooltips shuold display the reference citation, cutting it off it it's longer than 150 characters
  node_tip_html: (d) ->
    d.citation

  # node size depends on the number of authors for the reference
  node_size: (d) ->
    d3.max [10, Math.log( d.authors.length + 1 ) * 10]


class ScholarMapViz.CharacteristicsMap extends ScholarMapViz.Map

  constructor: ->
    @type = 'characteristics'
    super

  # node tooltips shuold display the reference citation, cutting it off it it's longer than 150 characters
  node_tip_html: (d) ->
    d.name

  # node size depends on the number of authors for the reference
  node_size: (d) ->
    10


class ScholarMapViz.DataToggle

  constructor:  ->
    $('#people-button').on 'click', ->
      choose_data $(@), -> new ScholarMapViz.PeopleMap
    $('#references-button').on 'click', ->
      choose_data $(@), -> new ScholarMapViz.ReferencesMap
    $('#characteristics-button').on 'click', ->
      choose_data $(@), -> new ScholarMapViz.CharacteristicsMap

  choose_data = ($current, activation_callback) ->
    unless $current.hasClass 'active'
      $current.siblings().removeClass 'active'
      $current.addClass 'active'
      activation_callback()


class ScholarMapViz.Initializer

  constructor: ->
    @setup()
    @fetch_default_data()
    new ScholarMapViz.DataToggle

  setup: ->
    ScholarMapViz.$window = $(window)

    ScholarMapViz.container  = '#visualization'
    ScholarMapViz.$container = $(ScholarMapViz.container)

  fetch_default_data: ->
    new ScholarMapViz.PeopleMap
    $('#people-button').addClass 'active'


$ ->

  new ScholarMapViz.Initializer
