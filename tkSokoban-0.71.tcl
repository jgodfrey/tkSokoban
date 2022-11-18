# Copyright (C) 2001  Jeff Godfrey

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.


# Revisions
#
# Mar 02, 2001 Keith Vetter
# o added check point into the undo stack both manual and automatic--
#   after every 10 events. This required reversing the direction of
#   global(undoList). Added menu items and mouse and key bindings.
# o keep best record for each level (minimize moves) and save the info
#   in lib/tkSokoban.rc. The date of the best time is shown along with
#   the level in the Select Level dialog--so you can tell which ones you've
#   completed. To do: start at and goto next unfinished level functionality.
# o start of an rc file (see above): loads at startup and saves best times
#   after finishing a round. To do: add other state info into it.

# ===========================================================================

#
#       Wrapper proc for all "startup" things
#
# Arguments:
#       none
#
# Results:
#       everything starts from here

proc main {} {

    set ::global(version)     "0.71"
    set ::global(releaseDate) "03-Mar-01"

    set ::global(libPath) [file join [file dirname [info script]] lib]
    set ::global(rcFilename) [file join $::global(libPath) tkSokoban.rc]
    set ::global(levelPath) [file join [file dirname [info script]] "levels"]
    set ::global(skinPath)  [file join [file dirname [info script]] "skins"]
    set ::global(autoCheckpoint) 1

    source [file join $::global(libPath) dialog.tcl]

    # If the previous levelIndex was not restored from the rc file, set it to 0 here

    if {! [info exist ::global(levelIndex)]} {
        set ::global(levelIndex) 0
    }

    # If the previous skinName was not restored from the rc file, set it here

    if {! [info exist ::global(skinName)]} {
        set ::global(skinName) "Default"
    }


    # Load in all finished level info

    if {[file readable $::global(rcFilename)]} {
        catch {source $::global(rcFilename)}
    }

    # load the map images

    loadImages $::global(skinName)

    # buid the User Interface

    buildUI

    # Automatically load the first level

    loadLevelAuto "curr"
}


# loadLevelAuto --
#
#       Automatically load a new level based on the "which" parameter
#
# Arguments:
#       which - Determines which level to load ("prev", "next", or "curr")
#
# Results:
#       The appropriate level is loaded and prepared for play

proc loadLevelAuto {which} {

    # If a game is currently running, make sure the User wants to load
    # a new level...

    if {[info exists ::global(baseTime)]} {

        switch -exact -- $which {

            "curr" {
                set message "If this level is restarted, the current progress\
                             will be lost.\n\nRestart the current level?"
            }

            "prev" {
                set message "If the previous level is loaded, progress on the\
                             current level will be lost.\n\nLoad the\
                             previous level?"
            }

            "next" {
                set message "If the next level is loaded, progress on the\
                             current level will be lost.\n\nLoad the\
                             next level?"
            }
        }

        set resp [tk_messageBox \
            -title "Load Level Warning" \
            -type yesno \
            -icon warning \
            -parent . \
            -message $message]

        if {[string equal "no" $resp]} {
            return
        }
    }

    # Determine which level we are trying to load and adjust the
    # levelIndex accordingly

    switch -exact -- $which {

        "prev" {
            set delta -1
        }

        "next" {
            set delta 1
        }

        "curr" {
            set delta 0
        }
    }

    incr ::global(levelIndex) $delta

    startLevel
}


# selectListItem --
#
#       Creates a modal dialog containing a listbox and allows an item
#       be selected
#
# Arguments:
#       list         - list of items to display in the listbox
#       title        - the title of the modal dialog
#       selectedItem - optional item to "pre-select"
#
# Results:
#       -1 - User pressed "Cancel"
#      0-N - List index number of selected item

proc selectListItem {list title {selectedItem -1}} {

    set diag [dialog_create $title]

    set diagInfo [dialog_info $diag]
    set diagCntls [dialog_controls $diag]

    # create a new toplevel window containing a listbox for level selection

    set frm [frame $diagInfo.f]

    set sb [scrollbar $frm.sb \
         -orient vertical \
         -command [list $frm.lb yview]]

    set lb [listbox $frm.lb \
        -bg white \
        -width 30 \
        -height 15 \
        -listvar ::global(diagList) \
        -yscrollcommand [list $frm.sb set]]

    set btnOK [button $diagCntls.btnOK \
        -text "OK" \
        -width 8 \
        -state disable \
        -command {set ::global(dialogWait) 1}]

    set btnCancel [button $diagCntls.btnCancel \
        -text "Cancel" \
        -width 8 \
        -command {set ::global(dialogWait) 2}]

    bind $lb <Double-Button-1> {set ::global(dialogWait) 1}
    bind $lb <<ListboxSelect>> [list $btnOK configure -state normal]

    pack $lb -side left -expand 1 -fill both
    pack $sb -side left -fill y
    pack $frm -expand 1 -fill both

    pack $btnCancel $btnOK -side right -padx 4 -pady 4

    set ::global(diagList) $list

    # If "selectedItem" is valid, select it and make it visible

    if {$selectedItem >= 0 && $selectedItem < [llength $list]} {

        $lb selection set $selectedItem
        $lb see $selectedItem
    }

    # wait for the dialog to be destroyed

    dialog_wait $diag ::global(dialogWait)

    if {$::global(dialogWait) == 1} {
        return [$lb curselection]
    } else {
        return -1
    }
}


