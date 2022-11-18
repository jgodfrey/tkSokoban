# tkSokoban
A decades old version of Sokoban, written in Tcl/Tk. Just dropping here for safe keeping. 

The text below is copied verbatim from the project's original home on the [Tcler's Wiki](https://wiki.tcl-lang.org/page/tkSokoban).

### License

Copyright (c) 2001, Jeff Godfrey (jeff_godfrey _at_ pobox _dot_ com)

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

### Requirements

* tcl/tk 8.3 or newer

### General

tkSokoban is a quick and dirty hack of a game better known as Sokoban. There are numerous incarnations of this game available on the net along with history, background, hints, and strategies. Because of this, this document will not go into these areas. It was written using tcl/tk 8.3.2 under Win98.

### Installation

Just unwrap the archive into the directory of your choice ensuring that the original directory structure is maintained.

### Objective

The objective of the game is to place all objects (green balls) on top of their storage locations (recessed cells) by pushing them with the player (blue ball). The objects cannot be pulled - they can only be pushed and only one object can be moved at a time. Once all the objects are in a valid storage location, the level is complete.

Note: The above "character" descriptions are only valid when using the default skin.

### Player Controls

The player can be moved with the keyboard or the mouse. The following keyboard input is accepted:

* Up Arrow - Move up 1 cell
* Down Arrow - Move down 1 cell
* Left Arrow - Move left 1 cell
* Right Arrow - Move right 1 cell
* Ctrl-Z - Undo last move
* Ctrl-R - Restart current level
* Ctrl-A - Load "A"ny level
* Ctrl-P - Load "P"revious level (if available)
* Ctrl-N - Load "N"ext level (if available)
* Ctrl-C - Insert checkpoint into undo stack (see Ctrl-B for use)
* Ctrl-B - Undo all moves back to last checkpoint

The mouse can be used as follows:

* Left Click - Move player or object to the selected cell (if possible)
* Right Click - Undo last move (same as Ctrl-Z)
* Middle Click - Insert checkpoint into undo stack (same as Ctrl-C)
* Ctrl-Right Click - Undo all moves back to last checkpoint (same as Ctrl-B)
* Checkpoints

Checkpoints are special markers inserted into the undo stack to allow more than one move to be undone at a time. Checkpoints can be inserted manually with the menu item "Game --> Checkpoint", CTRL-C, or a middle mouse click. You can "undo" a group of moves back to the last checkpoint with the menu item "Game --> Back to Checkpoint", CTRL-B, or ctrl-right mouse click. If the menu item "Game --> Auto Checkpoint" is enabled, tkSokoban will automatically add checkpoints every 10 moves. This will allow you to undo 10 moves at a time using any of the above methods.

### Left Click Details

Click on the cell you want the player (or object) to go to. The target cell will be analyzed using the following 2 methods:

1. Determine if the objective is to push an object:

Is the target cell orthogonal to the player's current position?
Is the target cell empty?
Is there exactly 1 object between the player and the target cell?
Are all other cells between the player and the target cell empty?
If all of the above is true, the object is moved to the target cell.

2. If any of the above is NOT true, determine if the objective is to move the player.

If it is possible to get from the player's current position to the target cell by navigating only EMPTY cells, the player will be moved to the target cell.

The mouse does not provide any functionality that is not available from the keyboard, but it does tend to speed up the game by automating the task of moving (or pushing) from point A to point B.

### Levels

The level file format used by tkSokoban is a "standard" format known as an "xsb" file (for X-Sokoban, I think?). Additional levels are available all over the Internet. Just dump any additional files into the "levels" directory (provided they are .xsb format).

The included levels were downloaded from:

http://kantorek.webzdarma.cz/sokoban.htm 

The owner of the site graciously granted me permission to include these levels. If you are interested, there are over 1000 more on his site.

The original author of each level (if included in the file) should be displayed on the left end of the status bar.

The "Next Level" and "Previous Level" logic is based on the next and previous level name as it would be found in an alphabetical list.

The maximum level dimensions are 24 wide x 20 high.

### Skins

The graphics used in tkSokoban are just small GIF images found in sub-folders beneath the "skins" folder. Feel free to replace them with your own. Creating the provided skins actually took me longer than writing the game! I am apparently somewhat less talented with PhotoImpact than tcl/tk (?). There are 7 images in all and the only requirement is that you do not change the filenames. The default images are 30x30 pixels, although you can change this to suit your preferences (although ALL images are assumed to be the same size...).

The image definitions are as follows:

* none_normal - empty normal cell
* none_storage - empty storage cell
* player_normal - player on normal cell
* player_storage - player on storage cell
* object_normal - object on normal cell
* object_storage - object on storage cell
* wall_normal - wall cell

Note: I included several rejected skins (Ugly and Uglier) just to demonstrate the program's ability to switch between skins. Outside of this purpose, these 2 skins are fairly worthless...

There are some nice Sokoban skins on the following site, although you will have to rename the files to match the above naming conventions in order to use them:

http://perso.wanadoo.fr/mrbozo/sokoban/ 

Things To Do (in no particular order)

1. Clean up and reorganize the code. tkSokoban was written in haste just "to see if I could". Toward the end of the development, when I wanted to add some of the "nifty" features, I realized that the design (or lack there of) didn't lend itself well to what I wanted. Due to this, some of the code is kind of kludgy and needs to be reworked.

2. Speed up the "findShortestPath" routine. This routine is called recursively and can get somewhat slow if a level contains large empty spaces (although in practice, most levels do not).

3. Add a level editor - this shouldn't be too difficult...

4. Flood fill the interior of the map before rendering it. Some of the available levels are created somewhat strangely (IMHO). That is, a SPACE is supposed to represent an EMPTY cell in the map, but many of the maps also use a SPACE as padding outside the map walls. See "level108" as an example. This causes the renderer to draw empty cells OUTSIDE the map walls. Although this doesn't really cause any problems, I think it looks bad. Flood filling the empty cells of the map's interior with a different character prior to rendering would avoid the problem altogether.

5. Maintain some solved level information - what levels have been solved, the move and push counts, etc...

(Partially completed in this version by Keith Vetter)

6. Maintain some "state" information between invocations (current level, current skin, etc...)

(Partially completed in this version)
