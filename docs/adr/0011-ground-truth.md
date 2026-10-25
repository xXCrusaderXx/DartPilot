# ADR 0011: Ground truth from reference corners and from the player's corrections

- **Status:** accepted
- **Date:** 2026-10-25
- **Issues:** #14, #15, #16, #115

## Context

Every claim about precision needs the true point of a dart to compare with. The target of the project is a radial error below 1.5 mm (technical plan, section 6.2), so the true point must be known clearly better than that. #14 asked for candidate methods, their measured uncertainty, and a decision.

## Candidates

1. **Reference corners.** A dart is pushed by hand into a known corner of the wires: the bull centre, or where a radial wire meets a ring wire. Its true point comes from the measured board model. The app guides this as a reference run (#167): ten targets, each located by the engine as it would locate a thrown dart. The run is stored as a session with the targets as the annotation set `reference_corners` (#181).
2. **The player's corrections.** In play, the player taps where a wrongly placed dart really is, or adds a dart the engine missed (#115). `python -m dartpilot_tools.corrections` turns those taps into the annotation set `corrections`.
3. **Confirmed fields.** A dart that the engine placed and the player left alone is in the right field. That makes it field-level truth, not millimetre truth. The detection test of the setup GUI (#197) makes this explicit by rating every dart.
4. **Annotation in a calibrated image, a high-resolution reference camera, physical measurement** (technical plan). Not tried: each needs new equipment or a second tool, and the methods above already exist in the product.

## Measurements

All from the reference setup (ADR 0009) with the refinement of 2026-10-24.

**Reference runs.** Three runs of the ten targets, 2026-10-24 and 2026-10-25. Error = distance between the engine's point and the target:

| Run | Located | Median | P90 | Max |
| - | - | - | - | - |
| 2026-10-24, first | 10 | 1.96 mm | – | – |
| 2026-10-24, second | 10 | 0.76 mm | – | – |
| 2026-10-25 (session 20261025T074057Z-4ebd) | 9 of 10 | 1.33 mm | 1.59 mm | 1.64 mm |

The first two runs were not stored, so only their medians are known. In the stored run, split into radial and tangential components:

- **tangential**: median |error| 0.29 mm; 7 of 9 darts within 0.41 mm.
- **radial**: outer double corners (target r = 168.2 mm) +0.70 to +1.64 mm outward; inner treble corners (r = 96.3 mm) −0.29 to −1.53 mm inward; bull centre −0.78 mm. In all three runs the outer double corners came out outward.

These errors bound the uncertainty of the method from above, since they also contain the engine's own error. They say:

- **Along the ring wire (tangential), a corner fixes the dart to about 0.3 mm.** The radial wire guides the point.
- **Across the ring wire (radial), it does not.** The targets assume the point sits a fixed distance inside the field (1.8 mm from the outer double wire, 2.7 mm from the inner treble wire). Where a pushed-in point ends up across the ring wire varies by about ±1 mm, and in the double it lands nearer the wire than assumed. The radial spread is as large as the engine's error, so the method cannot tell the two apart there.

**Corrections.** A tap on the phone or PC board fixes a point to about 3 mm (the size of a fingertip on a 7 cm board image). The annotation set gives it a 3 mm uncertainty. Game 20261025T080221Z-91cb (49 darts) gave 17 such points: 13 for abstentions and 4 for missed darts. 32 placed darts were left alone and count as confirmed fields.

## Decision

- **Millimetre ground truth** comes from reference corners, with the uncertainty written into each annotation: 0.5 mm (1 σ) tangential and 1.0 mm (1 σ) radial. The benchmark reports radial and tangential errors separately (#17), so a radial result below about 1 mm is read as "within the method", not as a measured precision.
- **Field ground truth** comes from the player's corrections and confirmed fields, and from the ratings of the detection test. The benchmark uses them for segment and multiplier accuracy, abstention and false acceptance, never for millimetre errors.
- **No separate annotation tool for now** (#15): the reference run, the corrections in play and the detection test already produce annotations in the session format, and the benchmark reads them.

## Not yet met, and what follows

#14 asks for an uncertainty clearly below 1.5 mm. That holds tangentially (0.3 mm), but not radially (about 1 mm). The maintainer accepted this ADR with that limitation; closing the gap is #205, for 0.4.0, by one of two measurements:

1. **Targets on the wire.** The point is pushed against the ring wire, and the target lies at the wire's radius minus the point's radius, instead of a guessed distance inside the field. Repeated runs of the same corners give the radial spread directly.
2. **A close-up photo per target** with a phone held square to the board. It measures the point against the wires in pixels, at well below 0.5 mm per pixel.

Until then, millimetre results of the benchmark are stated with the method's radial uncertainty next to them.

## Repeated runs (#205)

The same ten corners were located in three stored runs: `20261025T074057Z-4ebd`, `20261025T225744Z-7387` and `20261025T230032Z-42a7`. The last two were made during the recording `20261025T225514Z-0009`, so their frames exist too. In 7387 the user placed two darts wrongly. The table shows each run's error against the targets:

| Run | Located | Median | Max | Radial median | Tangential median |
| - | - | - | - | - | - |
| 4ebd | 9/10 | 1.33 mm | 1.64 mm | 0.61 mm | 0.34 mm |
| 7387 | 8/10 | 1.02 mm | 2.91 mm | 1.08 mm | 0.36 mm |
| 42a7 | 9/10 | 0.97 mm | 1.84 mm | 1.05 mm | 0.38 mm |

The error of a corner splits into a part that repeats from run to run and a scatter around it. Over the eight corners off the bull, with 15 degrees of freedom:

- **Scatter between runs:** 0.75 mm radial and 0.71 mm tangential (pooled standard deviation). This includes the engine's own noise, so it is an upper bound for how repeatably a dart is placed. Without the two misplaced darts of 7387, most corners repeat within 0.1 to 0.5 mm.
- **Repeating part:** each corner keeps its offset from run to run. All outer double corners come out outward, by +0.8 to +1.7 mm (D3 at +1.68 mm with a scatter of 0.06 mm). The inner treble corners come out inward, by −0.6 to −1.0 mm. Over the corners this part has an RMS of 0.94 mm radially and 0.52 mm tangentially. Repeated runs cannot tell whether the offset comes from the assumed distance of the point inside the field or from the engine's geometry: both repeat in the same way.

So the random radial uncertainty of the method is measured, and it is clearly below 1.5 mm: at most 0.75 mm. The done-when of #205 is met. The annotations keep 1.0 mm (1 σ) radial, because the repeating offset is not yet assigned to the method or to the engine. Wire targets or a close-up photo (above) would settle that, and the ADR on the geometry variants (#25) is where the engine's share gets examined.

## Consequences

- The reference run stays the source of millimetre truth. It needs about ten minutes per run at the board, which the user experienced as tedious. Wire targets would also reduce the number of runs needed.
- Field-level truth comes for free from play and the detection test, and grows with every session the player corrects.
- Corrections have a single source per throw (the player's tap). There is no second annotator, so their uncertainty is an estimate, not a measurement.
