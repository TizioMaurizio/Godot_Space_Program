# Godot Space Program — Aster Orbital Research Station

Implement a large modular orbital space station in **Godot Space Program**, strongly inspired by the engineering layout and gameplay role of the International Space Station, but designed as an original fictional station belonging to the Aster universe.

The station should be named:

**Aster Orbital Research Station**

Short designation:

**AORS**

It must not be a static decorative model.

It must be a real spacecraft constructed from the same `CraftDesign -> PartGraph -> RocketState/SpacecraftState` architecture used by player-built spacecraft.

Every module, truss, docking port, solar wing, radiator and propulsion/control component must exist as an identifiable physical part.

The completed station must:

- orbit Aster entirely through the existing orbital simulation;
- possess real mass, centre of mass and inertia;
- experience forces and structural loads;
- be capable of structural damage;
- contain functional docking ports;
- allow spacecraft to rendezvous and physically dock;
- support undocking;
- support vessel switching;
- persist while the player flies other spacecraft;
- survive save/reload;
- be visible and selectable from the orbital map;
- eventually be constructible through multiple launches instead of existing only as a predefined scenario.

Do not introduce any special "station physics."

A station is simply a very large spacecraft.

---

# 1. STATION DESIGN

## 1.1 Real-world reference

Use the mature International Space Station as the visual and architectural inspiration.

The real ISS has the characteristic architecture of:

- a long transverse integrated truss;
- pressurized cylindrical modules forming another major axis;
- connecting/node modules;
- laboratories branching laterally;
- multiple docking ports;
- large solar-array wings;
- thermal radiators;
- service modules;
- external equipment.

The real station is approximately:

- 94 m across the main truss;
- roughly 67 m along its pressurized-module axis;
- over 400,000 kg in mass;
- equipped with eight large original solar-array wings, later augmented by roll-out arrays.

Do NOT reproduce every real ISS component.

Do NOT use NASA logos, flags, real module markings or copyrighted textures.

The AORS should instead look immediately recognizable as a large ISS-style modular orbital laboratory while remaining an original spacecraft.

## 1.2 Reference configuration

Use a **mature 2020s ISS-like configuration** as the broad reference.

Do not attempt to represent one exact historical day.

Simplify:

- the Russian orbital segment into an original aft service complex;
- the many ISS external pallets into a smaller number of structural components;
- robotic arms initially;
- small antennas and experiments;
- visiting vehicles;
- duplicated modern solar-array upgrades.

The important visual language is:

**long truss + eight large solar wings + radiators + dense asymmetric pressurized module cluster + multiple docking ports.**

---

# 1.3 Overall AORS dimensions

Target approximately:

**Truss width:** 96 m

**Pressurized spine length:** approximately 45–50 m

**Maximum dimension including deployed solar wings:** approximately 100 m

**Initial wet mass:** approximately 185–195 tonnes

This makes it significantly lighter than the real ISS while remaining an enormous spacecraft relative to ordinary rockets.

Do not modify Aster's physics to accommodate it.

---

# 1.4 Visual identity

Use original procedural geometry and materials.

Suggested appearance:

### Pressurized modules

- off-white thermal blankets;
- metallic gray structural rings;
- darker attachment collars;
- occasional gold thermal insulation;
- small windows;
- handrail-like external details where inexpensive.

### Truss

- exposed metallic lattice;
- gray/aluminium structure;
- darker equipment boxes;
- cable/conduit details as geometry or textures.

### Solar arrays

Use large dark blue/black photovoltaic surfaces with visible cell segmentation.

Do not copy real ISS textures.

### Radiators

Large white or light-gray segmented panels.

### Observation module

Create a small multi-window cupola-inspired observation module beneath the station.

### Lighting

Add:

- small navigation lights;
- soft work lights around docking areas;
- illuminated windows on the night side.

Do not make the station glow excessively.

---

# 2. PART SPECIFICATION

Reuse the existing generic systems wherever possible:

- PartDefinition
- PartInstance
- AttachmentNodeDefinition
- ConnectionState
- TankModule
- CommandModule
- ReactionWheelModule
- existing structural solver
- collision/damage system
- spacecraft graph splitting
- FlightSnapshot
- SpacecraftRegistry
- CraftDesign serialization

Do not create station-specific copies of generic spacecraft systems.

Add new modules only where necessary.

## 2.1 New station part definitions

Use stable definition IDs.

