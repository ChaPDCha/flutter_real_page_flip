# Page-Flip Animation Math & Logic Verification Guide

This document describes the mathematical and logical formulations used to simulate the 2.5D page-flip effect in `real_page_flip`. It covers both **1-page (Single Page)** and **2-page (Dual Spread)** layouts for both **Next Page (Forward)** and **Previous Page (Backward)** transition directions.

Use this document to verify the mathematical soundness, boundary conditions, and coordinate symmetries of the page flip engine using an external AI.

---

## 1. System Input Variables & Definitions

Let the viewport size be defined by:
* $W$: Viewport Width (`size.width`)
* $H$: Viewport Height (`size.height`)

Let the single page width be defined by $W_{page}$:
* For Single Page (1단보기): $W_{page} = W$
* For Dual Spread (2단보기): $W_{page} = \frac{W}{2}$

Let the central spine X-coordinate be:
* $X_{spine}$: $0.0$ for Single Page, $\frac{W}{2}$ for Dual Spread.

The animation state is defined by:
* $g$: Raw animation/drag progress, where $g \in [0.0, 1.0]$.
* $isForward$: Boolean indicating next page transition (true) or previous page transition (false).
* $isDoubleSpread$: Boolean indicating dual spread layout (true) or single page layout (false).
* $T = (T_x, T_y)$: The local touch offset coordinate where the user interacts with the screen (`touchOffset`).

### Progress Mapping ($p$)
To handle forward and backward directions symmetrically, the visual progress parameter $p$ is mapped from the raw gesture progress $g$ as follows:
$$p = \begin{cases} 
      g & \text{if } isForward \text{ is true} \\
      1.0 - g & \text{if } isForward \text{ is false}
   \end{cases}$$
* $isForward = \text{true}$ (Next Page): $p$ starts at $0.0$ (no turn) and grows to $1.0$ (turn completed).
* $isForward = \text{false}$ (Prev Page): $p$ starts at $1.0$ (fully turned to the right) and decreases to $0.0$ (lands back to the left).

---

## 2. Derivations by View Mode and Direction

The page flip consists of a crease/fold line located at $X_{fold}$, and a curling page flap of visible width $W_{flap}$ extending to either the left or right of the fold line.

### Case 2.1: Single-Page (1단보기) — Forward & Backward
In single-page mode, $isDoubleSpread = \text{false}$ and $W_{page} = W$.
* **Flap Side**: The turning page flap is always on the left side of the fold line. Thus:
  $$\text{flapRightOfFold} = \text{false}$$

#### A. Forward (Next Page)
As the user drags right-to-left:
* Raw progress $g$ goes $0.0 \to 1.0$, so $p$ goes $0.0 \to 1.0$.
* The fold line starts at the right edge and moves to the left edge:
  $$X_{fold}(p) = W - W_{page} \cdot p = W(1.0 - p)$$
* The material width of the flap (how much page has peeled away) grows:
  $$W_{material}(p) = W_{page} \cdot p = W \cdot p$$
* The flap extends to the **left** of $X_{fold}$, from $X_{fold} - W_{flap}$ to $X_{fold}$.

#### B. Backward (Previous Page)
As the user drags left-to-right:
* Raw progress $g$ goes $0.0 \to 1.0$, so $p$ goes $1.0 \to 0.0$.
* The fold line starts at the left edge and moves to the right edge:
  $$X_{fold}(p) = W - W_{page} \cdot p = W(1.0 - p)$$
  *(Since $p$ goes $1.0 \to 0.0$, $X_{fold}$ goes $0.0 \to W$)*
* The material width of the flap shrinks as the previous page lands on the right side:
  $$W_{material}(p) = W_{page} \cdot p = W \cdot p$$
  *(Since $p$ goes $1.0 \to 0.0$, $W_{material}$ shrinks $W \to 0$)*
* The flap extends to the **left** of $X_{fold}$, sweeping the new page in from the left.

---

