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
      .linkDistance 100
      .linkStrength (d) =>
        if @group_by(d.source) == @group_by(d.target) then 1 else .25
      .charge -300
      .gravity .02

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
    d3.json "/api/v1/#{@type}/graphs/force-directed.json", (error, graph) =>

      # sets up the force layout with our API data
      @force
        .nodes graph.nodes
        .links graph.links
        .start()

      # sets up the grouping controls for the graph nodes
      @initialize_grouping_controls graph.nodes

      # sets up link hover area, with a minimum stroke-width
      hover_link = @svg.selectAll '.hover-link'
        .data graph.links
        .enter().append 'line'
          .attr 'class', 'hover-link'
          .style 'stroke-width', (d) => d3.max [ 25, @link_width(d) ]

      # sets up link styles
      visible_link = @svg.selectAll '.visible-link'
        .data graph.links
        .enter().append 'line'
          .attr 'class', 'visible-link'
          .style 'stroke-width', @link_width

      # sets up node background, so that transparency doesn't reveal link tips
      node_background = @svg.selectAll '.node-background'
        .data graph.nodes
        .enter().append 'circle'
          .attr 'class', 'node-background'
          .attr 'r', @node_size

      # sets up node style and behavior
      node = @svg.selectAll '.node'
        .data graph.nodes
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
        .entries graph.nodes

      @draw_groups_legend groups

      # removes any groups with only a single node
      groups = groups.filter (group) ->
        group.values.length > 1

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
      @force.on 'tick', =>

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
          .attr 'x1', (d) -> d.source.x
          .attr 'y1', (d) -> d.source.y
          .attr 'x2', (d) -> d.target.x
          .attr 'y2', (d) -> d.target.y
          .on 'mouseover', @link_tip.show
          .on 'mouseenter', (d) ->
             set_link_status d, 'active'
          .on 'mouseout', (d) =>
            @link_tip.hide()
            set_link_status d, 'inactive'

        # the links that users see between nodes
        visible_link
          .attr 'x1', (d) -> d.source.x
          .attr 'y1', (d) -> d.source.y
          .attr 'x2', (d) -> d.target.x
          .attr 'y2', (d) -> d.target.y
          .attr 'data-id', (d) -> "#{d.source.index}->#{d.target.index}"

        # the background of nodes (so that transparency doesn't reveal link tips)
        node_background
          .attr 'cx', (d) -> d.x
          .attr 'cy', (d) -> d.y

        # the nodes
        node
          .attr 'cx', (d) -> d.x
          .attr 'cy', (d) -> d.y

  # draws the legend for hull groupings
  draw_groups_legend: (groups) ->
    ScholarMapViz.$groups_legend.html ''
    for group in groups
      ScholarMapViz.$groups_legend.append(
        """
        <p>
          <span style="color: #{@color group.key};">█</span>
          #{group.key}
        </p>
        """
      )

  # sets up the grouping controls, pulling in node attributes
  initialize_grouping_controls: (nodes) ->
    # erases any previous grouping controls
    ScholarMapViz.$grouping_controls.html ''

    # adds the "Group by" heading
    ScholarMapViz.$grouping_controls.append "<h2 class=\"h3\">Group by</h2>"

    # for all attributes not blacklisted for grouping, create a button to group by
    for attribute in @node_attributes(nodes)
      unless attribute in @ungroupable_attributes
        ScholarMapViz.$grouping_controls.append(
          """
            <button class="btn btn-default btn-block #{'active' if attribute == @grouping}" data-attribute-name="#{attribute}">
              #{attribute[0].toUpperCase() + attribute[1..attribute.length - 1].toLowerCase()}
            </button>
          """
        )

    update_group_by = @update_group_by

    $grouping_buttons = ScholarMapViz.$grouping_controls.find('button')

    # when a grouping button is clicked on, we should group data by that attribute
    $grouping_buttons.on 'click', ->
      $current_button = $(@)
      unless $current_button.hasClass 'active'
        $grouping_buttons.removeClass 'active'
        update_group_by $current_button.data('attribute-name')
        $current_button.addClass 'active'

  # updates the node grouping
  update_group_by: (new_grouping_attribute) =>
    @force.stop()
    @grouping = new_grouping_attribute
    @draw()

  # returns the value of the grouping attribute
  group_by: (d) =>
    if d[@grouping] instanceof Array
      d[@grouping].sort().join ', '
    else
      d[@grouping]

  # returns all original node attributes (not including generated attributes)
  node_attributes: (nodes) ->
    attributes = []
    for key of nodes[0]
      return attributes if key == 'index'
      attributes.push key

  # link tooltips list node similarities by type
  link_tip_html: (d) ->
    d.similarities.map (similarity) ->
      "<span class=\"d3-tip-label\">#{similarity.type}:</span> #{similarity.list.join(', ')}"
    .join '<br>'

  # link weight is determined by number of similarities between nodes
  link_weight: (d) ->
    test = d.similarities.map (similarity) ->
      similarity.list.length
    .reduce (a, b) ->
      a + b

  # link width is a modified log of the calculated link weight
  link_width: (d) =>
    Math.log( d3.max([2, @link_weight(d)]) ) * 5


class ScholarMapViz.PeopleMap extends ScholarMapViz.Map

  constructor: ->
    @type = 'people'
    @grouping = 'department'
    @ungroupable_attributes = ['name']
    super

  # node tooltips should display people's name
  node_tip_html: (d) ->
    d.name

  # constant node size of 20
  node_size: (d) ->
    20


class ScholarMapViz.ReferencesMap extends ScholarMapViz.Map

  constructor: ->
    @type = 'references'
    @grouping = 'department'
    @ungroupable_attributes = ['citation', 'year']
    super

  # node tooltips shuold display the reference citation, cutting it off it it's longer than 150 characters
  node_tip_html: (d) ->
    d.citation

  # node size depends on the number of authors for the reference
  node_size: (d) ->
    d3.max [10, Math.log( d.authors.length + 1 ) * 10]


class ScholarMapViz.DataToggle

  constructor:  ->
    $('#people-button').on 'click', ->
      choose_data $(@), -> new ScholarMapViz.PeopleMap
    $('#references-button').on 'click', ->
      choose_data $(@), -> new ScholarMapViz.ReferencesMap

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

    ScholarMapViz.$groups_legend     = $('#groups-legend')
    ScholarMapViz.$grouping_controls = $('#grouping-controls')

  fetch_default_data: ->
    new ScholarMapViz.PeopleMap
    $('#people-button').addClass 'active'


$ ->

  new ScholarMapViz.Initializer
