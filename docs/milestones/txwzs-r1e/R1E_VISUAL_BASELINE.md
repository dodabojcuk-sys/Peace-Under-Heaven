# R1E Visual Baseline

## Direction

The shared direction is a restrained northern command-board: top-down,
low-saturation earth and stone, clear military structure, and one visual
language across city and battle. It must not read as a debug console, a flat
beige graybox, cyber UI, photorealistic painting, or cartoon bounce UI.

## Shared tokens

The existing project Theme is the single extension point for controls. The
baseline palette is:

- warm earth `#D8CEAD`
- pale sand `#C9BE9B`
- road and wall `#8D805F`
- deep ink `#102229`
- ink teal `#17353A`
- interaction jade `#4FA89A`
- bronze emphasis `#C69A4B`
- hostile rust `#A45742`
- warm primary text `#F2E9D2`
- muted secondary text `#AEBDB8`

Theme styles centralize borders, radii, shadows, focus, hover, selected,
warning, and disabled states. New UI code must not create per-control style
copies.

## City contract

- The ground uses low-contrast district variation and an edge treatment.
- Roads have shoulder, surface, center detail, and readable junctions.
- Key buildings use a roof/body/entrance/shadow/function-mark silhouette;
  labels supplement rather than define identity.
- Hover, selected, disconnected, constructing, and disabled states remain
  distinguishable without changing placement or connectivity rules.
- The city remains the visual subject. Context panels reveal detail only when
  needed and preserve the existing geometry-test facade.

## Battle contract

- The two deterministic routes remain unchanged but read as fortified lanes.
- Gates, obstacles, faction markers, formation banners, and nearby strength
  information replace anonymous gray strips.
- Commands and selection are clear at a glance; the result modal includes the
  participating formations and their losses.
- Feedback transitions last 120-180 ms, use cubic ease-out, kill prior tweens,
  and never alter simulation state or block input.

## Responsive and input gates

- Desktop targets: 1152x648, 1280x720, and 1440x900.
- Primary controls expose at least a 44x44 logical hit area and desktop body
  text is at least 14 px where R1E adds or replaces UI.
- Modal controls consume pointer input, establish initial keyboard focus, and
  use Input Map cancellation.
- Evidence relies on geometry/behavior assertions plus native screenshots and
  a real-input journey, never image hashes.

Status: implementation baseline, not Founder visual acceptance.