# loadSkin --
#
#       Allows a new skin to be selected from a listbox
#
# Arguments:
#       none
#
# Results:
#       If the User selects a new skin, the current level is redrawn
#       to reflect the change

proc loadSkin {} {

    set skinList [lsort -dictionary [glob -directory $::global(skinPath) \
        -nocomplain -types d *]]

    set baseList [list]

    foreach dir $skinList {
        lappend baseList [file tail $dir]
    }

    set item [selectListItem $baseList "Select Skin"]

    if {$item > -1} {
        loadImages [lindex $baseList $item]

        # Resize the canvas based on the new skin dims

        set cWid [expr {24 * $::global(imageX)}]
        set cHgt [expr {20 * $::global(imageY)}]
        .c1 configure -width $cWid -height $cHgt

        # redraw the level with the new skin

        drawLevel
    }
}


# loadLevelManual --
#
#       Allows a new level to be selected from a listbox
#
# Arguments:
#       none
#
# Results:
#       The appropriate level is loaded and prepared for play

proc loadLevelManual {} {

    # If a game is currently running, make sure the User wants to reload
    # the current level...

    if {[info exists ::global(baseTime)]} {

        set resp [tk_messageBox \
            -title "Reload Level Warning" \
            -type yesno \
            -icon warning \
            -parent . \
            -message "If a new level is loaded, progress on the current\
                      level will be lost.\n\nLoad a new level?"]

        if {[string equal "no" $resp]} {
            return
        }
    }

    set fileList [lsort -dictionary [glob -directory $::global(levelPath) \
            -nocomplain -types f *.xsb]]

    set baseList [list]
    foreach file $fileList {
        set baseName [file tail [file rootname $file]]

        # If the current level has been won before, append the date of
        # the win to the level name in the listbox

        if {[info exists ::global(times,$baseName)]} {
            append baseName " \[[lindex $::global(times,$baseName) 0]\]"
        }
        lappend baseList $baseName
    }

    set item [selectListItem $baseList "Select Level" $::global(levelIndex)]

    if {$item > -1} {
        set ::global(levelIndex) $item
        startLevel
    }
}


# timer --
#
#       Updates an on-screen level timer
#
# Arguments:
#       none
#
# Results:
#       The on-screen timer is updated every second to display the time spent
#       solving the current level

proc timer {} {

    # If the level start time is not yet set, do it now.

    if {![info exists ::global(baseTime)]} {
        set ::global(baseTime) [clock seconds]
    }

    set nowTime [clock seconds]
    set deltaTime [expr $nowTime - $::global(baseTime)]

    set ::global(time) [clock format $deltaTime -gmt 1 -format "%H:%M:%S"]

    after 1000 timer
}


proc exitScript {} {

    saveRCFile
    exit
}


# buildUI --
#
#       Create the User interface
#
# Arguments:
#       none
#
# Results:
#       The User interface is created