| Definition ID | Role | Approx dimensions | Dry mass |
|---|---|---:|---:|
| `station.node.core` | Main six-way pressurized node | 6.6 m × 4.4 m dia | 14,500 kg |
| `station.node.forward` | Forward connection hub | 6.6 m × 4.4 m dia | 14,500 kg |
| `station.lab.axial` | Main science laboratory | 8.5 m × 4.2 m dia | 14,500 kg |
| `station.lab.port` | Port laboratory | 7.0 m × 4.2 m dia | 13,000 kg |
| `station.lab.starboard` | Large starboard laboratory | 11.2 m × 4.4 m dia | 15,500 kg |
| `station.node.habitation` | Aft habitation/node module | 6.6 m × 4.4 m dia | 13,000 kg |
| `station.service.aft` | Service / command module | 12.5 m × 4.2 m dia | 20,000 kg |
| `station.airlock` | EVA-style airlock | 5.5 m × 4.0 m dia | 6,000 kg |
| `station.logistics` | Permanent logistics module | 6.4 m × 4.3 m dia | 7,000 kg |
| `station.observation` | Cupola-style observation module | ~3 m × 1.5 m | 1,800 kg |
| `station.truss.keel` | Core-to-truss support | 4 m | 2,000 kg |
| `station.truss.center` | Central truss | 12 × 3 × 3 m | 8,000 kg |
| `station.truss.inner` | Inner port/starboard truss | 18 × 3 × 3 m | 7,500 kg |
| `station.truss.outer` | Outer port/starboard truss | 24 × 3 × 3 m | 9,000 kg |
| `station.solar.wing` | Deployable photovoltaic wing | 34 × 11 × 0.15 m | 1,500 kg |
| `station.radiator.panel` | Thermal radiator | 10 × 3 × 0.12 m | 600 kg |
| `station.docking.port` | Active/passive docking interface | ~1.0 × 2.0 m dia | 500 kg |
| `station.rcs.cluster` | Multi-axis RCS thruster cluster | ~0.8 m | 180 kg |
| `station.propellant.tank` | Station monopropellant tank | ~2.0 × 1.5 m | 800 kg dry |

Exact procedural mesh dimensions may be adjusted slightly to avoid visual/collision interference, but record changes.

---

# 2.2 Collision geometry

Pressurized modules:

Use capsule/cylinder compound collision geometry.

Do not rely on one bounding box for the entire station.

Truss:

Use several boxes representing the primary structural beams.

Do not generate hundreds of tiny lattice collision shapes merely to match decorative truss geometry.

Solar wings:

Use thin box collision proxies.

Their visual mesh may be much thinner than their physics collision thickness.

Radiators:

Use thin box collision proxies.

Docking ports:

Use:

- central capture cylinder;
- docking face plane;
- approach/capture trigger volume;
- physical collar collision.

The trigger is only for detecting docking eligibility.

It must not replace physical docking conditions.

---

# 2.3 Structural ratings

These values are fictional AORS engineering parameters, not claims about real ISS hardware.

Initial suggested ratings:

### Major truss-to-truss joints

Axial:
`1.5 MN`

Shear:
`0.8 MN`

Bending:
`4.0 MN*m`

Torsion:
`1.5 MN*m`

### Major pressurized module connections

Axial:
`0.8 MN`

Shear:
`0.4 MN`

Bending:
`1.5 MN*m`

Torsion:
`0.6 MN*m`

### Docking hard-joint

Axial:
`150 kN`

Shear:
`80 kN`

Bending:
`250 kN*m`

Torsion:
`120 kN*m`

### Solar-array attachment

These should be significantly weaker:

Axial:
`20 kN`

Shear:
`8 kN`

Bending:
`20 kN*m`

Solar wings and radiators should therefore be among the first components damaged by an extremely violent collision or reentry.

Tune only based on documented structural validation.

---

# 3. ASSEMBLY LAYOUT

# 3.1 Coordinate convention

Station-local frame:

`+X = starboard`

`-X = port`

`+Y = forward`

`-Y = aft`

`+Z = zenith / away from Aster`

`-Z = nadir / toward Aster`

Origin:

centre of `station.node.core`.

Cylindrical modules use local `+Y` as their longitudinal forward axis.

Quaternions use:

`[x, y, z, w]`

---

# 3.2 Main pressurized spine

### Core node

Instance:

`aors-core`

Definition:

`station.node.core`

Position:

`[0, 0, 0]`

Rotation:

`[0, 0, 0, 1]`

This is initially the station's root part and primary command module.

---

### Main axial laboratory

Instance:

`aors-lab-axial`

Position:

`[0, 7.55, 0]`

Rotation:

identity.

Connect:

`aors-core.forward`
to
`aors-lab-axial.aft`

---

### Forward node

Instance:

`aors-node-forward`

Position:

approximately:

`[0, 15.1, 0]`

Connect downstream of the axial laboratory.

This is the primary visiting-vehicle and laboratory hub.

