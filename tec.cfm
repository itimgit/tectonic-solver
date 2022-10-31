<cfsetting showdebugoutput="true" requesttimeout="10">

<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0/css/bootstrap.min.css" integrity="sha384-Gn5384xqQ1aoWXA+058RXPxPg6fy4IWvTNh0E263XmFcJlSAwiGgFAW/dAiS6JXm" crossorigin="anonymous">

<cfhtmlhead>
	<style>
		table {
			border-collapse: collapse;
		}

		table.pzlTable td {
			width: 40px;
			height: 40px;
			text-align: center;
			vertical-align: middle;
			border: 1px solid silver;
		}

		table.pzlTable tbody tr td.l {border-left: 2px solid black;}
		table.pzlTable tbody tr td.t {border-top: 2px solid black;}
		table.pzlTable tbody tr td.r {border-right: 2px solid black;}
		table.pzlTable tbody tr td.b {border-bottom: 2px solid black;}
	</style>
</cfhtmlhead>

<cfscript>
	// if left=false (open), apply shiftFunction to #prop# to find next box
	BOX_SIDES_MAP = [
		"l" = {
			name = "left"
			, shiftFunction = function(coords){ arguments.coords.x--}
			, opposite = "r"
		}
		, "r" = {
			name = "right"
			, shiftFunction = function(coords){ arguments.coords.x++}
			, opposite = "l"
		}
		, "t" = {
			name = "top"
			, shiftFunction = function(coords){ arguments.coords.y--}
			, opposite = "b"
		}
		, "b" = {
			name = "bottom"
			, shiftFunction = function(coords){ arguments.coords.y++}
			, opposite = "t"
		}
	]

	DIAGONAL_MAP = [
		"lb" = {
			name = "linksboven"
			, shiftFunction = function(coords){ arguments.coords.y--; arguments.coords.x--}
		}
		, "rb" = {
			name = "rechtsboven"
			, shiftFunction = function(coords){ arguments.coords.y--; arguments.coords.x++}
		}
		, "lo" = {
			name = "linksonder"
			, shiftFunction = function(coords){ arguments.coords.y++; arguments.coords.x--}
		}
		, "ro" = {
			name = "rechtsonder"
			, shiftFunction = function(coords){ arguments.coords.y++; arguments.coords.x++}
		}
	]

	// combine sides
	ALL_SIDES_MAP = BOX_SIDES_MAP.duplicate().append(DIAGONAL_MAP, true)

	void function setVal(data,y,x,val){
		var d = arguments.data
		d[arguments.y][arguments.x].val = arguments.val
	}

	// prepare: enrich
	array function prepareSides(data){
		var d = arguments.data
		var rows = []

		var y = 0
		for(var r in d){
			y++
			var x = 0
			var row = []
			for(var c in r){
				x++
				var col = [
					"y" = y
					, "x" = x
					, "val" = 0
					, "groupNr" = 0
					, "groupLen" = 0
					, "surroundingBoxes" = []
					, "surroundingCoords" = ""
					, "illegalValues" = []
				]
				for(var side in BOX_SIDES_MAP.keyList()){
					col[side] = !c.listFind(side)
				}
				row.append(col)
			}
			rows.append(row)
		}
		return rows
	}

	boolean function appendUnique(required array sourceArray, required any value) {
		var s = arguments.sourceArray
		var v = arguments.value
		if(!s.find(v)){
			s.append(v)
			return true
		}
		return false
	}

	array function arrayUnique(required array sourceArray) {
		var source = arguments.sourceArray;
		return source.filter((item, index) => variables.source.find(arguments.item) == arguments.index); // return copy
	}

	// DISPLAY
	string function cssBoxClasses(c){
		var borders = []
		for(var side in BOX_SIDES_MAP.keyList()){
			if(arguments.c[side]){
				borders.append(side) // custom css class
			}
		}

		return borders.toList(" ")
	}

	string function debugCoordList(required array boxes){
		var b = arguments.boxes
		var coords = []
		for(var box in boxes){
			coords.append("#box.y#.#box.x#")
		}

		return coords.toList()
	}

	struct function getBoxFromCoordsString(required array data, required string coords){ // y.x!
		var d = arguments.data
		var c = arguments.coords
		var y = listFirst(c, ".")
		var x = listLast(c, ".")
		if(y < 1 || y > d.len() || x < 1 || x > d.first().len()){
			return {}
		}
		return d[y][x]
	}

	// PREPARE: get 1d array of all boxes
	array function arrayOfBoxCoords(required array data, boolean onlyWithValue = false){
		var d = arguments.data
		var boxes = []

		var y = 0
		for(var row in d){
			y++
			var x = 0

			for(var col in row){
				x++
				if(arguments.onlyWithValue){
					var box = d[y][x]
					if(val(box.val) == 0){
						continue;
					}
				}
				boxes.append("#y#.#x#")
			}
		}
		return boxes
	}

	// PREPARE: group helpers + grouper
	string function getOpenSidesList(box){
		var openSides = []
		for(var side in BOX_SIDES_MAP.keyList()){
			if(!arguments.box[side]){
				openSides.append(side)
			}
		}

		return openSides.toList()
	}

	boolean function isInGroup(required array group, required struct box){
		var findBox = arguments.box;
		return arguments.group.filter((b) => arguments.b.y == findBox.y && arguments.b.x == findBox.x).len() > 0;
	}

	struct function getCoords(required struct box){
		var clone = arguments.box.duplicate() // clone needed? Probably, to avoid changing x/y from original box
		return { x=clone.x, y=clone.y }
	}

	array function getImmediatelyAdjacent(required array data, required struct box){ // get directly adjacent - but only if not crossing a border
		var adjacent = []
		var sides = getOpenSidesList(arguments.box)
		for(var side in sides){ // loop open sides
			var coords = getCoords(arguments.box)
			var sideInfo = BOX_SIDES_MAP[side]
			sideInfo.shiftFunction(coords)
			// get adjacent box and add to array
			adjacent.add(arguments.data[coords.y][coords.x])
		}

		return adjacent;
	}

	array function getSurrounding(required array data, required struct box){
		var box = arguments.box
		var d = arguments.data
		var surrounding = []

		for(var side in ALL_SIDES_MAP){ // loop open sides
			var coords = getCoords(box)
			var sideInfo = ALL_SIDES_MAP[side]
			sideInfo.shiftFunction(coords)
			// get box from adjusted position and add to array (if within bounds)
			if(coords.x > 0 && coords.y > 0 && coords.y <= d.len() && coords.x <= d.first().len() ){
				surrounding.add(d[coords.y][coords.x])
			}
		}

		return surrounding
	}

	array function getGroupRecursively(required array data, required struct box, array group=[]){
		var immediatelyAdjacentBoxes = getImmediatelyAdjacent(data=arguments.data, box=arguments.box)
		arguments.group.append(box)
		for(var adjacentBox in immediatelyAdjacentBoxes){
			if(!isInGroup(arguments.group, adjacentBox)){
				getGroupRecursively(arguments.data, adjacentBox, arguments.group)
			}
		}
		return arguments.group
	}

	array function grouper(required array data){
		var d = arguments.data
		var b = arrayOfBoxCoords(d)
		var groups = []
		var groupNr = 0

		while(b.len()){ // while there are boxes to check
			groupNr++

			var boxCoords = b.first()
			var box = getBoxFromCoordsString(d, boxCoords)

			var thisGroup = getGroupRecursively(d, box)
			for(var boxInGoup in thisGroup){
				boxInGoup.groupNr = groupNr
				boxInGoup.groupLen = thisGroup.len()
				b.delete("#boxInGoup.y#.#boxInGoup.x#") // delete from "to be checked"
			}

			groups.append(thisGroup);
		}

		return groups
	}

	// SOLVER functions
	void function solveAllGroupsOfOne(required array groupMap){ // groups are BY REFERENCE: updating values will be reflected in main dataset
		var groups = arguments.groupMap
		for(var group in groups){
			if(group.boxes.len() == 1){
				var box = group.boxes.first()
				box.val = 1
				group.solved = true
			}
		}
	}


	void function setSurrounding(required array data){
		var d = arguments.data
		var b = arrayOfBoxCoords(d)
		while(b.len()){ // while there are boxes to check
			var boxCoords = b.first()
			var box = getBoxFromCoordsString(d, boxCoords)
			var surroundingBoxes = getSurrounding(data=d, box=box)
			box.surroundingCoords = debugCoordList(surroundingBoxes) // setting reference directly to surroundingBoxes seem to crash server. Maybe with a COPY, butlosing reference is pointless anyway. So use coordlist
			b.shift([]) // remove first or set empty (default)
		}
	}

	void function setIllegalValuesInSurroundingBoxes(required array data){
		var d = arguments.data
		var b = arrayOfBoxCoords(data=d, onlyWithValue=true)
		while(b.len()){ // while there are boxes to check
			var boxCoords = b.first()
			var box = getBoxFromCoordsString(d, boxCoords)
			for(var surroundingBoxCoords in box.surroundingCoords){
				var surroundingBox = getBoxFromCoordsString(d, surroundingBoxCoords)
				appendUnique(surroundingBox.illegalValues, box.val)
			}

			b.shift([]) // remove first or set empty (default)
		}
	}

	array function addGroupMetaData(required array groups){
		var groupMap = []
		for(var g in arguments.groups){
			groupMap.append([
				"boxes" = g
				, "valuesToFill" = []
				, "solved" = false
			])
		}
		return groupMap
	}

	array function getBoxesValueArray(required array boxes, boolean onlyNonZero = true){
		var vals = arguments.boxes.reduce((result=[], box) => arguments.result.append(arguments.box.val))
		if(arguments.onlyNonZero){
			vals = vals.filter((val) => arguments.val != 0)
		}
		return vals
	}
	void function determineGroupValuesToFill(required array groupMap){
		for(var g in arguments.groupMap){
			var max = g.boxes.len()
			var values = getBoxesValueArray(g.boxes)
			for(var i=1; i<=max; i++){
				if(!values.find(i)){
					g.valuesToFill.append(i)
				}
			}

			if(!g.valuesToFill.len()){
				g.solved = true
			}
		}
	}

	void function markFilledValuesAsIllegalWithinGroups(required array groupMap){
		for(var g in arguments.groupMap){
			var values = getBoxesValueArray(g.boxes)
			for(var box in g.boxes){
				if(box.val == 0){
					box.illegalValues = box.illegalValues.merge(values)
				}

				box.illegalValues = arrayUnique(box.illegalValues)
				arraySort(box.illegalValues, "numeric")

			}
		}
	}