proc buildUI {} {

    set width  [expr {24 * $::global(imageX)}]
    set height [expr {20 * $::global(imageY)}]
    set c1 [canvas .c1 -width $width -height $height -background black]
    set sep [frame .sep -height 2 -borderwidth 2 -relief sunken]

    set frmWrap       [frame .frmWrap]
    set frmLevelName  [frame $frmWrap.frmLevelName]
    set frmLevelInfo  [frame $frmWrap.frmLevelInfo]
    set frmTime       [frame $frmWrap.frmTime]
    set frmPushes     [frame $frmWrap.frmPushes]
    set frmMoves      [frame $frmWrap.frmMoves]

    set txtLevelName [label $frmLevelName.txtLevelName -text "Level Name:"]
    set txtLevelInfo [label $frmLevelInfo.txtLevelInfo -text "Level Info:"]
    set txtTime      [label $frmTime.txtTime -text "Time:"]
    set txtPushes    [label $frmPushes.txtPushes -text "Pushes:"]
    set txtMoves     [label $frmMoves.txtMoves -text "Moves:"]

    set lblLevelName [label $frmLevelName.lblLevelName -width 8 \
        -textvar ::global(levelName) -relief sunken]
    set lblLevelInfo [label $frmLevelInfo.lblLevelInfo -width 22 \
        -textvar ::global(levelInfo) -relief sunken]
    set lblTime      [label $frmTime.lblTime -width 8 \
        -textvar ::global(time) -relief sunken]
    set lblPushes    [label $frmPushes.lblPushes -width 5 \
        -textvar ::global(pushCount) -relief sunken]
    set lblMoves     [label $frmMoves.lblMoves -width 5 \
        -textvar ::global(moveCount) -relief sunken]

    # create the menu structure

    menu .menubar
    . config -menu .menubar

    foreach m {Game Level Skin Help} {
        set $m [menu .menubar.m$m -tearoff 0]
        .menubar add cascade -label $m -menu .menubar.m$m -underline 0
    }

    $Game add command \
        -label "Undo Last Move" \
        -accelerator "Ctrl+Z" \
        -underline 0 \
        -command undoMove

    $Game add command \
        -label "Back to Checkpoint" \
        -accelerator "Ctrl+B" \
        -underline 0 \
        -command backToCheckpoint

    $Game add separator

    $Game add command \
        -label "Insert Checkpoint" \
        -accelerator "Ctrl+C" \
        -underline 7 \
        -command insertCheckpoint

    $Game add checkbutton \
        -label "Auto Checkpoint" \
        -underline 0 \
        -onvalue 1   \
        -offvalue 0  \
        -variable global(autoCheckpoint)

    $Game add separator

    $Game add command \
        -label "Exit" \
        -underline 1 \
        -command exitScript

    $Level add command \
        -label "Load Previous Level" \
        -accelerator "Ctrl+P" \
        -underline 5 \
        -command {loadLevelAuto "prev"}

    $Level add command \
        -label "Load Next Level" \
        -accelerator "Ctrl+N" \
        -underline 5 \
        -command {loadLevelAuto "next"}

    $Level add command \
        -label "Load Any Level..." \
        -accelerator "Ctrl+A" \
        -underline 5 \
        -command loadLevelManual

    $Level add separator

    $Level add command \
        -label "Restart Level" \
        -accelerator "Ctrl+R" \
        -underline 0 \
        -command {loadLevelAuto "curr"}

    $Skin add command \
        -label "Load New Skin" \
        -underline 0 \
        -command loadSkin

    $Help add command \
        -label "About tkSokoban..." \
        -underline 0 \
        -command about

    pack $sep -pady 2 -fill x
    pack $c1 -pady 2

    pack $txtLevelInfo  $lblLevelInfo -padx 2 -side left
    pack $txtLevelName  $lblLevelName -padx 2 -side left
    pack $txtTime       $lblTime      -padx 2 -side left
    pack $txtMoves      $lblMoves     -padx 2 -side left
    pack $txtPushes     $lblPushes    -padx 2 -side left

    pack $frmLevelInfo $frmLevelName $frmTime $frmMoves $frmPushes \
        -padx 4 -pady 1 -side left

    pack  $frmWrap -fill x -pady 2 -side right

    focus -force $c1

    # bind to all accepted keystrokes and mouse events

    bind .c1 <KeyPress-Right>         {movePlayer "right"}
    bind .c1 <KeyPress-Left>          {movePlayer "left"}
    bind .c1 <KeyPress-Up>            {movePlayer "up"}
    bind .c1 <KeyPress-Down>          {movePlayer "down"}
    bind .c1 <Control-KeyPress-Z>     undoMove
    bind .c1 <Control-KeyPress-z>     undoMove
    bind .c1 <Control-KeyPress-R>     {loadLevelAuto "curr"}
    bind .c1 <Control-KeyPress-r>     {loadLevelAuto "curr"}
    bind .c1 <Control-KeyPress-P>     {loadLevelAuto "prev"}
    bind .c1 <Control-KeyPress-p>     {loadLevelAuto "prev"}
    bind .c1 <Control-KeyPress-N>     {loadLevelAuto "next"}
    bind .c1 <Control-KeyPress-n>     {loadLevelAuto "next"}
    bind .c1 <Control-KeyPress-A>     loadLevelManual
    bind .c1 <Control-KeyPress-a>     loadLevelManual
    bind .c1 <Control-KeyPress-B>     backToCheckpoint
    bind .c1 <Control-KeyPress-b>     backToCheckpoint
    bind .c1 <Control-KeyPress-C>     insertCheckpoint
    bind .c1 <Control-KeyPress-c>     insertCheckpoint
    bind .c1 <ButtonPress-3>          undoMove
    bind .c1 <ButtonPress-2>          insertCheckpoint
    bind .c1 <Control-ButtonPress-3>  backToCheckpoint

    # don't allow the window to be resized

    wm resizable . 0 0

    # If the User decides to nuke the Window, control the exit...

    wm protocol . WM_DELETE_WINDOW exitScript
}


# startLevel --
#
#       Wrapper proc designed to call routines responsible for validating
#       and displaying the map
#
# Arguments:
#       none
#
# Results:
#       If the current map is valid, it is displayed

proc startLevel {} {

    # Read the current level - if it fails, return

    if {[readLevel]} {

        # Nasty hack to prevent crash if requested level is not available...
        # *** FIXME ***

        loadLevelAuto "curr"
    }

    # Validate the current map - if it fails, return

    if {[validateMap]} {
        return
    }

    drawLevel
}


# about --
#
#       Create an exceptionally weak and half-hearted "about" box
#
# Arguments:
#       none
#
# Results:
#       Display an "About" box


proc about {} {
    tk_messageBox \
        -title "About tkSokoban" \
        -icon info \
        -type ok \
        -parent . \
        -message "tkSokoban $::global(version)\n\n$::global(releaseDate)\n\
                  \nJeff Godfrey\njeff_godfrey@bigfoot.com"
}


# movePlayer --
#
#       Process a player move
#
# Arguments:
#       direction - what direction are we moving (up, down, left, or right)
#
# Results:
#       The requested move is checked for validity and if found to be valid
#       is completed.