---

# 3.3 Side laboratories

Attach two laboratory modules to the forward node.

## Port lab

Position approximately:

`[-5.7, 15.1, 0]`

Rotate cylinder longitudinal axis from +Y to -X.

Quaternion:

`[0, 0, 0.707107, 0.707107]`

---

## Starboard lab

Position approximately:

`[7.8, 15.1, 0]`

Rotate +Y to +X.

Quaternion:

`[0, 0, -0.707107, 0.707107]`

This module can be visibly larger than the port laboratory to produce an intentionally asymmetric silhouette similar to the complexity of the ISS.

---

# 3.4 Aft section

Attach habitation node behind the core.

Instance:

`aors-hab-node`

Position:

approximately:

`[0, -6.6, 0]`

Then attach:

`aors-service`

Position approximately:

`[0, -16.15, 0]`

The aft service section should visually differ from the forward science modules.

Suggested visual features:

- smaller solar/equipment surfaces;
- RCS clusters;
- antennae;
- propellant tanks;
- darker engine/service section;
- aft docking port.

Do not reproduce Zvezda directly.

---

# 3.5 Airlock

Attach an airlock radially to the core.

Example port-side position:

`[-4.95, 0, 0]`

Rotation from +Y to -X:

`[0, 0, 0.707107, 0.707107]`

It is initially primarily visual/structural unless EVA gameplay already exists.

Clearly mark EVA functionality as deferred if not implemented.

---

# 3.6 Logistics module

Attach to the habitation node on the opposite side.

Example:

Position:

`[5.4, -6.6, 0]`

Rotation +Y to +X:

`[0, 0, -0.707107, 0.707107]`

---

# 3.7 Observation module

Attach the observation module to the nadir side of the habitation node.

Approximate position:

`[0, -6.6, -2.9]`

Rotate local +Y downward toward -Z:

`[-0.707107, 0, 0, 0.707107]`

Give it several visible windows.

Interior gameplay is not required.

---

# 3.8 Main truss

Mount the truss above the pressurized core.

Use:

`aors-truss-keel`

to connect the core to:

`aors-truss-center`

Truss centre approximately:

`[0, 0, 6.5]`

The complete truss runs along X.

Segments:

### Centre

`aors-truss-center`

Centre:
`X = 0`

Length:
12 m

### Port inner

`aors-truss-p1`

Centre:
`X = -15`

Length:
18 m

### Port outer

`aors-truss-p2`

Centre:
`X = -36`

Length:
24 m

### Starboard inner

`aors-truss-s1`

Centre:
`X = +15`

Length:
18 m

### Starboard outer

`aors-truss-s2`

Centre:
`X = +36`

Length:
24 m

Resulting span:

approximately `-48 m` to `+48 m`.

Total:

approximately 96 m.

---

# 3.9 Solar arrays

Install eight major solar wings.

Place paired forward/aft-facing wings at approximately:

`X = -36`
`X = -15`
`X = +15`
`X = +36`

Each location has:

one wing extending approximately toward +Y

and

one wing extending approximately toward -Y.

The eight large wings should dominate the station silhouette.

Each wing is approximately:

34 m × 11 m.

Keep sufficient Z offset or mounting mast length so arrays do not intersect pressurized modules.

The initial implementation may keep the solar wings in a fixed deployed orientation.

Do NOT implement complex articulated solar tracking until needed.

Their power generation should nevertheless depend on Sun incidence.

Single-axis tracking can be added later.

---

# 3.10 Radiators

Mount six white radiator panels near the centre/inner trusses.

Use three primarily associated with the port half and three with the starboard half.

Arrange them so they are visually distinct from solar arrays.

They must:

- have real mass;
- contribute to inertia;
- have collision geometry;
- experience structural damage.

For the first implementation:

**radiators are structural and visual components but do not simulate thermodynamics.**

Label this explicitly.

Do not fake a temperature system simply to make them appear functional.

---

# 3.11 Docking ports

Provide at least five active docking locations.

### Port 1 — Forward

At the forward end of the forward node.

Primary visiting spacecraft port.

### Port 2 — Zenith

On top of the forward node.

### Port 3 — Nadir

Under the forward node.

### Port 4 — Aft

At the aft end of the service module.

### Port 5 — Service radial

One radial port near the service/habitation area.

All ports use the same generic docking system initially.

Later port sizes/types can differ.

---

# 3.12 Graph topology

The initial physical graph MUST remain a connected tree.

There must be:

- no redundant truss connections;
- no structural loops;
- no invisible braces creating graph cycles.

The port truss branch and starboard truss branch both originate from the centre truss.

Side laboratories are branches.

Solar arrays are leaf branches.

