<cfscript>


	// works!
	// writeDump(var=getImmediatelyAdjacent(data, data[2][5]), label="these are adjacent")

	boolean function hasOpenSides(box){
		var hasOpenSides = false
		for(var side in BOX_SIDES_MAP.keyList()){
			if(!arguments.box[side]){
				return true
			}
		}
		return false
	}

	// , checkedSides = [] NEEDED in prepareSides!
	boolean function hasUncheckedSides(box){
		for(var side in BOX_SIDES_MAP.keyList()){
			if(!arguments.box.checkedSides.find(side)){
				return true
			}
		}
		return false
	}



	void function grouperA(data, groups){
		var d = arguments.data
		var g = arguments.groups

		var y = 0
		var groupNr = 0
		for(var r in d){
			y++
			var x = 0
			for(var c in r){
				x++

				// RECURSIVE START
				var boxToCheck = c;
				while(hasUncheckedSides(boxToCheck)){

					// loop t,l,b,r
					for(var side in BOX_SIDES_MAP.keyList()){

						// if open, shift next
						if(!c[side]){
							var sideInfo = BOX_SIDES_MAP[side]
							sideInfo.shiftFunction(x,y) // move "cursor" according to which side it is (see above)
							boxToCheck = d[y][x]
						}

						// mark side as checked
						c.checkedSides.append(side)
						c.groupNr = groupNr
					}

				}

				groupNr++
			}
		}
	}

	void function grouperB(data, groups){
		var d = arguments.data
		var g = arguments.groups
		var groupNr = 0

		if(!d.len() || !d.first().len()){
			return // err: no data
		}

		// RECURSIVE START
		var boxesChecked = [] // hold array of y.x strings
		var boxToCheck = d.first().first()
		while(hasUncheckedSides(boxToCheck) && !boxesChecked.find()){
			groupNr++

			// loop t,l,b,r
			for(var side in BOX_SIDES_MAP.keyList()){

				// checked this side already? Skip
				if(boxToCheck.checkedSides.find(side)){
					continue;
				}

				// mark side as checked
				boxToCheck.checkedSides.append(side)
				boxToCheck.groupNr = groupNr

				// if open, shift next
				if(!boxToCheck[side]){
					var sideInfo = BOX_SIDES_MAP[side]
					var clone = boxToCheck.duplicate()
					var coords = { x=clone.x, y=clone.y}

					// writeDump("#side# #coords.y#.#coords.x#")
					sideInfo.shiftFunction(coords) // move "cursor" according to which side it is (see above)

					//writeDump("#coords.y#.#coords.x#")

					boxToCheck = d[coords.y][coords.x]
					writeDump(var=boxToCheck, label="side=#side#; next: #coords.y#.#coords.x#")
					break; // next WHILE loop
				}
			}

			// mark checked
			boxesChecked.append("#coords.y#.#coords.x#")
		}
	}

	void function grouperC(boxesToCheck, data, groups){
		var b = arguments.boxesToCheck
		var d = arguments.data
		var g = arguments.groups

		var groupNr = 1

		while(b.len()){ // while there are boxes to check


			var boxCoords = b.first()
			var box = data[boxCoords.listFirst(".")][boxCoords.listLast(".")]

			writeDump(var=boxCoords, label="A")

			while(hasUncheckedSides(box)){ // while this box has sides to be checked

				box.groupNr = groupNr

				for(var side in BOX_SIDES_MAP.keyList()){ // loop sides

					if(!box[side]){ // if "open" (border for this side is false); get adjacent
						var sideInfo = BOX_SIDES_MAP[side]
						var clone = box.duplicate()
						var coords = { x=clone.x, y=clone.y }
						writeDump(var=coords, label="check")
						sideInfo.shiftFunction(coords) // move "cursor" according to which side it is (see above)

						// set adjacent box group to same group (IF adjacent box is still in the "to be checked" list, and IF rows/cols are not exceeded)
						if(b.find("#coords.y#.#coords.x#") && d.len() >= coords.y && d[coords.y].len() >= coords.x){
							writeDump(var=coords, label="go")
							var adjacent = d[coords.y][coords.x]
							adjacent.groupNr = groupNr

							// mark 'opposite' side as checked
							adjacent.checkedSides.append(sideInfo.opposite)

							// remove adjacent
							b.delete("#coords.y#.#coords.x#")
						}
					}

					// mark side as checked
					box.checkedSides.append(side)
				}
			}

			groupNr++

			b.shift(defaultValue=[]) // remove first box from array
		}
	}
</cfscript>