proc movePlayer {dir} {

    # If the level has already been won, don't process the move

    if {$::global(levelWon)} return

    # If the timer hasn't been started, do it now

    if {![info exists ::global(baseTime)]} {
        timer
    }

    # Initialize location vars

    set x  $::global(meX)
    set x1 $x
    set x2 $x
    set y  $::global(meY)
    set y1 $y
    set y2 $y

    # Determine move direction and calculate the cells of interest

    switch -exact -- $dir {

        "right" {
            set x1 [expr {$x + 1}]
            set x2 [expr {$x + 2}]
        }

        "left" {
            set x1 [expr {$x - 1}]
            set x2 [expr {$x - 2}]
        }

        "up" {
            set y1 [expr {$y - 1}]
            set y2 [expr {$y - 2}]
        }

        "down" {
            set y1 [expr {$y + 1}]
            set y2 [expr {$y + 2}]
        }
    }

    # bounds check the proposed move

    if {$x1 < 0 || $x1 > $::global(maxX)} return
    if {$y1 < 0 || $y1 > $::global(maxY)} return

    # Get the data from the player's cell and the adjacent cell

    set cell  $::mapArray($x,$y)
    set cell1 $::mapArray($x1,$y1)


    # The cell data consists of a 2-element list
    # The first element is the cell contents, and the second is the cell type

    set cont  [lindex $cell 0]
    set type  [lindex $cell 1]
    set cont1 [lindex $cell1 0]
    set type1 [lindex $cell1 1]

    # In order for a move to be *potentially* valid , the contents of the
    # "move to" cell must be either "none" or "object"

    switch -exact -- $cont1 {

        "none" {     # "move to" cell is empty, move player into it

            storeMove $x $y $x1 $y1
            updateCell $x $y   [list none $type]
            updateCell $x1 $y1 [list $cont $type1]
            incr ::global(moveCount)
        }

        "object" {   # "move to cell" is an object - see if it can be moved

            # Grab attribute info from cell on far side of object

            set cell2 $::mapArray($x2,$y2)
            set cont2 [lindex $cell2 0]
            set type2 [lindex $cell2 1]

            # If this cell is empty, the object can be moved into it, so do it

            if {[string equal $cont2 "none"]} {
                storeMove $x $y $x1 $y1 $x2 $y2
                updateCell $x2 $y2 [list $cont1 $type2]
                updateCell $x $y   [list none $type]
                updateCell $x1 $y1 [list $cont $type1]

                incr ::global(moveCount)
                incr ::global(pushCount)

                # An object was moved - did we win?

                checkForWin
            }
        }
    }
}


# storeMove --
#
#       Store a move in the undo list
#
# Arguments:
#       args - a list of 1 or more triplets describing a move
#       The triplet consists of {cellX cellY {attribList}.  By restoring the
#       cell at cellX,cellY to "attribList" this effectively undo's a move
#
# Results:
#       The results of a single move are prepended to the undo list

proc storeMove {args} {

    foreach {x y} $args {
        lappend temp $x $y $::mapArray($x,$y)
    }

    set ::global(undoList) [linsert $::global(undoList) 0 $temp]

    # If autoCheckpoint is on, then insert a checkpoint every 10 moves

    if {$::global(autoCheckpoint)} {

        set n [lsearch $::global(undoList) "checkpoint"]

        if {$n < 0} {
            set n [llength $::global(undoList)]
        }

        if {$n >= 10} {
            set ::global(undoList) [linsert $::global(undoList) 0 "checkpoint"]
        }
    }
}


# undoMove --
#
#       Undo the last move
#
# Arguments:
#       none
#
# Results:
#       The last move in the "undoList" is undone.

proc undoMove {} {

    # If the level has been won, do not undo any moves

    if {$::global(levelWon)} return

    # If no moves exist to undo, just return

    if {![llength $::global(undoList)]} return

    # Grab the first element from the undo list.  This will be a list of triplets
    # consisting of {cellX cellY {attribList}}.  It will contain a triplet for
    # each cell affected by the current move (either 2 or 3 cells).  After getting
    # the group of triplets, remove them from the global undo list

    # if the element is "checkpoint", then we pop it and keep looking

    while {1} {
        if {![llength $::global(undoList)]} return

        set move [lindex $::global(undoList) 0]
        set ::global(undoList) [lreplace $::global(undoList) 0 0]
        if {! [string equal $move "checkpoint"]} break
    }

    # Get each set of triplets and update each cell with its previous content

    set count 0
    foreach {x y attrib} $move {
        incr count
        updateCell $x $y $attrib

    }

    # If this undo contained 3 cells, it was a push.  Decrement the
    # push counter.

    if {$count == 3} {
        incr ::global(pushCount) -1
    }

    # ALL undos involve a move, so decrement the move counter

    incr ::global(moveCount) -1
}


# insertCheckpoint
#
#      Insert a "checkpoint" marker at the top of the undo stack, unless the
#      top of the stack is already a checkpoint.  This marker will allow
#      multiple moves to be undone in a single step.
#
# Arguments:
#       none
#
# Results:
#

