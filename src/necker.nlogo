;; A lot of this code is from the "Artificial Neural Net - Perceptron"
;; model that comes with NetLogo.  I'll be removing or replacing most
;; of that code as time goes on.

;; My contributions to this file are copyright 2020 Marshall Abrams
;; under GPL 3.0.
;;
;; The older code is copyright 2006 Uri Wilensky.
;; See the Info tab for details of the license for that code.

globals [
  epoch-error   ;; average error in this epoch
  perceptron    ;; a single output-node
  input-node-1  ;; keep the input nodes in globals so we can refer
  input-node-2  ;; to them directly and distinctly

  ;; marshall
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
]

links-own [ weight ] ; links between nodes

;; "neurons"
breed [ nodes node ]
nodes-own [activation prev-activation]

;; as turtles, these don't do anything, but it's useful to have a
;; data structure to organize nodes
breed [cubes cube]
cubes-own [front-upper-left front-upper-right back-upper-left back-upper-right
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
  update-from-toggles
  ;ask perceptron [ compute-activation ]
  reset-ticks
end

;; marshall
to go
  update-from-toggles
  settle-network
  if settled? [stop]
  tick
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Miscellaneous setup and go procedures

to setup-constants
  set bg-color white
  set-default-shape links "straight-no-arrow" ; this makes directed links look undirected
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
  set surface-fill-color 9.7
  set front-label-color black
  set base-link-thickness 2
  set min-activation-change 0.0001
  set negative-link-weight -1       ; if equal size, paradoxical perceptions are possible
  set positive-link-weight (2 / 3)  ; abs val needs to be less than for neg link weight
  ; "For purposes of this example, the strengths of connections have been arranged so that two negative inputs
  ; exactly balance three positive inputs." (p. 10 in Rumelhart et al.--see Info tab)

end

to update-from-toggles
  ifelse show-negative-links
    [ ask links with [weight < 0] [show-link] ]
    [ ask links with [weight < 0] [hide-link] ]

  ifelse show-nodes
    [ ask nodes [show-turtle] ]
    [ ask nodes [hide-turtle] ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Code to run the network

to settle-network
  ask nodes [
    let asking-node self
    ask my-links [
      ask other-end [
        ;print [weight] of myself ; DEBUG
        set prev-activation activation
        let new-val activation + ( 1 * ([weight] of myself) * ([activation] of asking-node) ) + 0.0001
        set activation max (list -1 (min (list 1 new-val)))
      ]
    ]
    update-node-color self
  ]
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
      link-across-cubes ([front-nodes-lis] of self) ([front-nodes-lis] of myself)
      link-across-cubes ([back-nodes-lis] of self)  ([back-nodes-lis] of myself)
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

;; marshall
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

;; marshall
to-report create-a-node [x y]
  let new-node "dummy-val"
  hatch-nodes 1 [
    set activation (random-float 2) - 1
    update-node-color self
    set size 15
    setxy x y
    set new-node self
  ]
  report new-node
end

;; marshall
to update-node-color [a-node]
  ask a-node [set color (rgb (255 * (- activation)) (175 * activation) (255 * activation))]
end


;; marshall
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

;; marshall
;; apparently, the order of node creation and not order of link creation determines what links are on top of others
to link-cube-nodes
  ;; back links
  ask back-upper-left   [create-link-with ([back-upper-right] of myself)  [setup-positive-back-link]]
  ask back-upper-right  [create-link-with ([back-lower-right] of myself)  [setup-positive-back-link]]
  ask back-lower-right  [create-link-with ([back-lower-left] of myself)   [setup-positive-back-link]]
  ask back-lower-left   [create-link-with ([back-upper-left] of myself)   [setup-positive-back-link]]

  ;; mid (front-back) links
  ask front-upper-left  [create-link-with ([back-upper-left] of myself)   [setup-positive-mid-link]]
  ask front-upper-right [create-link-with ([back-upper-right] of myself)  [setup-positive-mid-link]]
  ask front-lower-right [create-link-with ([back-lower-right] of myself)  [setup-positive-mid-link]]
  ask front-lower-left  [create-link-with ([back-lower-left] of myself)   [setup-positive-mid-link]]

  ;; front links
  ask front-upper-left  [create-link-with ([front-upper-right] of myself) [setup-positive-front-link]]
  ask front-upper-right [create-link-with ([front-lower-right] of myself) [setup-positive-front-link]]
  ask front-lower-right [create-link-with ([front-lower-left] of myself)  [setup-positive-front-link]]
  ask front-lower-left  [create-link-with ([front-upper-left] of myself)  [setup-positive-front-link]]
end

;; marshall
to setup-positive-link
  set weight positive-link-weight
  set thickness base-link-thickness
end

;; GET RID OF THIS CODE
to setup-positive-back-link
  setup-positive-link
  set color pos-link-back-color
end

;; marshall
to setup-positive-mid-link
  setup-positive-link
  set color pos-link-mid-color
end

;; marshall
to setup-positive-front-link
  setup-positive-link
  set color pos-link-front-color
end

;; marshall
to setup-negative-link
  set weight negative-link-weight
  set color item (random num-neg-link-colors) neg-link-colors ; neg links are hard to distinguish, so vary colors
  set thickness (base-link-thickness / 2)
  ;set shape "curve-up-no-arrow"
end

;; marshall
to link-across-cubes [l-cube-lis r-cube-lis]
  (foreach l-cube-lis r-cube-lis
    [ [l r] -> ask l [create-link-with r
                       [setup-negative-link]
                     ]
    ])
end

;; marshall
to make-back-links-dashed [back-corner-node]
  ask back-corner-node [
    ask my-links [
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
217
9
826
319
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
-300
300
-150
150
1
1
1
ticks
30.0

BUTTON
130
10
205
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
130
50
205
83
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
130
205
163
learning-rate
learning-rate
0.0
1.0
0.5
1.0E-4
1
NIL
HORIZONTAL

SWITCH
221
386
366
419
show-weights?
show-weights?
0
1
-1000

TEXTBOX
5
60
125
78
2. Train perceptron:
11
0.0
0

TEXTBOX
5
20
129
38
1. Setup perceptron:
11
0.0
0

BUTTON
130
90
207
124
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
430
412
615
445
show-negative-links
show-negative-links
0
1
-1000

SWITCH
430
459
565
492
show-nodes
show-nodes
0
1
-1000

@#$#@#$#@
To be revised.

Inspired by "Schemata and Sequential Thought Processes in PDP Models" D. E. Rumelhart, P. Smolensky, J. 1. McClelland and G. E. Hinton, chapter 14 in *Parallel Distributed Processing, Vol. 2: Psychological and Biological Models*, eds. James L. McLelland, David E. Rumelhart.



## WHAT IS IT?

Artificial Neural Networks (ANNs) are computational parallels of biological neurons. The "perceptron" was the first attempt at this particular type of machine learning.  It attempts to classify input signals and output a result.  It does this by being given a lot of examples and attempting to classify them, and having a supervisor tell it if the classification was right or wrong.  Based on this information the perceptron updates its weights until it classifies all inputs correctly.

For a while it was thought that perceptrons might make good general pattern recognition units.  However, it was discovered that a single perceptron can not learn some basic tasks like 'xor' because they are not linearly separable.  This model illustrates this case.

## HOW IT WORKS

The nodes on the left are the input nodes. They can have a value of 1 or -1.   These are how one presents input to the perceptron.  The node in the middle is the bias node.  Its value is constantly set to '1' and allows the perceptron to use a constant in its calculation.  The one output node is on the right.  The nodes are connected by links.  Each link has a weight.

To determine its value, an output node computes the weighted sum of its input nodes.  The value of each input node is multiplied by the weight of the link connecting it to the output node to give a weighted value.  The weighted values are then all added up. If the result is above a threshold value, then the value is 1, otherwise it is -1.  The threshold value for the output node in this model is 0.

While the network is training, inputs are presented to the perceptron.  The output node value is compared to an expected value, and the weights of the links are updated in order to try and correctly classify the inputs.

## HOW TO USE IT

SETUP will initialize the model and reset any weights to a small random number.

Press TRAIN ONCE to run one epoch of training.  The number of examples presented to the network during this epoch is controlled by EXAMPLES-PER-EPOCH slider.

Press TRAIN to continually train the network.

Moving the LEARNING-RATE slider changes the maximum amount of movement that any one example can have on a particular weight.

Pressing TEST will input the values of INPUT-1 and INPUT-2 to the perceptron and compute the output.

In the view, the larger the size of the link the greater the weight it has.  If the link is red then its a positive weight.  If the link is blue then its a negative weight.

If SHOW-WEIGHTS? is on then the links will be labeled with their weights.

The TARGET-FUNCTION chooser allows you to decide which function the perceptron is trying to learn.

## THINGS TO NOTICE

The perceptron will quickly learn the 'or' function.  However it will never learn the 'xor' function.  Not only that but when trying to learn the 'xor' function it will never settle down to a particular set of weights as a result it is completely useless as a pattern classifier for non-linearly separable functions.  This problem with perceptrons can be solved by combining several of them together as is done in multi-layer networks.  For an example of that please examine the ANN Neural Network model.

The RULE LEARNED graph visually demonstrates the line of separation that the perceptron has learned, and presents the current inputs and their classifications.  Dots that are green represent points that should be classified positively.  Dots that are red represent points that should be classified negatively.  The line that is presented is what the perceptron has learned.  Everything on one side of the line will be classified positively and everything on the other side of the line will be classified negatively.  As should be obvious from watching this graph, it is impossible to draw a straight line that separates the red and the green dots in the 'xor' function.  This is what is meant when it is said that the 'xor' function is not linearly separable.

The ERROR VS. EPOCHS graph displays the relationship between the squared error and the number of training epochs.

## THINGS TO TRY

Try different learning rates and see how this affects the motion of the RULE LEARNED graph.

Try training the perceptron several times using the 'or' rule and turning on SHOW-WEIGHTS?  Does the model ever change?

How does modifying the number of EXAMPLES-PER-EPOCH affect the ERROR graph?

## EXTENDING THE MODEL

Can you come up with a new learning rule to update the edge weights that will always converge even if the function is not linearly separable?

Can you modify the LEARNED RULE graph so it is obvious which side of the line is positive and which side is negative?

## NETLOGO FEATURES

This model makes use of some of the link features.  It also treats each node and link as an individual agent.  This is distinct from many other languages where the whole perceptron would be treated as a single agent.

## RELATED MODELS

Artificial Neural Net shows how arranging perceptrons in multiple layers can overcomes some of the limitations of this model (such as the inability to learn 'xor')

## CREDITS AND REFERENCES

Several of the equations in this model are derived from Tom Mitchell's book "Machine Learning" (1997).

Perceptrons were initially proposed in the late 1950s by Frank Rosenblatt.

A standard work on perceptrons is the book Perceptrons by Marvin Minsky and Seymour Papert (1969).  The book includes the result that single-layer perceptrons cannot learn XOR.  The discovery that multi-layer perceptrons can learn it came later, in the 1980s.

Thanks to Craig Brozefsky for his work in improving this model.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Rand, W. and Wilensky, U. (2006).  NetLogo Artificial Neural Net - Perceptron model.  http://ccl.northwestern.edu/netlogo/models/ArtificialNeuralNet-Perceptron.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2006 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2006 Cite: Rand, W. -->
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
-4.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0

curve-up-no-arrow
-5.0
-0.2 0 0.0 1.0
0.0 1 2.0 2.0
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