/////////////////

	// MANUAL CONFIG: list all sides that are OPEN
	openSides = [
		["r", "l,r", "l,r", "l", "b"]
		, ["r", "l,r,b", "l,b", "r", "l,t,b"]
		, ["", "t,r", "t,l", "b", "t,b"]
		, ["r", "l,r", "l,r", "l,t", "t"]
		, ["", "b,r", "l,b", "b,r", "l,b"]
		, ["b", "t,r", "l,t,b", "t,r,b", "t,l"]
		, ["t,r", "l", "t", "t", ""]
	]

	// PREPARE
	data = prepareSides(openSides)
	groups = grouper(data) // GROUP

	// MANUAL CONFIG: initially provided values (data,Y,X !!)
	setVal(data, 2,5, 5)
	setVal(data, 4,1, 3)
	setVal(data, 5,2, 2)
	setVal(data, 6,4, 4)
	setVal(data, 7,3, 1)

	originalData = data.duplicate()
	groupMap = addGroupMetaData(groups)

	// SOLVE
	solveAllGroupsOfOne(groupMap)
	setSurrounding(data)

	setIllegalValuesInSurroundingBoxes(data)

	determineGroupValuesToFill(groupMap)

	// add all currently set group values to all group boxes illegalValues
	markFilledValuesAsIllegalWithinGroups(groupMap)

	// fill boxes that have one option (g.len-1 == b.illegalValues | valuesToFill )

	// determine POSSIBLE values