### Case 2.2: Dual-Spread (2단보기) — Forward & Backward
In dual-spread mode, $isDoubleSpread = \text{true}$ and $W_{page} = \frac{W}{2}$.

#### A. Forward (Next Page)
The user turns the right page over to the left side (like reading a book).
* Raw progress $g$ goes $0.0 \to 1.0$, so $p$ goes $0.0 \to 1.0$.
* The flap is on the left side of the fold line (peeling towards the spine):
  $$\text{flapRightOfFold} = \text{false}$$
* The fold line starts at the right viewport edge and moves leftwards to the spine:
  $$X_{fold}(p) = W - W_{page} \cdot p = W - \frac{W}{2} \cdot p$$
  *(At $p=0.0$, $X_{fold} = W$; at $p=1.0$, $X_{fold} = \frac{W}{2}$ (spine))*
* The material width of the flap grows:
  $$W_{material}(p) = W_{page} \cdot p = \frac{W}{2} \cdot p$$
* Left edge of the flap (free edge) is:
  $$X_{free} = X_{fold} - W_{flap}$$
  *(At $p=1.0$, $X_{fold} = \frac{W}{2}$ and $W_{flap} \approx \frac{W}{2}$, so the free edge ends at $0.0$, the far left of the viewport)*

#### B. Backward (Previous Page)
The user turns the left page over to the right side.
* Raw progress $g$ goes $0.0 \to 1.0$, so $p$ goes $1.0 \to 0.0$.
* The flap is on the right side of the fold line (peeling from left to right):
  $$\text{flapRightOfFold} = \text{true}$$
* The fold line starts at the left edge and moves rightwards to the spine:
  $$X_{fold}(p) = W_{page} \cdot (1.0 - p) = \frac{W}{2} \cdot (1.0 - p)$$
  *(Since $p$ goes $1.0 \to 0.0$, $X_{fold}$ goes $0.0 \to \frac{W}{2}$ (spine))*
* The material width of the flap starts fully peeled and shrinks as it lands on the right:
  $$W_{material}(p) = W_{page} \cdot (1.0 - p) = \frac{W}{2} \cdot (1.0 - p)$$
  *(Since $p$ goes $1.0 \to 0.0$, $W_{material}$ goes $\frac{W}{2} \to 0$)*
* The flap extends to the **right** of $X_{fold}$, meaning:
  $$X_{free} = X_{fold} + W_{flap}$$
  *(At $p=1.0$, $X_{fold} = 0$ and $W_{flap} \approx \frac{W}{2}$, so the free edge starts at $\frac{W}{2}$ (spine) and moves to $W$ as $p \to 0.0$)*

---

## 3. Mathematical Calculations & Hinge Transform

### 3.1 Angle Calculation & Limits
To simulate the tilt of the page as the user drags up or down, a rotation angle $\theta$ (in radians) is calculated based on the vertical position of the touch relative to the viewport height $H$, scaled by an empirical constant $k_{angle} = 0.30$ (approx. $17^\circ$ max tilt):
$$\theta_{base}(p) = \left(\frac{T_y}{H} - 0.5\right) \cdot k_{angle} \cdot \sin(p^{0.82} \cdot \pi)$$

To prevent the flap from breaking physical boundaries (clipping outside the viewport or crossing the spine incorrectly), the rotation angle $\theta$ is clamped using Trigonometric limit bounds:
* Let $w_{flap} = W_{material}(p)$ (width of the flap).
* Let $w_{reveal}$ be the remaining width on the stationary side:
  $$w_{reveal} = \begin{cases} 
        \max(0, X_{fold} - X_{spine}) & \text{if } isForward \text{ is true} \\
        \max(0, W_{page} - X_{fold}) & \text{if } isForward \text{ is false}
     \end{cases}$$
* The angle boundary limits are derived from the right triangle formed by the fold line and the page corners:
  $$\theta_{limit} = \max\left(0, \min\left( \arctan2(w_{flap}, \frac{H}{2}), \arctan2(w_{reveal}, \frac{H}{2}) \right)\right)$$