Radiators are leaf branches.

Docking ports are leaves until something docks.

Docking a vehicle attaches a new subtree through one docking connection.

If later structural struts connect two already-connected branches, that requires explicit graph-cycle/load-sharing support and must not be introduced silently.

---

# 4. ORBITAL SCENARIO

# 4.1 Aster parameters

Preserve existing values:

Planet radius:

`600,000 m`

Surface gravity:

`9.81 m/s²`

Atmosphere boundary:

`60,000 m altitude`

Do not change them.

Use the existing Aster gravitational parameter.

---

# 4.2 Nominal station orbit

Initialize AORS into:

**Circular altitude:** `120 km`

Orbital radius:

`720 km`

**Inclination:** `51.6 degrees`

This inclination intentionally echoes the real ISS without requiring Earth-scale geography.

Choose a documented initial:

RAAN:
approximately `25°`

argument of latitude:
`0°`

Because the orbit is circular, avoid depending on an undefined argument of periapsis.

Use the project's orbital-state conversion functions.

Expected approximate circular velocity:

**2,215 m/s**

Expected orbital period:

**34 minutes**

These are validation expectations, not new hard-coded physics constants.

Calculate authoritative values using the actual Aster `mu`.

---

# 4.3 Initialized scenario

Create:

`data/scenarios/aors_complete_orbit.json`

This scenario is explicitly:

**PREBUILT / INITIALIZED FOR TESTING**

It does NOT imply the station was launched as one piece.

It initializes the complete AORS directly into the nominal orbital state so docking, persistence and performance can be tested immediately.

Do not hide this initialization behind gameplay.

The scenario loader must clearly distinguish:

`initialized_orbital_scenario`

from spacecraft that reached orbit through flight.

---

# 4.4 Docking test scenario

Also create:

`data/scenarios/aors_docking_test.json`

Initialize:

- complete AORS;
- one small RCS-equipped docking vehicle;
- same general orbit;
- visiting craft approximately 500–1,000 m behind the station;
- very small initial relative velocity.

Do not initialize it already aligned perfectly at the docking port.

The player should have to:

- acquire target;
- null relative velocity;
- translate;
- align;
- approach;
- dock.

---

# 4.5 Real assembly campaign

Separately support actual orbital construction.

Suggested construction sequence:

### Launch 1
Core node + temporary propulsion/control tug.

### Launch 2
Main axial laboratory.

Rendezvous and dock.

### Launch 3
Forward node and first docking port.

### Launch 4
Central truss + keel.

### Launch 5
Port truss sections.

### Launch 6
Starboard truss sections.

### Launch 7
First solar-array set and radiators.

### Launch 8
Second solar-array set and radiators.

### Launch 9
Port and starboard laboratories.

### Launch 10
Habitation/logistics/observation modules.

### Launch 11
Aft service module.

### Launch 12+
Remaining equipment and docking interfaces.

Do not require all of these missions for the first playable station milestone.

They define the architecture so the station can eventually genuinely be assembled in orbit.

---

# 5. REQUIRED GAME SYSTEMS

The following systems are required before AORS can be considered fully implemented.

---

# 5.1 Docking ports

Create:

`DockingPortModuleDefinition`

and runtime:

`DockingPortModuleState`

A docking port must expose:

- capture position;
- outward docking axis;
- roll/up reference;
- compatible port type;
- capture distance;
- maximum closing velocity;
- maximum lateral offset;
- maximum angular misalignment;
- docked connection ID;
- state.

Suggested states:

`AVAILABLE`

`TARGETED`

`SOFT_CAPTURE`

`HARD_DOCKED`

`UNDOCKING`

---

# 5.2 Docking conditions

Docking must result from actual relative geometry and velocity.

Suggested initial capture limits:

Capture-plane separation:

`<= 0.12 m`

Closing velocity:

`<= 0.25 m/s`

Lateral offset:

`<= 0.10 m`

Docking-axis angular error:

`<= 7.5 degrees`

Roll alignment can be substantially more permissive for round ports.

If limits are exceeded:

do NOT magically dock.

The spacecraft should either:

- continue past;
- bounce/contact;
- damage the docking system if sufficiently violent.

Make the limits configurable.

---

# 5.3 Soft capture

When valid capture conditions are met:

do not instantly teleport one vessel onto the other.

Enter a short soft-capture phase.

Use spring/damping constraint forces to:

- remove small remaining translation;
- remove small angular error;
- align port faces.

These forces must be equal and opposite.

Do not violate total momentum.

Once:

relative velocity is very small,

alignment is within hard-dock tolerance,

and contact remains stable briefly,

transition to hard dock.

---

# 5.4 Hard docking

At hard dock:

merge the two connected physical assemblies.

Create a new explicit PartGraph edge:

`DockingConnection`

Recompute:

- total mass;
- combined COM;
- full inertia tensor;
- resource networks;
- electrical networks;
- command/control capability;
- structural graph.

Preserve total linear momentum.

Preserve total angular momentum about the new combined centre of mass.

Docking is intentionally inelastic.

Energy dissipated by the docking mechanism may be lost and should optionally be logged for debugging.

Do NOT invent additional velocity.

Do NOT zero station rotation arbitrarily.

---

# 5.5 Undocking

Undocking breaks the docking edge through the existing graph splitter.

Restore two connected components.

Use the existing momentum-preserving separation architecture.

Apply a small configurable equal-and-opposite separation impulse.

Suggested separation speed:

approximately:

`0.15–0.20 m/s`

The detached craft must retain:

- fuel;
- electrical charge;
- damage;
- part state;
- orientation;
- engine/RCS state where applicable;
- identity metadata.

---

# 5.6 RCS

Implement a genuine reaction-control system.

Add:

`RCSModuleDefinition`

`RCSModuleState`

RCS thrusters apply forces at their actual part positions.

They therefore create torque when appropriate.

Use propellant.

Add a monopropellant-like resource if no suitable resource exists.

No infinite free translation.

---

# 5.7 Translation controls

Add dedicated translational controls.

Suggested defaults:

`I / K` = forward / backward

`J / L` = left / right

`U / O` = up / down

Keep:

`W/S`
`A/D`
`Q/E`

for attitude where practical.

Use InputMap actions rather than hard-coding keys so controls can be remapped.

Provide:

**RCS ON/OFF**

and a docking-control indicator.

---

# 5.8 Docking reference frame

When a docking port is targeted, expose a relative docking frame.

HUD must show:

- target vessel;
- target docking port;
- range;
- range rate;
- total relative speed;
- closing velocity;
- lateral velocity;
- alignment angle;
- target-port direction.

Add navigation markers for:

- target direction;
- relative prograde;
- relative retrograde;
- docking axis.

At very close range, provide a dedicated docking alignment indicator.

Do not force automatic alignment.

---

# 5.9 Target selection

Allow the player to target:

- another spacecraft;
- station;
- individual docking port.

From:

- map;
- flight view;
- vessel list.

Targeting does not modify physics.

---

# 5.10 Vessel switching

Implement switching between controllable spacecraft.

Suggested controls:

`F6` = next controllable/persistent vessel

`Shift+F6` = previous vessel

Exact mapping may change if conflicts exist.

Switching active vessel must NOT:

- teleport spacecraft;
- freeze other vessels;
- delete them;
- reset their physics;
- change their orbit.

Other vessels continue to simulate.

---

# 5.11 Vessel persistence classes

Replace distance-only lifetime assumptions with explicit lifecycle classes.

Suggested:

`ACTIVE`

`PERSISTENT`

`DEBRIS`

`TRANSIENT_EFFECT`

AORS is:

`PERSISTENT`

Docking-capable player craft should normally be:

`PERSISTENT`

Important spacecraft MUST NOT be deleted because they are more than the existing 200 km debris cleanup distance from the active vessel.

Only actual debris should use aggressive cleanup rules.

---

# 5.12 Flight-state persistence

Craft JSON is currently a design description.

Do NOT overload it with flight state.

Introduce a separate versioned flight save.

Suggested path:

`user://saves/<save_name>.json`

Create a schema containing:

- schema version;
- simulation/session epoch;
- celestial state/reference;
- every persistent vessel ID;
- craft/design reference;
- absolute double position;
- absolute double velocity;
- orientation quaternion;
- angular velocity;
- complete live PartGraph;
- docked connections;
- remaining resources;
- electrical charge;
- module runtime states;
- deployed solar arrays;
- damage;
- broken connections;
- RCS state;
- staging state where relevant;
- vessel metadata;
- active vessel ID;
- target vessel/port where reasonable.

Save atomically.

Reloading must reproduce the station's actual state.

---

# 5.13 Electrical power system

For AORS, make solar arrays and batteries FUNCTIONAL rather than purely decorative.

Introduce an electrical resource network if one does not already exist.

Use real units consistently.

Preferred:

Energy:
`joules`

Power:
`watts`

Each solar wing:

maximum approximately:

`18 kW`

Eight wings:

approximately:

`144 kW` peak.

Generation:

`P = P_max * max(0, dot(panel_normal, sun_direction))`

also account for planetary eclipse.

Do not generate power while Aster blocks the Sun.

Implement a simple ray/geometric eclipse test against the planet.

---

# 5.14 Batteries

Provide distributed battery storage.

