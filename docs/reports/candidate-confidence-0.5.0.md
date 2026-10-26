# Candidate confidence, 0.5.0

Every tip candidate (#26) states how sure it is: a 2×2 pixel covariance and a confidence from 0 to 1 (#28, technical plan 5.2). This report checks that both mean what they say, on the [dataset](../dataset.md) of 2026-10-25.

## How they are made

`tip_candidates::tipCandidates` rates each end of the dart from the candidates found there:

- **Covariance:** the spread of all candidates at that end, plus the scatter of the axis points across the axis, plus 0.5 px each way, then doubled (see below). Where axis end, contour end and skeleton end agree, the end is clear; where they spread along the axis, the fading point or a flight edge leaves the tip open.
- **Confidence:** `1 / (1 + s / 4 px)`, with `s` the square root of the trace before doubling: 1 where everything agrees, one half at a spread of 4 px.

All candidates at one end share the covariance and confidence of that end.

## How they are checked

There is too little millimetre truth with frames for this (12 throws, all of them hard ones; see the [tip candidate report](tip-candidates-0.5.0.md)). Instead, on throws located by three or more cameras, the located point's image in each camera stands in for the tip. The location comes from the cameras' axis planes, not from the tip candidates, so it is an independent reference. It has errors of its own: the point lies on the board plane, while the visible tip sits about 1.65 mm behind it (#23). The check uses every generated candidate at the end of the dart nearest that image (`python -m dartpilot_tools.candidate_recall`).

## Confidence against error

| Confidence | Development (91cb, 5966, 0bef): candidates | median / P90 error | Test (9406): candidates | median / P90 error |
| - | - | - | - | - |
| 0.6 – 1 | 151 | 2.3 / 5.5 px | 63 | 2.6 / 5.4 px |
| 0.4 – 0.6 | 126 | 4.0 / 9.5 px | 60 | 2.8 / 7.9 px |
| 0.2 – 0.4 | 13 | 9.1 / 16.9 px | 3 | 13.5 / 13.6 px |

The confidence orders the candidates by their error on both: lower confidence, larger error. None fell below 0.2.

## Covariance against error

For a normal error, 39 % fall within the 1σ ellipse and 86 % within the 2σ ellipse.

| | Development: within 1σ / 2σ | Test: within 1σ / 2σ |
| - | - | - |
| spread as measured | 20 % / 60 % | 25 % / 71 % |
| **doubled (as built)** | **39 % / 73 %** | **45 % / 86 %** |

The spread of the candidates alone understates how far the tip may lie. Doubling the variance (σ × 1.41) was chosen on the development sessions, as the factor that puts the median squared Mahalanobis distance where a normal error has it. On the test session it then gives 45 % and 86 %. On development the 2σ share stays at 73 %: their tail holds the views with two darts side by side, which no spread of candidates at one end can foresee (see the [shaft axis report](shaft-axis-0.5.0.md)).

## Effect on detection

None yet. The location still uses the axes and the axis ends, and replays of 91cb and 9406 give the same points as before on every throw. The confidence and covariance are there for the next steps: weighting cameras in the fusion (#32), and the threshold for asking the player about an uncertain dart (#33, #126).

## Reproducing

```sh
dartpilot replay <sessions>/<id> --pipeline tracker --run-id conf-028 --extrinsics <calibration>/extrinsics.yml
cd tools
DARTPILOT=<build>/engine/apps/dartpilot_cli/dartpilot python -m dartpilot_tools.candidate_recall <sessions>/<id>... --run conf-028
```