</cfscript>


<cfoutput>

	<div class="row m-3">
		<div class="col-4">
			<table class="pzlTable">
				<cfloop array="#originalData#" index="iRow" item="cols">
					<tr>
						<cfloop array="#cols#" item="col">
							<td class="#cssBoxClasses(col)#"><cfif col.val EQ 0>&nbsp;<cfelse><b>#col.val#</b></cfif></td>
						</cfloop>
					</cfloop>
				</tr>
			</table>
		</div>

		<div class="col-4">
			<table class="pzlTable">
				<cfloop array="#data#" index="iRow" item="cols">
					<tr>
						<cfloop array="#cols#" item="col">
							<cfset group = groupMap[col.groupNr]>
							<td class="#cssBoxClasses(col)# <cfif group.solved>text-success</cfif>"
								title="#group.valuesToFill.toList()#"
							>
								<cfif col.val EQ 0>
									<cfif col.illegalValues.len()>
										<small class="text-danger">
											#col.illegalValues.toList()#
										</small>
									<cfelse>
										&nbsp;
									</cfif>
								<cfelse>
									<b>#col.val#</b>
								</cfif>
							</td>
						</cfloop>
					</cfloop>
				</tr>
			</table>
		</div>

		<div class="col-4">
			<table class="pzlTable">
				<cfloop array="#data#" index="iRow" item="cols">
					<tr>
						<cfloop array="#cols#" item="col">
							<td class="#cssBoxClasses(col)#" title="#col.surroundingCoords#">(#col.groupNr#)#col.y#.#col.x#</td>
						</cfloop>
					</cfloop>
				</tr>
			</table>
		</div>
	</div>

	<cfdump var="#groupMap#" label="groupMap" expand="true">
	<cfdump var="#data#">

</cfoutput>