* The final clamped angle $\theta$ is:
  $$\theta = \begin{cases} 
        0.0 & \text{if } p \le 0.0 \text{ or } p \ge 1.0 \\
        \text{clamp}(\theta_{raw}, -\theta_{limit}, \theta_{limit}) & \text{otherwise}
     \end{cases}$$
  where $\theta_{raw} = -\theta_{base}$ if $\text{flapRightOfFold}$ is true, and $\theta_{raw} = \theta_{base}$ otherwise.

### 3.2 Hinge Transform Matrix
The curling flap is projected onto the canvas using a 2D affine transformation matrix $M$ hinged at the fold line $X_{fold}$:
$$M = T(X_{fold}, \frac{H}{2}) \cdot R(-\theta) \cdot T(-X_{fold}, -\frac{H}{2})$$
where $T(\Delta x, \Delta y)$ is the translation matrix and $R(\phi)$ is the 2D rotation matrix.

Using this transform $M$, the top and bottom endpoints of the fold line and flap free edge are projected from their straight local space coordinates:
$$\mathbf{P}_{fold\_top} = M \cdot \begin{bmatrix} X_{fold} \\ -H \end{bmatrix}, \quad \mathbf{P}_{fold\_bottom} = M \cdot \begin{bmatrix} X_{fold} \\ 2H \end{bmatrix}$$
$$\mathbf{P}_{flap\_top} = M \cdot \begin{bmatrix} X_{free} \\ -H \end{bmatrix}, \quad \mathbf{P}_{flap\_bottom} = M \cdot \begin{bmatrix} X_{free} \\ 2H \end{bmatrix}$$

---

## 4. Curved Paper Simulation & Bezier Meshing

To make the page look like curling paper rather than a flat rotating board, the engine applies:
1. **Foreshortening**: The visible flap width $W_{flap}$ is compressed near mid-flip ($p = 0.5$) using a sine wave profile:
   $$W_{flap}(p) = W_{material}(p) \cdot \left(1.0 - 0.30 \cdot \sin(p \cdot \pi)\right)$$
2. **Bezier Curvature**: A quadratic Bezier curve is applied to the fold line and flap edge:
   * Peak curvature amount: $C(p) = \sin(p \cdot \pi)$
   * Curve direction multiplier: $d_{dir} = -1.0$ if $\text{flapRightOfFold}$ is true, else $1.0$.
   * Control offset: $\delta_{curve} = C(p) \cdot W_{page} \cdot 0.04 \cdot d_{dir}$
   * Control points in global space:
     $$\mathbf{C}_{fold} = M \cdot \begin{bmatrix} X_{fold} - \delta_{curve} \\ \frac{H}{2} \end{bmatrix}, \quad \mathbf{C}_{flap} = M \cdot \begin{bmatrix} X_{free} - \delta_{curve} \\ \frac{H}{2} \end{bmatrix}$$
3. **Bulging Vertex Mesh**: A triangle grid is built between the fold line and the flap edge. To simulate a 3D cylindrical surface bulge, interior grid columns $s \in [0, 1]$ receive an amplified curve offset:
   $$\text{bulge}(s) = \sin(s \cdot \pi) \quad \text{for } s \in [0, 1]$$
   $$\delta_{col}(s) = \delta_{curve} \cdot (1.0 + 0.30 \cdot \text{bulge}(s))$$
   The column X-coordinates are interpolated as:
   $$X_{col}(s, y) = X_{fold}(y) + \left( X_{flap}(y) - X_{fold}(y) \right) \cdot s$$
   This ensures that the center of the curling page bulges outwards more than the clamped edges.

---

## 5. Layer Composition & Clipping

To render the page-flip without visual seams or overlaps, the screen is split into three layers:
* **Layer 1 (Bottom Layer)**: The new page being revealed.
  * Clipped to the right of the fold line (for forward flips): $\text{ClipPath} = \text{OpenPageClipPath}$.
