# Open-source dart detection with three USB cameras

## Problem analysis, technical approach and first implementation plan

**As of:** 23 October 2026\
**Goal:** Build an open-source automatic dart detection whose impact position is more precise than that of the solution currently in use.

---

## 1. Summary

The central recommendation: **build our own computer-vision detection engine and use existing open-source projects as technical references and possible integration bases.** Do not fork a complete existing project early and adopt its detection architecture.

The main technical bottleneck is not general dart-app functionality but the **geometrically correct localisation of the dart tip and the impact position derived from it**. The current method is based on frame differencing before and after the throw. The three USB cameras run independent streams; their synchronisation has not been examined yet.

This leads to three priority tasks:

1. Build a reproducible benchmark of annotated throws with ground truth.
2. Measure time offset, jitter and frame drops of the three cameras.
3. Compare single-camera projection and multi-camera triangulation on the same test data before fixing the architecture.

Scoring code must be separated from geometric detection. Detection must be able to return a board point with its uncertainty and diagnostic information instead of only a score.

---

## 2. Starting point and requirements

### 2.1 Known constraints

- Three USB cameras.
- Current detection by frame differencing between images before and after the throw.
- Main error: geometrically wrong dart tip, and therefore wrong impact position.
- Camera synchronisation: independent streams; offset and jitter have not been examined.
- The developer's technical background:
  - OpenCV
  - intrinsic and extrinsic camera calibration
  - projections
  - object detection
  - DMTX, ArUco and ChArUco
- Online multiplayer is a long-term interest but not the first development priority.
- The goal is a more precise, traceable and extensible open-source solution.

### 2.2 Out of focus

OpenCV and camera calibration basics do not need to be worked out again. The technical focus is on:

- precise dart tip localisation
- temporal association of frames
- robust multi-camera fusion
- board-plane geometry and impact point
- uncertainty estimation
- reproducible measurement of detection quality

---

## 3. Problem analysis

### 3.1 Frame differencing does not automatically yield the tip

A difference mask shows changed image regions, not necessarily the physical tip. It can contain the shaft, shadows, reflections, wire, lighting changes and darts that are already in the board.

The outermost mask pixel or a contour end is therefore not reliable enough to be used unchecked as the impact point.

**Consequence:** keep frame differencing as an event and candidate generator for now. Tip localisation is a separate, measurable step.

### 3.2 Unsynchronised cameras can corrupt fusion

With independent USB streams, the selected frames can represent different points in time. The dart moves during a throw, so image points from different cameras cannot simply be treated as simultaneous observations.

To be examined:

- constant time offset between cameras
- temporal jitter
- capture timestamps versus host arrival time
- frame drops and irregular frame rates
- buffering and queue latency

A common host timestamp on arrival does not guarantee synchronisation at exposure level. If no device-side capture timestamps are available, this limitation must be documented and characterised experimentally.

### 3.3 Correct calibration does not guarantee a correct tip

Even with good intrinsic and extrinsic parameters, a wrong image point can be projected or triangulated. A small pixel or calibration error can also cause a relevant error in board coordinates, depending on the viewing angle.

At least three error types must therefore be considered separately:

1. **Image error:** the wrong tip was localised in the image.
2. **Geometry error:** a correct image point is transferred incorrectly into board coordinates.
3. **Fusion error:** non-corresponding or temporally incompatible measurements are combined.

### 3.4 Score accuracy alone is not enough for diagnosis

An impact point can be noticeably wrong inside a wide segment without changing the score. Conversely, a small position error near a wire can change the score.

The primary geometric metric is therefore the position error in millimetres. Segment and multiplier accuracy remain important end metrics.

---

## 4. Proposed architecture

```text
Three USB cameras
       |
       v
Capture per camera
timestamp, frame ID, drop counter, ring buffer
       |
       v
Throw event / time window
baseline before the throw + difference masks
       |
       v
Tip candidates per camera
pixel position, shaft axis, confidence, covariance
       |
       v
Temporal association and geometric plausibility check
       |
       +-----------------------+
       |                       |
       v                       v
Board projection          3D triangulation
per camera                from corresponding measurements
       |                       |
       +-----------+-----------+
                   |
                   v
Robust fusion / uncertainty check
                   |
                   v
Board coordinates in mm
                   |
                   v
Deterministic scorer
                   |
                   v
Score + confidence + diagnostics
```

### Guiding principles

