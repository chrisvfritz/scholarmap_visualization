window.ScholarMapViz = {}

class ScholarMapViz.Map

  similarity_types = undefined
  node_tip_html    = undefined
  data_type        = undefined
  constructor: ->
    similarity_types = @similarity_types
    node_tip_html    = @node_tip_html
    data_type        = @type
    @draw()

  # draws the map
  draw: ->
    ScholarMapViz.$container.html ''
    $('.loader').addClass 'loading'
    initialize_drawing_area()
    set_colors()
    initialize_force_layout()
    initialize_tooltips()
    ScholarMapViz.$container.fadeOut 0
    @get_data()

  # sets up the SVG to fill its container
  width  = undefined
  height = undefined
  svg    = undefined
  initialize_drawing_area = ->
    width  = ScholarMapViz.$container.outerWidth()
    height = ScholarMapViz.$window.height()

    svg = d3.select(ScholarMapViz.container).append 'svg'
      .attr 'width',  width
      .attr 'height', height

  # https://github.com/mbostock/d3/wiki/Ordinal-Scales#categorical-colors
  color = undefined
  set_colors = ->
    color = d3.scale.category10();

  # https://github.com/mbostock/d3/wiki/Force-Layout
  force = undefined
  initialize_force_layout = ->
    force = d3.layout.force()
      .size [width, height]
      .linkDistance 50
        # base     = 150
        # grouping = if @group_by(d.source) == @group_by(d.target) then 40 else 0
        # weight   = @link_weight(d) * 10
        # base - grouping - weight
      .linkStrength (d) ->
        if group_by(d.source) == group_by(d.target) then 0.05 else .01
      .charge (d) ->
        # -9 * @node_size(d)
        -200
      .gravity 0.03

  # https://github.com/Caged/d3-tip/blob/master/docs/index.md#d3tip-api-documetation
  node_tip = undefined
  link_tip = undefined
  initialize_tooltips = ->

    node_tip_direction = (override_this) ->
      element = if override_this instanceof SVGCircleElement then override_this else @
      coords = d3.mouse(element)
      upper = coords[1] < (0.5 * height)
      left  = coords[0] < (0.25 * width)
      right = coords[0] > (0.75 * width)
      return 'se' if upper && left
      return 'sw' if upper && right
      return 's'  if upper
      return 'nw' if right
      return 'ne' if left
      return 'n'

    node_tip_offset = ->
      direction = node_tip_direction(@)
      return [-10, 0]  if direction == 'n' || direction == 'nw' || direction == 'ne'
      return [10,  0]  if direction == 's' || direction == 'sw' || direction == 'se'

    node_tip = d3.tip()
      .attr 'class', 'd3-tip'
      .direction node_tip_direction
      .offset node_tip_offset
      .html node_tip_html

    link_tip = d3.tip()
      .attr 'class', 'd3-tip'
      .offset -> [@.getBBox().height / 2 - 5, 0]
      .html link_tip_html

    svg.call node_tip
    svg.call link_tip

  graph = undefined
  get_data: ->
    return bind_data() if graph
    # fetch data of the appropriate type from the API
    d3.json "http://somelab09.cci.fsu.edu:8080/scholarMap/api/v1/#{data_type}/graphs/force-directed?#{window.location.search.substring(1)}", (error, data) ->
      graph = data
      bind_data()

  bind_data = ->

    graph.links = generate_links graph.nodes

    draw_link_by_buttons graph.links

    # sets up the force layout with our API data
    force
      .nodes graph.nodes
      .links graph.links
      .start()

    setTimeout ->
      force.stop()
      # setTimeout(->
      #   node.fixed = true for node in @graph.nodes
      # , 100)
      $('.loader').removeClass 'loading'
      ScholarMapViz.$container.fadeIn 500
    , 3000

    # sets up link hover area, with a minimum stroke-width
    # hover_link = @svg.selectAll '.hover-link'
    #   .data @graph.links
    #   .enter().append 'line'
    #     .attr 'class', 'hover-link'
    #     .style 'stroke-width', (d) => d3.max [ 15, @link_width(d) ]
    #     .on 'mouseover', @link_tip.show
    #     .on 'mouseenter', (d) ->
    #       setTimeout (->
    #         set_link_status d, 'active'
    #       ), 1
    #     .on 'mouseout', (d) =>
    #       @link_tip.hide()
    #       set_link_status d, 'inactive'

    # sets up link styles
    visible_link = svg.selectAll '.visible-link'
      .data graph.links
      .enter().append 'line'
        .attr 'class', 'visible-link'
        .style 'stroke-width', 2 # @link_width
        .style 'opacity', link_opacity

    # sets up node background, so that transparency doesn't reveal link tips
    # node_background = @svg.selectAll '.node-background'
    #   .data @graph.nodes
    #   .enter().append 'circle'
    #     .attr 'class', 'node-background'
    #     .attr 'r', @node_size

    # sets up node style and behavior
    node = svg.selectAll '.node'
      .data graph.nodes
      .enter().append 'circle'
        .attr 'class', 'node'
        .attr 'r', node_size
        .style 'fill', (d) -> color group_by(d)
        .on 'mouseover', node_tip.show
        .on 'mouseenter', (d) ->
          setTimeout (->
            set_related_links_status d, 'active'
          ), 1
        .on 'click', (d) ->
          $('#node-title').html node_tip_html(d)
          $('#node-url').attr 'href', d.relative_url
          $node_attrs = $('#node-attrs').html ''
          for key of d
            continue if key in ['name', 'citation', 'relative_url']
            break    if key == 'index' or key in similarity_types()
            $node_attrs.append """
              <h4>#{key[0].toUpperCase() + key[1..-1]}</h4>
              <p>#{if typeof(d[key]) == 'object' then d[key].join(', ') else d[key]}</p>
            """
        .on 'mouseout', (d) ->
          node_tip.hide()
          set_related_links_status d, 'inactive'
        .call force.drag

    # prevents nodes from spilling out the sides of the draw area
    node_binding_x_cache = {}
    node_binding_x = (d) ->
      return node_binding_x_cache[d.x] if node_binding_x_cache[d.x]
      node_binding_x_cache[d.x] = Math.max node_size(d), Math.min(width - node_size(d), d.x)

    # prevents nodes from spilling out the top or bottom of the draw area
    node_binding_y_cache = {}
    node_binding_y = (d) ->
      return node_binding_y_cache[d.y] if node_binding_y_cache[d.y]
      node_binding_y_cache[d.y] = Math.max node_size(d), Math.min(height - node_size(d), d.y)

    # groups nodes by the group_by function
    groups = d3.nest()
      .key group_by
      .entries graph.nodes

    # removes any groups with only a one or two nodes
    groups = groups.filter (group) ->
      group.values.length > 2

    # calculates dimensions of hulls surrounding node groups
    group_path = (d) ->
      "M#{ d3.geom.hull( d.values.map (p) -> [node_binding_x(p), node_binding_y(p)] ).join 'L' }Z"

    # colors groups by their key
    group_fill = (d) -> color d.key

    # sets a state-SOMETHING class on visible link
    set_link_status = (d, status) ->
      # get the visible-link of the currently hovered hover-link
      $active_link = $(".visible-link[data-id='#{d.source.index}->#{d.target.index}']")
      # remove any existing state classes
      $active_link.attr 'class', $active_link.attr('class').replace(/(^|\s)state-\S+/g, '')
      # add a new state class
      $active_link.attr 'class', $active_link.attr('class') + " state-#{status}"

    # sets a state-SOMETHING class on visible links related to a node
    set_related_links_status = (d, status) ->
      connected_links = graph.links.filter (link) ->
        link.source.index == d.index || link.target.index == d.index
      if connected_links.length > 0
        for link in connected_links
          set_link_status link, status

    # constantly redraws the graph, with the following items
    force.on 'tick', (e) ->

      # the hulls surrounding node groups
      svg.selectAll 'path'
        .data groups
        .attr 'd', group_path
        .enter().insert 'path', 'circle'
          .attr 'class', 'node-group'
          .style 'fill', group_fill
          .style 'stroke', group_fill
          .style 'stroke-width', (d) ->
            d3.max d.values.map( (p) -> node_size(p) * 2 + 20 )
          .attr 'd', group_path

      # the hover areas around links to show tooltips
      # hover_link
      #   .attr 'x1', (d) -> node_binding_x d.source
      #   .attr 'y1', (d) -> node_binding_y d.source
      #   .attr 'x2', (d) -> node_binding_x d.target
      #   .attr 'y2', (d) -> node_binding_y d.target

      # the links that users see between nodes
      visible_link
        .attr 'x1', (d) -> node_binding_x d.source
        .attr 'y1', (d) -> node_binding_y d.source
        .attr 'x2', (d) -> node_binding_x d.target
        .attr 'y2', (d) -> node_binding_y d.target
        .attr 'data-id', (d) -> "#{d.source.index}->#{d.target.index}"

      # the background of nodes (so that transparency doesn't reveal link tips)
      # node_background
      #   .attr 'cx', node_binding_x
      #   .attr 'cy', node_binding_y

      # the nodes
      node
        .attr 'cx', node_binding_x
        .attr 'cy', node_binding_y

  # calculates communities with the Louvain algorithm
  louvain_communities = ->
    louvain_nodes = [0..graph.nodes.length]
    louvain_edges = graph.links.map (link) ->
      source: link.source.index,
      target: link.target.index,
      weight: link_weight(link)
    communities = jLouvain().nodes(louvain_nodes).edges(louvain_edges)()
    louvain_communities = -> communities

  # groups by Louvain communities
  group_by = (d) ->
    louvain_communities()[d.index]

  # sizes nodes by combined link weights
  node_size = (d) ->
    10

    # @node_size_cache = @node_size_cache || {}
    # return @node_size_cache[d.index] if @node_size_cache[d.index]

    # connected_links = @graph.links.filter (link) ->
    #   link.source.index == d.index || link.target.index == d.index

    # return 0 if connected_links.length == 0

    # calculated_node_size = connected_links.map (link) =>
    #   @link_weight(link)
    # .reduce (a, b) =>
    #   a + b

    # @node_size_cache[d.index] = d3.max [ Math.sqrt(calculated_node_size), 10 ]

  # returns all original node attributes (not including generated attributes)
  node_attributes = (nodes) ->
    attributes = []
    for key of nodes[0]
      return attributes if key == 'index'
      attributes.push key

  # link tooltips list node similarities by type
  link_tip_html = (d) ->
    d.similarities.map (similarity) ->
      type = similarity.type[0].toUpperCase() + similarity.type[1..-1]
      attribute_names = similarity.list.map (item) ->
        graph.attributes[similarity.type][item.id].name
      "<span class=\"d3-tip-label\">#{type}:</span> #{attribute_names.join(', ')}"
    .join '<br>'

  link_index = (d) ->
    "#{d.source.index}->#{d.target.index}"

  # link weight is determined by number of similarities between nodes
  link_weight_cache = {}
  link_weight = (d) ->
    return link_weight_cache[link_index(d)] if link_weight_cache[link_index(d)]

    weights = _.flatten d.similarities.map (similarity) ->
      similarity.list.map (item) ->
        item.weight
    total_weight = weights.reduce( (a, b) -> a + b )

    link_weight_cache[link_index(d)] = total_weight


  # link width is a modified log of the calculated link weight
  link_width = (d) ->
    Math.log( d3.max([2, link_weight(d)]) )# * 5

  link_opacity_cache = {}
  max_link_weight = undefined
  link_opacity = (d) ->
    link_opacity_cache = link_opacity_cache || {}
    return link_opacity_cache[link_index(d)] if link_opacity_cache[link_index(d)]

    max_link_weight = max_link_weight || d3.max( Object.keys(link_weight_cache).map (key) -> link_weight_cache[key] )
    calculated_weight = link_weight(d) / max_link_weight

    link_opacity_cache[link_index(d)] = calculated_weight

  node_tip_html: (d) ->
    d.name

  draw_link_by_buttons = (links) ->
    return if ScholarMapViz.$similarity_types.data('links-for') == @type

    ScholarMapViz.$similarity_types.css 'display', 'none'

    similarity_types = []
    for link in links
      for similarity in link.similarities
        similarity_types.push(similarity.type) unless similarity_types.indexOf(similarity.type) > -1

    ScholarMapViz.$similarity_types.html ''

    for type in similarity_types
      formatted_type = type[0].toUpperCase() + type[1..-1]
      ScholarMapViz.$similarity_types.data 'links-for', type
      ScholarMapViz.$similarity_types.append """
        <button class="btn btn-default btn-block active" data-similarity-type="#{type}">#{formatted_type}</button>
      """

    ScholarMapViz.$similarity_types.fadeIn 500

  generate_links = (nodes) ->
    links = nodes.map (node, index) ->
      nodes.slice(index+1, nodes.length).map (other_node) ->
        similarities = {}
        any_links = false
        for similarity_type in active_similarity_types()
          similarities[similarity_type] = if node[similarity_type] and other_node[similarity_type]
            if node[similarity_type] and typeof(node[similarity_type][0]) == 'object'
              node_attr_ids       =       node[similarity_type].map (similarity) -> similarity.id
              other_node_attr_ids = other_node[similarity_type].map (similarity) -> similarity.id
              similarities[similarity_type] = _.intersection(node_attr_ids, other_node_attr_ids).map (id) ->
                node_attr_weight       = _.find(       node[similarity_type], (item) -> item.id == id ).weight
                other_node_attr_weight = _.find( other_node[similarity_type], (item) -> item.id == id ).weight
                {
                  id: id
                  weight: (node_attr_weight + other_node_attr_weight) / 2
                }
            else
              node_attr_ids       =       node[similarity_type]
              other_node_attr_ids = other_node[similarity_type]
              similarities[similarity_type] = _.intersection(node_attr_ids, other_node_attr_ids).map (id) ->
                id: id
                weight: 50
          else
            []
          any_links = true if similarities[similarity_type].length > 0
        if any_links
          {
            source: nodes.indexOf node
            target: nodes.indexOf other_node
            similarities: active_similarity_types().map (similarity_type) ->
              {
                type: similarity_type
                list: similarities[similarity_type]
              }
            .filter (similarity) ->
              similarity.list.length > 0
          }
        else
          null

    _.compact _.flatten(links)

  similarity_exclusions = ->
    $.makeArray( ScholarMapViz.$similarity_types.find('button:not(.active)') ).map (type) ->
      $(type).data 'similarity-type'

  active_similarity_types = ->
    similarity_types().filter (type) ->
      similarity_exclusions().indexOf(type) < 0