* **Layer 2 (Middle Layer)**: The current page which is stationary.
  * Clipped to the left of the fold line: $\text{ClipPath} = \text{StationaryPageClipPath}$.
* **Layer 3 (Flap Layer)**: The turning page flap itself, drawn on top using the vertex mesh.
  * Clipped to the region between the fold line and the flap edge.

### Overlapping Bleed ($d_{bleed} = 1.5\text{ px}$)
Due to anti-aliasing in rasterization engines, placing two clipped paths edge-to-edge results in a 1-pixel semi-transparent gap (white seam). The engine fixes this by shifting the clip boundaries along the X-axis:
* Layer 2 (Stationary) uses positive shift: $X'_{fold\_top} = X_{fold\_top} + d_{bleed}$
* Layer 1 (Open/Revealed) uses negative shift: $X'_{fold\_top} = X_{fold\_top} - d_{bleed}$
This causes Layer 1 and Layer 2 to overlap by exactly $3\text{ px}$ along the fold line seam, eliminating rendering gaps.

---

## 6. Verification Questions for the Reviewer AI

When submitting these files to another AI for validation, ask it to analyze and answer the following questions:

1. **Boundary Values Verification ($p \to 0.0$ and $p \to 1.0$)**:
   * Does $X_{fold}(p)$ land exactly on the correct physical coordinates ($0.0$, $W_{page}$, $\frac{W}{2}$, or $W$) at both ends without any rounding errors?
   * Does the rotation angle $\theta$ reduce smoothly to $0.0$ at the boundaries? Is there any discontinuity or division by zero in the angle limit calculation $\theta_{limit}$?

2. **Symmetry & Direction Inversion**:
   * Is the transformation logic for Backward Dual Spread ($isDoubleSpread = \text{true}, isForward = \text{false}$) mathematically symmetric to the Forward Dual Spread?
   * Specifically, verify if the coordinate calculations for $X_{fold}$ and the direction of the flap ($flapRightOfFold$) result in an identical speed profile and mirror-image trajectory.

3. **Angle Clamping and Trigonometric Bounds**:
   * Verify the formula: $\theta_{limit} = \max(0, \min( \arctan2(w_{flap}, \frac{H}{2}), \arctan2(w_{reveal}, \frac{H}{2}) ))$. 
   * Does this physically prevent the flap corner points from clipping outside the viewport boundaries or crossing over the spine boundary?
   * Does using $\frac{H}{2}$ inside $\arctan2$ correctly assume the maximum vertical distance from the center hinge to the top/bottom boundary?

4. **Curvature Offset Signs**:
   * Verify if the sign of $\delta_{curve}$ (derived from $d_{dir}$) is correct for all four cases (1단/2단 $\times$ 이전/다음). Does the curl bend *away* from the destination page in all scenarios, or does it bend inwards (imploding the page)?

5. **Overlap and Clipper Match**:
   * Verify the overlap logic in Section 5. Does the choice of sign ($+d_{bleed}$ for stationary, $-d_{bleed}$ for open) guarantee an overlap regardless of whether the flap is on the left or right of the fold? Or does it depend on $isForward$?

---

## 7. Reference Source Code Locations

You can examine the raw source code implementations in the `sources/` subdirectory:
1. Core Geometry Calculations: [`sources/page_flip_geometry.dart`](file:///h:/Automation/Sharebible/flutter_real_page_flip/doc/math_verification/sources/page_flip_geometry.dart)
2. Clipping & Mesh Grid Generation: [`sources/page_flip_engine.dart`](file:///h:/Automation/Sharebible/flutter_real_page_flip/doc/math_verification/sources/page_flip_engine.dart)
3. Gesture/Drag-to-Progress mapping: [`sources/page_flip_state_controller.dart`](file:///h:/Automation/Sharebible/flutter_real_page_flip/doc/math_verification/sources/page_flip_state_controller.dart)