- Implement detection, geometry and scoring separately.
- Every output can be traced back to the frames and candidates it is based on.
- Uncertain results may be rejected instead of always forcing a score.
- All experiments are reproducible on recorded frames.
- UI and online multiplayer can be integrated later through a stable interface.

---

## 5. Technical approach

### 5.1 Capture and timing

Store at least the following per frame:

- `camera_id`
- sequential `frame_id`
- monotonic capture time, if available
- host arrival time
- effective FPS
- frame drop counter
- exposure time and gain, if accessible
- associated `throw_id` and event window

Each camera gets its own capture thread and a bounded ring buffer. Under overload, old frames are dropped in a controlled way instead of building unbounded queues.

The time difference between camera $i$ and camera $j$ is

$$\Delta t_{ij} = t_i - t_j$$

Evaluate median, standard deviation and high percentiles of the absolute time offset per camera pair. Consider the constant offset separately from the jitter.

**Experiment:** record an event with known timing that all cameras can see, for example an LED switching pattern or a fast-moving marker. Repeat the measurement over longer run times and under system load.

### 5.2 Tip candidates per camera

The existing difference mask stays for now. A candidate pipeline is built behind it:

1. Use several frames before the throw as a robust reference.
2. Create the difference mask and candidate regions.
3. Analyse components and linear structures.
4. Estimate the shaft axis, for example with PCA as initialisation and a robust line fit.
5. Create several tip candidates from contour end points, skeleton end points and axis end points.
6. Rate candidates by image features, mask stability, line fit and geometric consistency.

A candidate has more than a pixel position, for example:

```text
camera_id
capture_timestamp
tip_candidates[]
  - pixel_xy
  - covariance_2x2
  - confidence
shaft_line
mask_quality
```

The covariance describes how uncertain the pixel position is. An occluded or blurred tip gets less weight in fusion than a clear measurement.

PCA and skeletonisation are only candidate generators. They do not guarantee that the detected line end is the physical tip. A neural detector is a possible later extension, but it should first be tested against the classical pipeline on annotated hard cases.

### 5.3 Compare board projection and triangulation

Both approaches are evaluated on the same labelled throws. Do not assume in advance that one of them is fundamentally better.

**Approach A: board projection**

For a visible tip, the calibrated camera ray is intersected with the known board plane. The result is converted to local board coordinates.

Advantages:

- simple and fast
- no 3D point correspondence across cameras needed
- can be diagnosed separately per camera

Risks:

- pixel and calibration errors can be amplified in board coordinates
- wrong image points lead to wrong impact positions

**Approach B: multi-camera triangulation**

Temporally corresponding image points are triangulated. Then the distance to the board plane and the reprojection errors are checked.

For camera $i$:

$$r_i = \left\lVert \mathbf{u}_i - \pi_i(\hat{\mathbf{X}}) \right\rVert_2$$

where $\mathbf{u}_i$ is the observed image point, $\pi_i$ the calibrated projection function and $\hat{\mathbf{X}}$ the reconstructed 3D point.

Advantages:

- additional geometric redundancy
- contradictory measurements can be detected

Risks:

- time offset between frames
- unfavourable triangulation angles
- wrong point correspondences
- calibration errors

A low reprojection error alone does not prove that the correct tips were matched. Large inconsistencies must not simply be hidden by projecting onto the board plane.

**Variants to compare:**

1. best single-camera projection
2. weighted fusion of the board projections
3. triangulation with the current frame association
4. triangulation with the best possible temporal frame association
5. robust fusion with outlier handling and an abstain option

### 5.4 Fusion and uncertainty

For each throw:

1. Associate candidates in time.
2. Discard geometrically incompatible combinations.
3. Evaluate reprojection error and distance to the board plane.
4. Weight measurements by their uncertainty.
5. Estimate robustly and handle outliers.
6. Output impact point, uncertainty and diagnostic values.

Fusion must be able to report "uncertain" when in doubt. The acceptance threshold is set from the validation data.

### 5.5 Deterministic scoring

The scoring component receives a board point in millimetres and converts it deterministically into sector and ring. It can be tested separately, without processing camera images.

This cleanly separates two cases:

- The position was estimated wrongly.
- The position is correct but was converted into a wrong score.

For points near wires, the geometric uncertainty and the distance to the segment boundary are available in the diagnostics.

---

## 6. Metrics and preliminary targets

### 6.1 Core metrics