proc insertCheckpoint {} {

    if {! [string equal "checkpoint" [lindex $::global(undoList) 0]]} {
        set ::global(undoList) [linsert $::global(undoList) 0 "checkpoint"]
    }
}


# backToCheckpoint
#
#       Calls undoMove repeatedly until top of undo stack is "checkpoint"
#       or the stack is empty. The checkpoint is left on the undo stack.
#
# Arguments:
#       none
#
# Results:
#       The board is regressed to the last check point.

proc backToCheckpoint {} {

    if {$::global(levelWon)} return

    # First skip past any immediate checkpoints

    if {[string equal "checkpoint" [lindex $::global(undoList) 0]]} {
        set ::global(undoList) [lreplace $::global(undoList) 0 0]
    }

    # Now, do undoMove until top of stack says "checkpoint" or stack is empty

    while {1} {
        if {![llength $::global(undoList)]} break
        if {[string equal "checkpoint" [lindex $::global(undoList) 0]]} break
        undoMove
    }
}

# checkForWin --
#
#       Determines if the level has been completed by scanning the map for
#       objects not currently in a storage position.  If no "unstored" objects
#       are found, the level is complete.
#
# Arguments:
#       none
#
# Results:
#       If a win is detected, a message is issued informing the User.
#       Also, the User is given the chance to auto-load the next level.

proc checkForWin {} {

    # If the level is already complete, return

    if {$::global(levelWon)} return

    set maxX $::global(maxX)
    set maxY $::global(maxY)

    # Step through each element of the map looking for "unstored" objects
    # If any are found, just return

    for {set y 0} {$y <= $maxY} {incr y} {
        for {set x 0} {$x <= $maxX} {incr x} {
            set index "$x,$y"
            if {[info exists ::mapArray($index)]} {
                if {[string equal $::mapArray($index) [list object normal]]} {
                    return
                }
            }
        }
    }

    # Set the levelWon flag, stop the timer, and unset the baseTime var

    set ::global(levelWon) 1
    after cancel timer
    catch {unset ::global(baseTime)}

    # See if we have a best score for this levelName

    set moves [expr {$::global(moveCount) + 1}]

    if {[info exists ::global(times,$::global(levelName))]} {
        set moves [lindex $::global(times,$::global(levelName)) 2]
    }
    if {$::global(moveCount) < $moves} {
        set ::global(times,$::global(levelName)) [list \
        [clock format [clock seconds] -format "%a, %d %b %Y"] \
        $::global(time) $::global(moveCount) $::global(pushCount)]
    }

    # Issue User dialog along with level statistics

    set stat1 "Time:\t$::global(time)"
    set stat2 "Moves:\t$::global(moveCount)"
    set stat3 "Pushes:\t$::global(pushCount)"

    # Save the stats while the User is looking at the messageBox

    after 1 {saveRCFile 1}
    set resp [tk_messageBox \
        -title "Level Complete" \
        -type yesno \
        -icon question \
        -message "Level \"$::global(levelName)\" complete.\n\
                  \nStatistics:\n\n$stat1\n$stat2\n$stat3\n\
                  \nLoad the next level?" \
        -parent .]

    # If User wants to load next level, do it now

    if {[string equal "yes" $resp]} {
        loadLevelAuto "next"
    }

    return
}


# updateCell --
#
#       Update a cell (in the internal map and onscreen) with new content
#
# Arguments:
#          x - x map location of cell in question
#          y - y map location of cell in question
#       attr - the attributes of the updated cell (2-element list)
#
# Results:
#       The cell at x,y is updated with the new attributes and redrawn
#       on the screen.  Also, if the cell contains the player, update
#       the global player position.

proc updateCell {x y attr} {

    set cellCont [lindex $attr 0]

    # If this cell contains the player, update the player's global position

    if {[string equal $cellCont "player"]} {
        set ::global(meX) $x
        set ::global(meY) $y
    }

    # Update the memory map and the onscreen cell

    set ::mapArray($x,$y) $attr
    drawCell $x $y
}


# loadLevel --
#
#       Load a level file
#
# Arguments:
#       file - the level file to be loaded
#
# Results:
#       If the level file is found, it is loaded and prepared for play