Target total station capacity:

approximately:

`300–400 MJ`

Exact value may be tuned after eclipse-duration testing.

Base station consumption:

approximately:

`30–40 kW`

Loads can include:

- command computers;
- docking system;
- reaction wheels;
- lights;
- laboratory loads.

Create resource priorities.

Critical command systems should have higher priority than laboratories.

Do not add unnecessary detailed life support yet.

---

# 5.15 Solar tracking

FIRST implementation:

arrays remain fixed in their deployed geometry.

Generation depends on incidence.

Later:

single-axis rotary tracking may be added.

Do not create unreliable articulated rigid-body chains merely to animate the arrays.

If cosmetic solar tracking is added before physical articulation exists, clearly label it as visual-only and ensure it does not modify physical mass distribution incorrectly.

---

# 5.16 Radiators

Radiators are initially:

- physical parts;
- structural parts;
- collision-enabled;
- damageable;
- visual.

But:

**they are NOT yet thermally functional unless a proper thermal simulation exists.**

Do not invent meaningless "heat points."

Add a thermal system in a later milestone if desired.

---

# 5.17 Station attitude control

AORS may contain:

- reaction wheels/control moment approximation;
- RCS.

Attitude HOLD may use those systems.

But there must be:

**NO orbital station-keeping magic.**

The orbit must evolve only according to existing gravity and forces.

Do not secretly restore altitude.

Do not zero eccentricity.

Do not lock position to an orbital path.

AORS should remain in orbit because its initialized state is physically orbital.

---

# 5.18 Time warp near other spacecraft

High time warp must not skip rendezvous or collisions.

Implement proximity protection.

Suggested behavior:

When targeted/persistent vessels are within approximately:

`5 km`

disable analytic high coast warp if the predicted interval could cross a close approach.

Under:

`2 km`

limit warp aggressively.

Under:

`200 m`

allow at most low physics warp.

Under:

`50 m`

force:

`1x`

when relative collision/capture is possible.

Better:

perform closest-approach/event prediction across the proposed warp interval and drop from warp before entering the protected region.

Do not merely detect proximity after the vessels have crossed through each other.

---

# 5.19 Camera

Camera must support:

- station-scale craft;
- normal visiting spacecraft;
- switching vessels;
- target tracking.

For very large assemblies increase camera distance appropriately.

Add:

**Target camera**

capable of keeping both active craft and target station visible where practical.

Near docking:

allow camera focus on selected docking port.

---

# 5.20 Orbit map

AORS must appear in the existing map.

Show:

- vessel name;
- station icon;
- orbit;
- selected/target state.

Allow:

- focus;
- switch-to-vessel;
- set target.

If multiple spacecraft exist, render their orbits using the appropriate current-body reference.

Do not calculate the station using separate orbital rules.

---

# 6. IMPLEMENTATION SEQUENCE

Proceed continuously.

Do not wait for user approval after every milestone.

Use:

**implement -> test -> document -> continue**

unless encountering a genuine blocker.

---

## Milestone 1 — Persistent complete station

Implement first:

- station part definitions;
- completed AORS CraftDesign;
- initialized orbital scenario;
- procedural visuals;
- station physical mass/inertia;
- persistent vessel lifecycle;
- map/camera support.

FIRST PLAYABLE TARGET:

The player can load the AORS scenario, switch to it, rotate around it with the camera and time-warp while it naturally continues around Aster.

No docking required yet.

Validate orbit before proceeding.

---

## Milestone 2 — RCS and relative navigation

Implement:

- RCS thrusters;
- monopropellant;
- translation controls;
- vessel targeting;
- relative position/velocity;
- docking HUD;
- target markers.

Create the docking test scenario.

Player must be able to maneuver the test vehicle around AORS without docking yet.

---

## Milestone 3 — Docking

Implement:

- DockingPortModule;
- capture checks;
- soft capture;
- hard docking;
- graph merge;
- combined mass properties;
- momentum conservation;
- undocking;
- graph split;
- separation impulse.

FIRST MAJOR GAMEPLAY TARGET:

Rendezvous with AORS, dock and later undock.

---

## Milestone 4 — Vessel switching and persistence

Implement:

- multiple persistent vessels;
- active-vessel switching;
- station state continuing while inactive;
- save/reload flight state;
- restored docking topology;
- restored resources and damage.

Test saving while:

- approaching;
- independently orbiting;
- docked;
- undocked.

---

## Milestone 5 — Electrical system

Implement:

- ElectricResourceNetwork;
- solar generation;
- Sun incidence;
- planetary eclipse;
- battery storage;
- station loads;
- load priority;
- HUD/debug telemetry.

Station systems should run through eclipse using battery storage.