| Metric | Definition / purpose |
| ------ | -------------------- |
| Radial position error | $e = \lVert \hat{\mathbf{p}} - \mathbf{p}^* \rVert_2$, in mm |
| Median, P90, P95 of the error | Typical error and tail risk |
| Segment accuracy | Correctly detected number sector |
| Multiplier accuracy | Correct single/double/triple/bull assignment |
| False acceptance rate | Wrong results among accepted throws |
| Abstention rate | Share of throws without an automatic result |
| Detection latency | Time from throw event to result, P50/P95 |
| Frame drop rate | Missing frames per camera |
| Inter-camera timing error | Offset and jitter between streams |
| Replay reproducibility | Identical results for identical input and configuration |

In addition, analyse the error in radial and tangential direction, and report results for throws near sector and ring boundaries separately.

### 6.2 Preliminary targets

These values are project targets for orientation, not guaranteed results. After the first benchmark they are reviewed against the ground-truth quality and the actual error distribution.

| Metric | Early target | Ambitious target |
| ------ | -----------: | ---------------: |
| Radial error P95 | ≤ 3 mm | ≤ 1.5 mm |
| Segment accuracy | ≥ 97 % | ≥ 99 % |
| Multiplier accuracy | ≥ 97 % | ≥ 99 % |
| Replay reproducibility | 100 % identical results | 100 % identical results |

False acceptance rate and abstention rate are always reported together. A system can raise its accuracy artificially by rejecting many hard throws.

---

## 7. Experiment plan

### Experiment 1: time offset and frame selection

**Goal:** check whether asynchronous streams impair geometric fusion.

- Record a timing reference event with all cameras.
- Determine offset, jitter and frame drops.
- Visualise timestamps and tip candidates of real throws on a common time axis.
- Compare fusion with the current frame selection against the best possible temporally associated frames.

**Success criterion:** a quantified relationship between temporal association and position error.

### Experiment 2: ground truth and single-camera error

**Goal:** separate image localisation errors from projection errors.

- A few hundred carefully selected and annotated throws as the first benchmark.
- Evaluate tip pixel, board projection and error in millimetres per camera.
- Record the distance to the nearest segment or ring boundary.
- Record annotation uncertainty explicitly.

**Success criterion:** for each camera it is known in which situations its measurement is reliable.

### Experiment 3: projection path versus triangulation

**Goal:** choose the most robust geometric method empirically.

Evaluate all fusion variants on exactly the same throws. Compare median/P95 of the millimetre error, segment and multiplier accuracy, false acceptance rate and abstention rate.

**Success criterion:** a traceable architecture decision based on measured data instead of assumptions.

### Experiment 4: better tip candidates

**Goal:** check whether better candidates actually reduce the errors.

Ablations:

- current difference mask
- difference mask plus robust shaft axis
- difference mask plus skeleton/contour end points
- combination of candidate features and geometric rating

Measure candidate recall and tip error separately.

**Success criterion:** a demonstrable gain on hard cases, not only in the aggregate mean.

### Experiment 5: robustness

Separate test groups for:

- proximity to wires and segment boundaries
- bull and bullseye
- double and triple rings
- darts already in the board
- occluded tips
- reflections and lighting changes
- longer sessions and system load

**Success criterion:** critical failure cases become visible and are not hidden by a good overall value.

### Dataset split

Split data by sessions or recording series, not randomly by frames. Nearly identical frames from the same recording must not end up in both training and test in an uncontrolled way. Keep an untouched hold-out test set until the final evaluation.

---

## 8. Software structure and diagnostics

Modules:

- `capture`: camera threads, timestamps, ring buffers and drop monitoring
- `event_detection`: throw event and time window
- `tip_candidates`: candidate generation and local tip rating
- `geometry`: board plane, projection, triangulation and reprojection error
- `fusion`: temporal association, robust estimation and abstention
- `scoring`: deterministic mapping from board point to score
- `replay`: reproducible offline evaluation
- `benchmark`: metrics, group analyses and regression tests

Per throw, store at least the source frame IDs, timestamps, candidates, confidences, fusion residuals, board point, score and run times.

The engine's interface returns more than a score, for example:

```text
throw_id
board_xy_mm
position_covariance
score
confidence
accepted
camera_measurements[]
diagnostics
processing_latency_ms
```

The concrete data format can later be JSON, Protobuf or an internal struct. What matters is a clear separation of responsibilities and the ability to inspect measurements afterwards.

---

## 9. Fork an existing project or build our own?

### Recommendation

**Build our own detection engine and use existing projects as technical references and possible integration bases.**

Do not fork a complete project right away and adopt its CV architecture.

Reasons:

- The core advantage of the project is a demonstrably more precise impact position.
- The pipeline must be measurable and changeable in a targeted way.
- A new engine allows clean replay tests and a clear separation between image detection, geometry, fusion and scoring.
- Existing UI and multiplayer functions can be integrated later if they fit technically and legally.

### Projects to examine

- **OpenDartboard:** https://github.com/OpenDartboard/OpenDartboard
- **ThrowVision:** https://github.com/kashiwagiren/ThrowVision
- **InstaDarts:** https://github.com/Instadarts/instadarts

These projects are starting points for a technical review, not proof that their detection meets our requirements. Before adopting code, check current activity, architecture, interfaces, dependencies and license terms directly in the repository.

### Possible integration strategy

1. Implement our own CV backend with a stable API.
2. Examine existing projects for usable camera, UI, network or multiplayer components.
3. Adopt components only if they clearly save time and do not restrict the architecture unnecessarily.
4. Check license obligations and compatibility before adopting code.
5. Prioritise online multiplayer only after a reliable detection benchmark exists.

---

## 10. First implementation plan

The phases are tracked as milestones in [ROADMAP.md](../ROADMAP.md).

### Phase 1 – Measurability

- [ ] Capture three cameras with frame IDs and timestamps.
- [ ] Log frame drops, effective FPS and queue latency.
- [ ] Introduce a replay format and throw ID.
- [ ] Create annotations for a first benchmark.
- [ ] Define board coordinates and the ground-truth convention.
- [ ] Compute baseline metrics for the current pipeline.

**Result:** a reproducible baseline that describes the current state quantitatively.

### Phase 2 – Synchronisation and geometry

- [ ] Measure time offset and jitter.
- [ ] Evaluate single-camera projections.
- [ ] Test triangulation on temporally associated measurements.
- [ ] Log reprojection error and board-plane distance.
- [ ] Break errors down by camera, board region and difficulty.

**Result:** a well-founded decision on time association and the geometry path.

### Phase 3 – Better tip localisation

- [ ] Produce candidate lists instead of a single point.
- [ ] Compare shaft-axis and end-point methods.
- [ ] Introduce confidence and position covariance.
- [ ] Annotate robustness cases specifically.
- [ ] Optionally evaluate a specialised detector if classical candidates are insufficient.

**Result:** measurably better tip localisation, or a clearly documented remaining bottleneck.

### Phase 4 – Robust fusion and scoring

- [ ] Discard temporally and geometrically incompatible candidates.
- [ ] Implement uncertainty-weighted robust fusion.
- [ ] Set the abstention threshold from the validation set.
- [ ] Test scoring independently of the CV pipeline.
- [ ] Set up regression tests for known hard throws.

**Result:** a verifiable engine with traceable quality indicators.

### Phase 5 – Product integration

- [ ] Stabilise the API and event model.
- [ ] Check a UI or existing dart platform for integration.
- [ ] Connect online multiplayer as needed.
- [ ] Define license and documentation requirements.
- [ ] Publish a release benchmark and a collection of failure cases.

**Result:** a modular open-source solution whose precision is backed by a repeatable benchmark.

---

## 11. Risks and open questions

### Technical risks

- The actual tip is not visible in some cameras, or only indirectly.
- USB streams provide no usable capture timestamps.
- The camera geometry gives unfavourable triangulation angles for some regions.
- The ground truth is not precise enough to validate millimetre targets.
- Good average accuracy hides rare but game-deciding misclassifications.
- A neural detector increases maintenance and run-time cost without reducing the core error enough.

### Still to be clarified

- Capture backend; the first camera model, its modes and exposure controls are recorded in [Reference hardware](hardware.md)
- Camera positions and viewing angles relative to the board
- Whether the tip is visible in all three views after the throw
- How ground truth is produced in practice
- Which existing software already provides camera capture, UI and multiplayer

Decided: the project is licensed under GPL-3.0-or-later, and the language stack is recorded in [ADR 0001](adr/0001-language-stack.md).

---

## 12. Conclusion

The most useful next investment is not rewriting the whole dart application right away. It is an **independently testable detection engine with a clean time base, explicit tip candidates, geometric validation and a millimetre benchmark**.

The first decisions are based on data:

1. How synchronous are the cameras really?
2. How accurate is each single camera after projection onto the board plane?
3. Does triangulation improve the error distribution, or make it worse through time offset and geometry?
4. Which cases cause the largest tip errors?
5. How often should the system reject a throw instead of reporting a wrong score?

Once these questions are answered, it can be decided on solid ground which algorithms, which existing software and which later UI/multiplayer integration make sense.