proc readLevel {} {

    # Housekeeping required to play a new level

    after cancel timer
    set ::global(maxX) 0
    set ::global(maxY) 0
    set ::global(levelWon) 0
    set ::global(undoList) [list]
    set ::global(moveCount) 0
    set ::global(pushCount) 0
    set ::global(moveCount) 0
    set ::global(time) "00:00:00"
    catch {unset ::global(baseTime)}
    catch {unset ::mapArray}

    # Grab all level filenames and sort them

    set levelList [lsort -dictionary [glob -directory $::global(levelPath) \
        -nocomplain -types f *.xsb]]

    set listLen [llength $levelList]

    # Bounds check requested list index

    set message ""

    if {$::global(levelIndex) < 0} {
        set title   "Previous Level Not Available"
        set message "You are currently playing the FIRST level."
        set ::global(levelIndex) 0
    }
    if {$::global(levelIndex) >= $listLen} {
        set title   "Next Level Not Available"
        set message "You are currently playing the LAST level."
        set ::global(levelIndex) [expr {$listLen - 1}]
    }

    # If the requested index is out of bounds, issue User message and return

    if {[string length $message]} {
        tk_messageBox \
            -title $title \
            -type ok \
            -icon warning \
            -parent . \
            -message $message
        return 1
    }

    set file [lindex $levelList $::global(levelIndex)]

    # If the level file doesn't exist, issue message and return a fail status

    if {![file exists $file]} {
        tk_messageBox \
            -title "File Not Found" \
            -type ok \
            -icon error \
            -parent . \
            -message "Level file \"$file\" not found."
        return 1
    }

    set fileID [open $file RDONLY]

    # Read the file a line at a time

    set y -1
    while {[gets $fileID line ] >= 0} {

        # If the line contains only blanks, skip it

        set trimLine [string trim $line]
        if {![string length $line]} {
            continue
        }

        # If the first character of the lines is not SPACE or "#", this *should*
        # be the level information (?) - put it in the status bar...

        set line [string range $line 0 23]
        set char [string index $line 0]
        if {![string equal $char "#"] && ![string equal $char " "]} {
            set ::global(levelInfo) $trimLine
            continue
        }

        # The line looks valid.  If we have found more than 20 valid lines,
        # stop reading the file as this is larger than we want to handle

        incr y
        if {$y >= 20} {
            break
        }

        # Split the line into it's separate characters

        set colList [split $line {}]

        # Determine which map cell is represented by each char in the line

        set x -1
        foreach cell $colList {

            incr x

            # Remember the largest map cell X position

            if {$x > $::global(maxX)} {set ::global(maxX) $x}

            switch -exact -- $cell {

                "#" {  # wall

                    set ::mapArray($x,$y) [list wall normal]
                }

                " " {  # empty cell

                    set ::mapArray($x,$y) [list none normal]
                }

                "@" {  # player on empty cell

                    set ::mapArray($x,$y) [list player normal]
                    set ::global(meX) $x
                    set ::global(meY) $y
                }

                "+" {  # player on storage cell

                    set ::mapArray($x,$y) [list player storage]
                    set ::global(meX) $x
                    set ::global(meY) $y
                }

                "." {  # empty storage cell

                    set ::mapArray($x,$y) [list none storage]
                }

                "*" {  # object on storage cell

                    set ::mapArray($x,$y) [list object storage]
                }

                "$" {  # object on empty cell

                    set ::mapArray($x,$y) [list object normal]
                }
            }
        }
    }

    close $fileID

    # Remember the number of map lines stored

    set ::global(maxY) $y

    # Display the level filename in the status bar

    set ::global(levelName) [file tail [file rootname $file]]

    return 0
}


# validateMap --
#
#       Determine the validity of the current map
#
# Arguments:
#       none
#
# Results:
#       The map is deemed either valid or invalid.  If invalid, a user dialog
#       is issued explaining why.

proc validateMap {} {

    set objCount 0
    set storageCount 0
    set playerCount 0

    # Spin through all map cells and count the important stuff...
    # Players MUST equal 1, and object cells MUST equal storage cells

    for {set y 0} {$y <= $::global(maxY)} {incr y} {
        for {set x 0} {$x <= $::global(maxX)} {incr x} {
            if {[info exists ::mapArray($x,$y)]} {
                set cellCont [lindex $::mapArray($x,$y) 0]
                set cellType [lindex $::mapArray($x,$y) 1]
                if {[string match $cellCont "object"]}  {incr objCount}
                if {[string match $cellType "storage"]} {incr storageCount}
                if {[string match $cellCont "player"]}   {incr playerCount}
            }
        }
    }

    set message ""

    # If not exactly 1 player was found, fail the map

    if {$playerCount != 1} {
        set message "Map must contain exactly 1 player icon."
    }

    # If the object and storage cell counts do not match, fail the map

    if {$storageCount != $objCount} {
        set message "The object count and storage count must match."
    }

    if {[string length $message]} {
        tk_messageBox \
            -title "Invalid Map" \
            -type ok \
            -icon info \
            -message $message \
            -parent .

        return 1
    }

    return 0
}


# drawLevel --
#
#       Draw the map on the screen
#
# Arguments:
#       none
#
# Results:
#       The current map is drawn centered in the canvas

proc drawLevel {} {

    set width  $::global(imageX)
    set height $::global(imageY)

    # Determine X and Y offsets required to center the map

    set bufferX [expr {ceil(((24 - $::global(maxX)) / 2.0) - 1)}]
    set bufferY [expr {ceil(((20 - $::global(maxY)) / 2.0) - 1)}]

    # Ensure proper bounds for the offsets

    if {$bufferX < 0} {set bufferX 0}
    if {$bufferY < 0} {set bufferY 0}

    # Delete any existing objects from the canvas

    .c1 delete all

    # Spin through each cell of the map and display it on the screen

    for {set y 0} {$y <= $::global(maxY)} {incr y} {
        for {set x 0} {$x <= $::global(maxX)} {incr x} {
            set index "$x,$y"
            if {[info exists ::mapArray($index)]} {
                set cell $::mapArray($index)
                .c1 create image [expr {($bufferX * $width) + ($x * $width)}] \
                    [expr {($bufferY * $height) + ($y * $height)}] \
                    -anchor nw \
                    -tag $index \
                    -image $::images($cell)

                # Bind the autoMove proc to the click event of each map cell

                .c1 bind $index <ButtonPress-1> [list autoMove $index]
            }
        }
    }
}