class ScholarMapViz.PeopleMap extends ScholarMapViz.Map

  constructor: ->
    @type = 'people'
    super

  similarity_types: ->
    ['fields', 'methods', 'theories', 'venues', 'references']


class ScholarMapViz.ReferencesMap extends ScholarMapViz.Map

  constructor: ->
    @type = 'references'
    super

  similarity_types: ->
    ['fields', 'methods', 'theories', 'venues', 'people']

  # node tooltips should display the reference citation
  node_tip_html: (d) ->
    d.citation


class ScholarMapViz.CharacteristicsMap extends ScholarMapViz.Map

  constructor: ->
    @type = 'characteristics'
    super

  similarity_types: ->
    ['people', 'references']


class ScholarMapViz.DataToggle

  constructor:  ->
    $('#map-types').on 'click', 'button', ->
      $current_button = $(@)
      choose_data $current_button, ->
        ScholarMapViz.current_map = new ScholarMapViz[$current_button.data('map-type')]

  choose_data = ($current, activation_callback) ->
    unless $current.hasClass 'active'
      $current.siblings().removeClass 'active'
      $current.addClass 'active'
      ScholarMapViz.$similarity_types.html ''
      activation_callback()


class ScholarMapViz.LinkTypeToggles

  constructor: ->
    ScholarMapViz.$similarity_types.on 'click', 'button', ->
      unless ScholarMapViz.$similarity_types.find('button.active').length == 1 && $(@).hasClass('active')
        $(@).toggleClass 'active'
        ScholarMapViz.current_map.link_weight_cache = {}
        ScholarMapViz.current_map.draw()


class ScholarMapViz.Initializer

  constructor: ->
    @setup()
    @fetch_default_data()
    new ScholarMapViz.DataToggle
    new ScholarMapViz.LinkTypeToggles

  setup: ->
    ScholarMapViz.$window = $(window)

    ScholarMapViz.container  = '#visualization'
    ScholarMapViz.$container = $(ScholarMapViz.container)

    ScholarMapViz.$similarity_types = $('#similarity-types')

  fetch_default_data: ->
    ScholarMapViz.current_map = new ScholarMapViz.PeopleMap
    $('#map-types').find('button[data-map-type="PeopleMap"]').addClass 'active'


$ ->

  new ScholarMapViz.Initializer