Do not let arrays produce energy through Aster.

---

## Milestone 6 — Real orbital construction

Make station modules launchable as ordinary craft payloads.

Support assembling AORS from separate launches.

Docked modules must become genuine permanent additions to the station PartGraph.

Nothing about orbital construction should invoke a special station assembly command.

Docking IS assembly.

---

# 7. ACCEPTANCE TESTS

Create automated tests wherever feasible and rendered/integration tests where necessary.

---

## 7.1 Orbit

Initialize AORS in the defined circular orbit.

With:

- engines/RCS off;
- no fake stabilization;

run several complete orbital periods.

Verify:

- orbital altitude remains within expected integrator tolerance;
- energy drift remains within existing physics tolerance;
- no artificial orbit correction occurs.

---

## 7.2 Mass

Verify total station mass exactly equals:

sum of:

- part dry masses;
- propellant;
- other mass-bearing resources.

Electrical charge must not incorrectly add kilograms unless explicitly modelled with negligible physical mass and documented.

---

## 7.3 COM and inertia

Compare calculated station COM/inertia against an independently calculated expected result for the predefined AORS design.

The station is intentionally asymmetric.

Its COM should not coincidentally be forced to geometric centre.

---

## 7.4 Independent rendezvous

Initialize test spacecraft approximately 1 km away.

Player/test pilot must be able to:

- acquire target;
- reduce relative velocity;
- approach station.

No position snapping.

---

## 7.5 Docking rejection

Attempt docking with:

- excessive speed;
- excessive lateral offset;
- excessive angular error.

Docking must NOT occur.

---

## 7.6 Valid docking

Perform valid slow approach.

Verify:

- soft capture;
- hard capture;
- creation of docking graph edge;
- single resulting physical connected component.

---

## 7.7 Momentum conservation

Immediately before and after hard dock compare:

total linear momentum.

Also compare total angular momentum about a common inertial reference.

Momentum must remain within rigorous numerical tolerance.

Loss of relative kinetic energy during capture is allowed and expected.

No unexplained momentum may appear.

---

## 7.8 Combined mass properties

After docking verify:

- total mass;
- new COM;
- new inertia tensor;
- fuel network;
- electrical network.

Docking a craft on one side should physically move the combined COM.

---

## 7.9 Undocking

Undock.

Verify:

- correct graph components;
- resources remain with their respective parts;
- identities survive;
- equal/opposite separation impulse;
- no duplicated or missing mass;
- momentum conservation.

---

## 7.10 Vessel switching

Create:

- station;
- visiting craft;
- another distant craft.

Switch among them repeatedly.

Verify no vessel:

- freezes;
- teleports;
- resets;
- disappears.

---

## 7.11 Persistence

Save a flight containing AORS.

Move active spacecraft more than 200 km away.

AORS must remain present.

Reload.

Verify absolute:

- position;
- velocity;
- orientation;
- resources;
- damage;
- docking state.

---

## 7.12 Time warp encounter protection

Construct a trajectory that would pass through the station during high warp.

The simulation must detect/protect the encounter before the bodies overlap.

High warp must fall back appropriately.

---

## 7.13 Structural behavior

Apply unrealistic collision or acceleration loads.

The station must use the same structural failure system as any other spacecraft.

Solar arrays/radiators should be vulnerable.

Do not make the station indestructible.

---

## 7.14 Solar generation

Test array normal:

toward Sun -> near maximum generation.

90° incidence -> approximately zero.

Facing away -> zero.

Behind Aster in eclipse -> zero.

---

## 7.15 Battery eclipse test

Run through full sun -> eclipse -> full sun.

Verify:

- battery charges;
- discharges;
- station load consumes energy;
- recharge resumes after eclipse.

---

## 7.16 Regression

All applicable existing tests must still pass:

- launch;
- orbital mechanics;
- staging;
- part graph;
- structural failure;
- aerodynamics;
- terrain;
- water;
- reentry;
- time warp;
- spacecraft editor;
- Moon/SOI;
- save systems already implemented.

Do not weaken old tests to add AORS.

---

# 7.17 Performance

Measure at least:

50-part assembly

100-part assembly

full AORS

AORS + docked vehicle

AORS + multiple nearby visiting vehicles.

Record:

- fixed physics cost;
- structural solver cost;
- render cost;
- collision candidate count;
- map cost;
- memory;
- time-warp cost.

The full station should remain reasonably playable on the existing target desktop hardware.

Profile before simplifying physics.

---

# 8. DELIVERABLES

Deliver:

### Part definitions

All AORS `.tres`/definition resources.

### Craft file

`data/craft/aors_complete.json`

### Scenario