# autoMove --
#
#       A wrapper proc to process a left mouse click on a map cell.
#
# Arguments:
#       index - the index of the clicked cell in "x,y" format
#
# Results:
#       The player may be moved, an object may be pushed, or nothing
#       at all based on analysis of the proposed move

proc autoMove {index} {

    # If the level has already been won, don't process the click

    if {$::global(levelWon)} {return}

    # Split the index into it's x and y components

    set indexList [split $index ","]
    set x [lindex $indexList 0]
    set y [lindex $indexList 1]

    # Determine if the requested move is a push

    set isPush [pushTo $x $y]

    # It wasn't a push, see if we can just move to the selected cell

    if {!$isPush} {
        runTo $x $y
    }
}


# pushTo --
#
#       Analyze the cell in question with respect to the player's current
#       position and determine if an object can be pushed.  If so, do it.
#       This needs to be done with less code.....
#
# Arguments:
#       x - x map coordinate of target cell
#       y - y map coordinate of target cell
#
# Results:
#       If possible, an object is pushed to the target cell.  If not possible,
#       nothing happens.

proc pushTo {x y} {

    set meX $::global(meX)
    set meY $::global(meY)
    set objCount 0

    # If the selected cell is not empty it is not valid

    set cellCont [lindex $::mapArray($x,$y) 0]
    if {![string equal $cellCont "none"]} {
        return 0
    }

    # If the selected cell is not orthogonal to the player position,
    # it is not valid.

    if {$meX != $x && $meY != $y} {
        return 0
    }

    if {$meY == $y} {

        # Horizontal move

        set delta [expr {abs($meX - $x)}]

        # Moving left or right?

        if {$meX < $x} {
            set min [expr {$meX + 1}]
            set max [expr {$x - 1}]
            set dir "right"
        } else {
            set min [expr {$x + 1}]
            set max [expr {$meX - 1}]
            set dir "left"
        }

        # See what's between the player and the target cell

        for {set nextX $min} {$nextX <= $max} {incr nextX 1} {
            set cellCont [lindex $::mapArray($nextX,$y) 0]

            # If walls are in the way, the move is invalid

            if {[string equal $cellCont "wall"]} {
                return 0
            }

            # Count the number of objects between the player and target the cell

            if {[string equal $cellCont "object"]} {
                incr objCount
            }
        }

        # If exactly 1 object was not found, the move is not valid

        if {$objCount != 1} {
            return 0
        }

        # Everything looks good - move the required number of cells

        for {set i 1} {$i < $delta} {incr i 1} {
            movePlayer $dir
        }

    } else {

        # Vertical move

        set delta [expr {abs($meY - $y)}]

        # Moving up or down?

        if {$meY < $y} {
            set min [expr {$meY + 1}]
            set max [expr {$y - 1}]
            set dir "down"
        } else {
            set min [expr {$y + 1}]
            set max [expr {$meY - 1}]
            set dir "up"
        }

        # See what's between the player and the target cell

        for {set nextY $min} {$nextY <= $max} {incr nextY 1} {
            set cellCont [lindex $::mapArray($x,$nextY) 0]

            # If walls are in the way, the move is invalid

            if {[string equal $cellCont "wall"]} {
                return 0
            }

            # Count the number of objects between the player and target the cell

            if {[string equal $cellCont "object"]} {
                incr objCount
            }
        }

        # If exactly 1 object was not found, the move is not valid

        if {$objCount != 1} {
            return 0
        }

        # Everything looks good - move the required number of cells

        for {set i 1} {$i < $delta} {incr i 1} {
            movePlayer $dir
        }

    }

    return 1
}


# runTo --
#
#       Move the player from his current position to the target cell using
#       the shortest path possible.  This is only done if we can get "from
#       here to there" by traversing only empty cells.
#
# Arguments:
#       x - x map coordinate of target cell
#       y - y map coordinate of target cll
#
# Results:
#       If possible, the player is moved to the target cell

