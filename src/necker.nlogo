;; Copyright 2020 Marshall Abrams under GPL 3.0.  See file LICENSE for details.

;; TODO change node update to more closely match what's in the paper?

globals [
  half-square-side ; how far nodes are from center of cube along x, y
  node-shift-x ; how much x shift of four nodes to give the illusion
  node-shift-y ; how much y shift of four nodes to give the illusion
  cube-shift-x ; how much to shift each cube along x from origin
  centering-shift ; how much to shift nodes so pair of cubes appears centered on origin
  left-cube    ; pointer to one cube-network
  right-cube
  bg-color     ; color of background
  pos-link-front-color ; cube links need different colors so we can see what's in front
  pos-link-mid-color
  pos-link-back-color
  neg-link-colors     ; list of possible colors for negative links
  num-neg-link-colors ; how many of them
  surface-fill-color  ; when we paint the back of a cube
  front-label-color   ; color of "front" labeled near front of cube
  base-link-thickness
  positive-link-weight ; needs to be smaller than neg link weight
  negative-link-weight
  min-activation-change ; stop settling if change is < this in all nodes
  default-learning-rate
  default-external-input
]

;; Functionally, all links/constraints will be treated as
;; undirected (or bi-directed), but we need directed links
;; to control curved link shapes so that they don't flip
;; directions randomly.
directed-link-breed [constraints constraint]
constraints-own [weight]

;; "neurons"
breed [nodes node]
nodes-own [activation prev-activation]

;; These don't do much, but it's useful to have a data structure to organize nodes.
breed [cubes cube]
cubes-own [front-upper-left front-upper-right back-upper-left back-upper-right ; nodes
           front-lower-left front-lower-right back-lower-left back-lower-right
           cube-nodes-lis front-nodes-lis back-nodes-lis ; lists
           cube-nodes front-nodes back-nodes] ; agentsets

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Main procedures

to setup
  clear-all
  setup-constants
  ask patches [ set pcolor bg-color ]
  setup-cube-network ; sets left-cube, right-cube
  update-from-ui-controls
  ;ask perceptron [ compute-activation ]
  reset-ticks
end

to go
  settle-network
  update-from-ui-controls ; run after settle-network to get latest weights, and before stopping
  if settled? [stop]
  tick
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Miscellaneous setup and go procedures

to setup-constants
  set bg-color white
  set-default-shape constraints "straight-no-arrow" ; this makes directed links look undirected
  set-default-shape nodes "circle"
  set half-square-side 60
  set node-shift-x 60
  set node-shift-y 60
  set cube-shift-x 135
  set centering-shift -22
  set pos-link-front-color black; 87 ; 94
  set pos-link-mid-color black ; 85 ; 92
  set pos-link-back-color black; 96 ; 90
  set neg-link-colors [14 15 16 24 25 125 126 135] ; neg links are hard to distinguish, so vary colors
  set num-neg-link-colors length neg-link-colors
  set surface-fill-color 9.5
  set front-label-color black
  set base-link-thickness 2
  set min-activation-change 0.00001
  set default-learning-rate 1.00
  set default-external-input 0.00001
  set negative-link-weight -1       ; if equal size, paradoxical perceptions are possible
  set positive-link-weight (2 / 3)  ; abs val needs to be less than for neg link weight
  ; "For purposes of this example, the strengths of connections have been arranged so that two negative inputs
  ; exactly balance three positive inputs." (p. 10 in Rumelhart et al.--see Info tab)

end

to update-from-ui-controls
  ifelse show-neg-links
    [ ask constraints with [weight < 0] [show-link] ]
    [ ask constraints with [weight < 0] [hide-link] ]

  ifelse show-nodes
    [ ask nodes [show-turtle] ]
    [ ask nodes [hide-turtle] ]

  ifelse show-activations
    [ ask nodes [set label (precision activation 2)] ]
    [ ask nodes [set label ""] ]
end

;; reset of UI-controlled parameters to sane defaults
to set-default-params
  set learning-rate default-learning-rate
  set external-input default-external-input
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Code to run the network

to settle-network
  ask nodes [
    let asking-node self
    ask my-constraints [
      ask other-end [
        ;print [weight] of myself ; DEBUG
        set prev-activation activation
        let new-val activation + ( learning-rate * ([weight] of myself) * ([activation] of asking-node) ) + external-input
        set activation max (list -1 (min (list 1 new-val)))
        update-node-color self
      ]
    ]
  ]
end