`data/scenarios/aors_complete_orbit.json`

### Docking test scenario

`data/scenarios/aors_docking_test.json`

### Systems

- docking;
- RCS;
- targeting;
- relative navigation;
- vessel switching;
- persistence;
- electrical power.

### Visuals

Original procedural:

- laboratories;
- nodes;
- truss;
- docking ports;
- solar wings;
- radiators;
- observation module;
- service module.

No proprietary or copied ISS assets.

### UI

- target selection;
- relative velocity;
- docking indicators;
- RCS state;
- vessel list/switching;
- station electrical state;
- map vessel selection.

### Tests

Add automated and integration validation for every acceptance condition above.

### Documentation

Update:

`docs/DEVELOPMENT_JOURNAL.md`

`docs/VALIDATION.md`

and relevant architecture documents.

---

# 9. DEBUGGING SUPPORT

Add a station/docking debug overlay.

Display:

Active vessel

Target vessel

Target port

Distance

Relative velocity vector

Closing speed

Lateral velocity

Port-axis angle

Soft-capture state

Docking-connection state

Active vessel mass

Combined COM

Angular velocity

RCS force/torque

Monopropellant

Electrical generation

Electrical load

Battery energy

Sun incidence

Eclipse state

Persistent-vessel count

Physics mode/time warp

This should make docking problems diagnosable rather than visual guesswork.

---

# 10. APPROXIMATIONS AND DEFERRED FEATURES

Explicitly defer unless already supported:

### Crew simulation
No astronauts or crew life support required.

### Interior
No walkable interior required.

### EVA
Airlock may initially be structural/visual.

### Robotic arm
A Canadarm-like robotic arm is deferred.

Do not fake one as a rigid decoration unless clearly nonfunctional.

### Detailed thermal physics
Radiators remain nonthermal until a real thermal model exists.

### Flexible solar arrays
Solar-array flex is deferred.

Structural joint failure still applies.

### Solar tracking
Full physical articulated solar tracking may be deferred.

### Docking autopilot
Manual docking is the baseline.

Optional rendezvous/docking assistance can be added later.

### Fluid transfer
Cross-vessel propellant transfer after docking may be deferred unless straightforward.

Normal resource-network connectivity should not automatically imply tank balancing unless explicitly implemented.

### Pressurization
Pressurized modules do not require atmosphere/leak simulation yet.

### Crew transfer
Deferred.

---

# 11. IMPORTANT ENGINEERING RULES

Do not special-case AORS as an immovable world object.

Do not use:

`StaticBody3D`

for the complete station.

Do not freeze its orbit.

Do not attach it to the map.

Do not parent visiting craft visually and pretend they docked.

Do not set velocities equal when docking without conserving momentum.

Do not teleport craft into alignment from metres away.

Do not ignore COM changes after docking.

Do not ignore angular momentum.

Do not let persistent vessels disappear because the player flies far away.

Do not allow high time warp to tunnel through the station.

Do not give RCS infinite propellant.

Do not generate solar power during eclipse.

Do not make the station immune to structural damage.

The station must be subject to the same physical universe as everything else.

---

# 12. TARGET PLAYER EXPERIENCE

The final experience should be:

I open the AORS scenario.

A vast station is already orbiting above Aster.

The camera can pull back enough to reveal its ~100-m-wide silhouette: a long metallic truss, eight enormous solar wings, white radiators and a dense asymmetric group of pressurized modules below it.

Aster moves beneath the station naturally.

The station passes from sunlight into darkness.

Its solar production drops to zero.

Batteries begin supplying the station.

City lights become visible on Aster below.

Small station lights and module windows become visible.

The station continues around Aster because it is genuinely in orbit.

I switch to a small spacecraft several hundred metres away.

AORS remains physically present.

I select the station as my target.

The HUD shows range and relative velocity.

I turn on RCS.

I null my relative velocity and translate toward the station.

I select the forward docking port.

The docking display shows lateral error and angular alignment.

I approach at centimetres per second.

When the docking interfaces physically meet within their capture limits, soft capture begins.

The mechanism removes the final tiny errors.

Hard docking occurs.

The spacecraft and station become one physical connected assembly.

Their combined centre of mass changes.

Their inertia changes.

Their resources and structural graph update.

I time-warp several orbits.

I save the game.

I reload.

My spacecraft remains docked exactly where it was.

Later I undock.

A small physical separation impulse pushes the spacecraft away.

The station remains behind, continuing in its orbit.

Eventually I can launch new modules from Aster, rendezvous with AORS and expand the station piece by piece.

That is the target.

The Aster Orbital Research Station should demonstrate that **Godot Space Program now supports not merely rockets, but persistent modular infrastructure in space.**