proc runTo {x y} {

    set maxX $::global(maxX)
    set maxY $::global(maxY)

    # Each cell will be marked with its relative distance from target cell.
    # We need a value that will be larger than the longest possible path to
    # represent an "unreachable" state.  9999 sounds good to me...

    set UNREACHABLE 9999

    # Mark all cells (in a temporary map) as UNREACHABLE for now

    for {set tempY 0} {$tempY <= $maxY} {incr tempY} {
        for {set tempX 0} {$tempX <= $maxX} {incr tempX} {
            set ::distArray($tempX,$tempY) $UNREACHABLE
        }
    }

    # Find the shortest path to the target cell using a fill search algorithm

    findShortestPath $x $y 0

    set meX $::global(meX)
    set meY $::global(meY)

    # If the player's cell is still marked as "UNREACHABLE", then the requested
    # move IS NOT valid - just return.

    if {$::distArray($meX,$meY) == $UNREACHABLE} {
        return
    }

    # We seem to have found a valid path.  Walk from the player position to the
    # target cell by always moving to the cell containing the "next" distance
    # value.  Each cell will be marked with the total distance between it and
    # the target cell (which is marked with 0).  There should ALWAYS be an
    # adjacent cell containing the next LOWER sequential distance value.  This
    # is the "next" cell...  So, starting at the player's cell (dist N) walk
    # to the target cell (dist 0) by following the path of decrementing
    # distance values.

    while {$::distArray($meX,$meY)} {

        # The distance value we are looking for next should be one less than
        # the distance value marking the current cell.

        set nextDist [expr {$::distArray($meX,$meY) - 1}]

        # Is the correct cell to our left?

        if {$::distArray([expr {$meX-1}],$meY) == $nextDist} {
            incr meX -1
            movePlayer left

        # Is the correct cell to our right?

        } elseif {
            $::distArray([expr {$meX+1}],$meY) == $nextDist} {
            incr meX 1
            movePlayer right

        # Is the correct cell up?

        } elseif {
            $::distArray($meX,[expr {$meY-1}]) == $nextDist} {
            incr meY -1
            movePlayer up

        # Is the correct cell down?

        } elseif {
            $::distArray($meX,[expr {$meY+1}]) == $nextDist} {
            incr meY 1
            movePlayer down

        # If we didn't find the correct cell, we have a rather large problem.
        # This should NEVER happen...

        } else {
            puts "What the?  Errr.... Houston, we have a problem"
            return
        }
    }
}


# findShortestPath --
#
#       Find the shortest path between the target cell and the player's
#       current position using a fill search algorithm.  Note, this
#       proc is called recursively to find the correct path.
#
# Arguments:
#             x - x map coordinate of current cell
#             y - y map coordinate of current cell
#       pathLen - the current distance from the target cell
#
# Results:
#       <start here>

proc findShortestPath {x y pathLen} {

    # If the target cell is off the map, return

    if {$x < 0 || $x > $::global(maxX)} return
    if {$y < 0 || $y > $::global(maxY)} return

    set cellCont [lindex $::mapArray($x,$y) 0]
    set cellType [lindex $::mapArray($x,$y) 1]

    # If the current cell contains a "wall" or an "object", it is not valid

    if {[string equal $cellCont "wall"] || [string equal $cellCont "object"]} {
        return
    }

    # If the cell is already marked with a shorter path distance, return

    if {$::distArray($x,$y) <= $pathLen} {
        return
    }

    # mark the cell with the current path distance

    set ::distArray($x,$y) $pathLen
    incr pathLen

    # if this cell is the player, return

    if {($x == $::global(meX)) && ($y == $::global(meY))} {
        return
    }

    # call recursively

    findShortestPath [expr {$x - 1}] $y $pathLen
    findShortestPath [expr {$x + 1}] $y $pathLen
    findShortestPath $x [expr {$y - 1}] $pathLen
    findShortestPath $x [expr {$y + 1}] $pathLen
}


# drawCell --
#
#       Draw a map cell on screen
#
# Arguments:
#       x - x map coordinate of target cell
#       y - y map coordinate of target cell
#
# Results:
#       A cell is drawn on the screen

proc drawCell {x y} {

    set index "$x,$y"
    .c1 itemconfigure $index -image $::images($::mapArray($index))
    update idletasks
}


# loadImages --
#
#       Load all cell image data
#
# Arguments:
#       none
#
# Results:
#       0 - All image data loaded
#       1 - Fail

proc loadImages {which} {

    foreach {content type} \
        {none normal player normal player storage object normal \
         object storage none storage wall normal} {
             set file [file join $::global(skinPath) $which ${content}_${type}.gif]

            # If the image file doesn't exist, issue message and return a fail status

            if {![file exists $file]} {
                tk_messageBox \
                    -title "File Not Found" \
                    -type ok \
                    -icon error \
                    -parent . \
                    -message "Skin image file \"$file\" not found."
                exit
            }

             set ::images([list $content $type]) [image create photo -file $file]
    }
    set ::global(skinName) $which
    set ::global(imageY) [image height $::images([list player normal])]
    set ::global(imageX) [image width  $::images([list player normal])]
}


# saveRCFile  --
#
#       Saves info about the state of the game into an RC file
#
# Arguments:
#       quiet - if true, then don't put up any error messages
#
# Results:
#       The tkSokoban.rc file is overwritten with new state information

proc saveRCFile {{quiet 0}} {

    if {[catch {set fout [open $::global(rcFilename) w]} err]} {
        if {! $quiet} {
            set msg "Could not open tkSokoban.rc file for writing:\n$err"
            tk_messageBox \
            -title "Open RC File Error" \
            -type ok \
            -icon error \
            -parent . \
            -message $msg
        }

        return
    }

    # Store all solved level information

    foreach name [lsort [array names ::global times,*]] {
            puts $fout "set ::global($name) \[list $::global($name)\]"
    }

    # Store current level and skin

    puts $fout "set ::global(levelIndex) $::global(levelIndex)"
    puts $fout "set ::global(skinName) $::global(skinName)"

    close $fout
}

# Kick this thing off

main