to update-node-color [a-node]
  ask a-node [set color (rgb (min (list 255 (50 + (255 * (- activation))))) (100 * activation) (min (list 255 (50 + (255 * activation))))) ]
end

to-report settled?
  report all? nodes [ (abs (activation - prev-activation)) < min-activation-change ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Code to set up cube network

to setup-cube-network
  create-cubes 2 [
    set color bg-color ; make the cube turtle icon invisible against background
    set-cube-nodes
    link-cube-nodes
    hide-turtle
  ]

  ;; give the two cubes distinct identities
  set left-cube min-one-of  cubes [who]
  set right-cube max-one-of cubes [who]

  ask left-cube [
    ask front-nodes [setxy (xcor + node-shift-x) (ycor + node-shift-y)] ; add 3D perspective
    ask cube-nodes [set xcor xcor - cube-shift-x] ; separate the cubes
  ]

  ask right-cube [
    ask back-nodes [setxy (xcor + node-shift-x) (ycor + node-shift-y)] ; add 3D perspective
    ask cube-nodes [set xcor xcor + cube-shift-x] ; separate the cubes
  ]

  ask left-cube [
    ask right-cube [
      link-across-cubes ([front-nodes-lis] of self) ([front-nodes-lis] of myself) "straight-no-arrow"
      link-across-cubes ([back-nodes-lis] of self)  ([back-nodes-lis] of myself)  "straight-no-arrow"
      link-across-cubes ([front-nodes-lis] of self) ([back-nodes-lis] of myself)  "curve-down-no-arrow"
      link-across-cubes ([back-nodes-lis] of self)  ([front-nodes-lis] of myself) "curve-up-no-arrow"
    ]
  ]

  ask nodes [setxy (xcor + centering-shift ) (ycor + centering-shift)] ; recenter images

  ask left-cube  [fill-surface surface-fill-color front-lower-left front-upper-right]
  ask right-cube [fill-surface surface-fill-color front-lower-left front-upper-right]

  ask left-cube  [make-back-links-dashed back-upper-right]
  ask right-cube [make-back-links-dashed back-lower-left]

  add-front-label left-cube  15
  add-front-label right-cube -15 - (2 * half-square-side)
end

to add-front-label [a-cube y-offset]
  let ful-x 0
  let fur-x 0
  let y 0

  ask a-cube [
    ask front-upper-left  [set ful-x xcor  set y ycor]
    ask front-upper-right [set fur-x xcor]
  ]

  ;print (list ful-x fur-x y) ; DEBUG

  let label-x ful-x + ( (abs (fur-x - ful-x)) / 2) + 15
  let label-y y + y-offset

  ;print (list label-x label-y) ; DEBUG

  ask patch label-x label-y [
    set plabel-color front-label-color
    set plabel "front"
  ]
end

to-report create-a-node [x y]
  let new-node "dummy-val"
  hatch-nodes 1 [
    set activation (random-float 2) - 1
    ;set activation (random-float 1.2) - 0.6 ; keeping initial vals away from extrema is more interesting
    update-node-color self
    set label-color black
    set size 15
    setxy x y
    set new-node self
  ]
  report new-node
end

;; The back-front angular shift will be done separately
to set-cube-nodes
  ;; the order of node creation determines which links are on top of others
  set back-upper-left   create-a-node  (- half-square-side) half-square-side
  set back-upper-right  create-a-node  half-square-side     half-square-side
  set back-lower-left   create-a-node  (- half-square-side) (- half-square-side)
  set back-lower-right  create-a-node  half-square-side     (- half-square-side)

  set front-upper-left  create-a-node  (- half-square-side) half-square-side
  set front-upper-right create-a-node  half-square-side     half-square-side
  set front-lower-left  create-a-node  (- half-square-side) (- half-square-side)
  set front-lower-right create-a-node  half-square-side     (- half-square-side)

  ;; ordered lists of nodes make some code simpler
  set front-nodes-lis (list front-upper-left front-upper-right front-lower-left front-lower-right)
  set back-nodes-lis  (list back-upper-left  back-upper-right  back-lower-left  back-lower-right)
  set cube-nodes-lis (sentence front-nodes-lis back-nodes-lis)

  ;; but agentsets of nodes are convenient, too
  set front-nodes (turtle-set front-nodes-lis)
  set back-nodes  (turtle-set back-nodes-lis)
  set cube-nodes  (turtle-set cube-nodes-lis)
end

;; apparently, the order of node creation and not order of link creation determines what links are on top of others
to link-cube-nodes
  ;; back links
  ask back-upper-left   [create-constraint-to ([back-upper-right] of myself)  [setup-positive-back-link]]
  ask back-upper-right  [create-constraint-to ([back-lower-right] of myself)  [setup-positive-back-link]]
  ask back-lower-right  [create-constraint-to ([back-lower-left] of myself)   [setup-positive-back-link]]
  ask back-lower-left   [create-constraint-to ([back-upper-left] of myself)   [setup-positive-back-link]]

  ;; mid (front-back) links
  ask front-upper-left  [create-constraint-to ([back-upper-left] of myself)   [setup-positive-mid-link]]
  ask front-upper-right [create-constraint-to ([back-upper-right] of myself)  [setup-positive-mid-link]]
  ask front-lower-right [create-constraint-to ([back-lower-right] of myself)  [setup-positive-mid-link]]
  ask front-lower-left  [create-constraint-to ([back-lower-left] of myself)   [setup-positive-mid-link]]

  ;; front links
  ask front-upper-left  [create-constraint-to ([front-upper-right] of myself) [setup-positive-front-link]]
  ask front-upper-right [create-constraint-to ([front-lower-right] of myself) [setup-positive-front-link]]
  ask front-lower-right [create-constraint-to ([front-lower-left] of myself)  [setup-positive-front-link]]
  ask front-lower-left  [create-constraint-to ([front-upper-left] of myself)  [setup-positive-front-link]]
end

to setup-positive-link
  set weight positive-link-weight
  set thickness base-link-thickness
end

;; GET RID OF THIS CODE
to setup-positive-back-link
  setup-positive-link
  set color pos-link-back-color
end

to setup-positive-mid-link
  setup-positive-link
  set color pos-link-mid-color
end

to setup-positive-front-link
  setup-positive-link
  set color pos-link-front-color
end

to setup-negative-link [link-shape]
  set weight negative-link-weight
  set color item (random num-neg-link-colors) neg-link-colors ; neg links are hard to distinguish, so vary colors
  set thickness (base-link-thickness / 2)
  set shape link-shape
  ;set shape "curve-up-no-arrow"
end

to link-across-cubes [l-cube-lis r-cube-lis link-shape]
  (foreach l-cube-lis r-cube-lis
    [ [l r] -> ask l [create-constraint-to r
                       [setup-negative-link link-shape]
                     ]
    ])
end

to make-back-links-dashed [back-corner-node]
  ask back-corner-node [
    ask my-constraints [
      if weight > 0 [ ; only positive, cube links
        set shape "dashed-no-arrow"
        set thickness (base-link-thickness / 2)
      ]
    ]
  ]
end

to fill-surface [surface-color lower-left-corner-node upper-right-corner-node] ; i.e. kitty-corner node
  let corner-x 0
  let corner-y 0
  let kitty-x 0
  let kitty-y 0
  ask lower-left-corner-node  [set corner-x xcor  set corner-y ycor]
  ask upper-right-corner-node [set kitty-x xcor   set kitty-y ycor]

  ;print (list "corner x" corner-x "y" corner-y "kitty x" kitty-x "y" kitty-y) ; DEBUG

  let x corner-x
  let y corner-y
  while [x < kitty-x] [
    while [y < kitty-y] [
      ask patch-at x y [set pcolor surface-color]
      ;print (list x y) ; DEBUG
      set y y + 1
    ]
    set y corner-y
    set x x + 1
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
175
10
744
300
-1
-1
1.0
1
10
1
1
1
0
0
0
1
-280
280
-140
140
1
1
1
ticks
30.0

BUTTON
5
10
80
43
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
5
45
80
78
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
5
80
165
113
learning-rate
learning-rate
0.0
1.0
1.0
1.0E-4
1
NIL
HORIZONTAL

SWITCH
5
260
152
293
show-activations
show-activations
1
1
-1000

BUTTON
86
45
163
79
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SWITCH
5
225
151
258
show-neg-links
show-neg-links
0
1
-1000

SWITCH
5
190
151
223
show-nodes
show-nodes
0
1
-1000

SLIDER
5
116
166
149
external-input
external-input
0
0.0002
1.0E-5
0.00001
1
NIL
HORIZONTAL

BUTTON
5
152
167
187
restore default parameters
set-default-params
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
(In progress.)



## WHAT IS IT?

This is a simple "constraint satisfaction" neural network model of a perceptual process for interpreting a 2-D image known as a Necker cube as three-dimensional
(https://en.wikipedia.org/wiki/Necker_cube). The model was inspired by a description in "Schemata and Sequential Thought Processes in PDP Models" D. E. Rumelhart, P. Smolensky, J. 1. McClelland and G. E. Hinton, chapter 14 in *Parallel Distributed Processing, Vol. 2: Psychological and Biological Models*, eds. James L. McLelland, David E. Rumelhart.

The pattern of light that comes into the eye and hits the back of the retina is essentially two-dimensional, yet we experience a three-dimensional world.  So our visual system has to reconstruct representation of a three-dimensional world from two-dimensional data.  In a sense, what the visual system is doing is taking two-dimensional data, and using it to construct a "theory" about the structure of the three-dimensional world that light is reflecting off of.  

Various sorts of information in this data gets used by the visual system in our eye, optic nerve, and brain in this process.  The Necker cube illustrations one aspect of this process: they eye sees an object in the world that is literally two-dimensional, but that we tend to experience as three-dimensional.  There are two ways to do this, experiencing a 3-D cube from two different perspectives.  Just before a Necker cube is experienced as three-dimensional, or when the perception of the diagram "flips" from one perspective to another, we can consider the visual system to be entertaining two different hypotheses about the three-dimensional structure represented by the Necker cube figure.

This program models a process by which these two different hypotheses compete with each other.  It is a model of a process by which a visual system might work out a consistent
3-D construction of a cube.


## HOW IT WORKS

### Necker cubes 

First, try turning off the *show-nodes* and *show-neg-links* options on the left side of the NetLogo model, and then click on *setup*.  This shows two Necker cubes, one on the left, and one on the right.  For the moment, try to see each as a two-dimensional drawing, consistneting of lines on the screen.  Each image consists of two overlapping squares, one of which is shifted diagonally from the other, and four diagonal lines connecting the corners of the two squares.  

However, our visual systems tends to see each of these two-dimensional objects as if each was a three-dimensional cube.  There are two different ways that the human visual system turns this kind of two-dimensional object into something that is experienced as cube.  The dashed lines, the label "front", and the shaded front square, the images suggest those two ways of seeing the diagrams.  The left image is supposed to suggest seeing the upper right square as the front of the cube, and the lower parallelogram as its bottom.  The right images is intended to suggest that the lower left square is the front, with the upper parallelogram as the top of the square.  However, the pattern of two overlapping squares with diagonal lines connecting their corners is the same in both of the images.

In order to construct a three-dimensional cube from a two-dimensional diagram (see above), a visual system has to interpret the data from each line and each corner in a way that consistently fits together as a hypothesis about a three-dimensional object.  For example, if the upper right corner of the diagram is the corner of the front surface of a cube, then the corner directly to its left must be the upper left corner of the front of the cube, and the lower left corner of the entire diagram must be the buttom left corner of the back surface of the cube.  So each consistent "hypothesis" about the three-dimensional object represented by the Necker figure can be understood as a series of smaller hypotheses about the locations of corners in space.  These smaller hypotheses have to fit together in a larger perceptual hypothesis.

### Positive constraint links

Now turn on *show-nodes*, and click *setup* again.  The colored circles at the corners of the squares are nodes, or abstract, idealized neurons in a "neural network" model.  The lines of the two Necker cubes now also represent links between these nodes.  

Each node has a number called its *activation*, which is represented in the NetLogo model by color.  Activation values range from -1 to 1.  Red nodes have negative activations, with bright reds representing numbers closer to -1.  Blue nodes have positive activations, with bright blues representing numbers closer to 1.

The links between nodes--i.e. the lines that are also edges of the Necker cubes--allow communication between nodes.  When you click on *go once*, each node will "try" to influence the nodes to which it is linked.  That is, the activation values of nodes that are connected to a node with negative activation will be pushed a little bit toward a lower value, and the nodes that are connected to a node with a positive vaue, with have their activations pushed a little bit higher.  The end result of clicking on *go once* is that each node gets a new activation value that is a sort of average of its old activation value and the activation values of all of the nodes to which it is linked.  (There is more to say, though--see the next sections.)

We call this process "settling" the network.  *go once* causes one step of settling.  Clicking on *go* is like clicking on *go once* repeatedly.  With *go*, the activation values of the nodes will change bit by bit, until they don't change any more, at which point the *go* button will release itself, because the settling process has ended.

### Subnetworks as perceptual hypotheses

The left subnetwok---the one corresponding to the left Necker figure--is supposed to represent the hypothesis that the upper right square in the figure is the front of the cube, and the lower left square (two of whose sides are dashed) represents the back of the cube.

The right subnetwork represents the hypothesis that the lower-right square is the front of the sube, and the upper left square (with two dashed sides) is the back of the cube.

The model "decides" which perceptual hypothesis to adopt as "correct" if all of the nodes in that subnetwork acquire activation (blue) activation values of 1, and if all of the nodes in the other subnetwork acquire (red) activation values of -1.  

We can think of the transmission of influences between connected nodes as pushing each node to adopt the same "hypothesis" as its neighbors.  When the network goes through the settlijng process, nodes with negative activations in effect tell their neighbors, "You should be negative, like me", while nodes with positive activations tell their neighbors, "You should be positive, like me."  When the network settles into a steady state, a consensus has been reached by all of the nodes.

### Negative constraint links

Now set *show-neg-links* on.  *show-nodes* should be on as well.  Click on *setup*.  The colors of nodes will change, because *setup* causes new random activations to be assigned to them. In addition, you should now see a number of red lines connecting nodes in the left subnetwork to nodes in the right subnetwork.

[THIS SECTION IS NOT FINISHED]


## HOW TO USE IT

SETUP sets each node's activation value to a random number between -1 and 1.

GO ONCE performs one iteration of settling--that is, each node's activation value is adjusted due to the influence of the activation values of the nodes to which it is connected, and the weights of the links between nodes.

GO does the same thing as GO ONCE, but does it repeatedly until the activation values of the nodes stop changing significantly.

LEARNING-RATE specifies how much each node influences the nodes to which it is linked.

EXTERNAL-INPUT specifies a small number that is added to activation of each node when it is updated.

RESTORE DEFAULT PARAMETERS resets learning-rate and external-input to default values specified in the code.

The SHOW-NODES and SHOW-NEG-LINKS switches can be used to hide the node circles and negative links, so that you can see the two Necker cubes without visual interference.

SHOW-ACTIVATIONS allows you to see the activation values for each node.  The location of these numbers on the screen is not ideal.  NetLogo makes it a bit difficult to put them in a place that would be easier to read.  (If this is important to you, let me know, and I'll consider fixing the problem.)


## THINGS TO NOTICE

NetLogo shows the number of ticks,, i.e. cycles, that it takes to settle the network.  Notice that this number varies from run to run depending on the initial random activation values.

## THINGS TO TRY

You can slow down or speed up the settling process using NetLogo's speed slider.  This doesn't affect the process, but it might allow you to watch what happens during settling, or to focus on the end result.


## CREDITS AND REFERENCES

As noted above, this model was inspired by a description in "Schemata and Sequential Thought Processes in PDP Models" D. E. Rumelhart, P. Smolensky, J. 1. McClelland and G. E. Hinton, chapter 14 in *Parallel Distributed Processing, Vol. 2: Psychological and Biological Models*, eds. James L. McLelland, David E. Rumelhart.  I started thinking about writing this to help students understand a less detailed description in Keith Holyoak and Paul Thagard's *Mental Leaps: Analogy in Creative Thought*, MIT Press 1995.  I was inspired by a Java applet that A. D. Marshall at Cardiff University had made available on the web previously.  This is no longer available, though--no doubt partly because Java applets are considered obsolete and potentially dangerous.

## COPYRIGHT AND LICENSE

Copyright 2020 by Marshall Abrams.  Released under Gnu Public License version 3.0.
Details can be found at https://www.gnu.org/licenses/gpl-3.0.en.html .
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bias-node
false
0
Circle -16777216 true false 0 0 300
Circle -7500403 true true 30 30 240
Polygon -16777216 true false 120 60 150 60 165 60 165 225 180 225 180 240 135 240 135 225 150 225 150 75 135 75 150 60

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

output-node
false
1
Circle -7500403 true false 0 0 300
Circle -2674135 true true 30 30 240
Polygon -7500403 true false 195 75 90 75 150 150 90 225 195 225 195 210 195 195 180 210 120 210 165 150 120 90 180 90 195 105 195 75

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
resize-world -9 9 -9 9
setup
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 4.0 4.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

curve-down-no-arrow
25.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0

curve-up-no-arrow
-25.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0

dashed-no-arrow
0.0
-0.2 0 0.0 1.0
0.0 1 4.0 4.0
0.2 0 0.0 1.0
link direction
true
0

small-arrow-shape
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 135 180
Line -7500403 true 150 150 165 180

straight-no-arrow
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
@#$#@#$#@
1
@#$#@#$#@
