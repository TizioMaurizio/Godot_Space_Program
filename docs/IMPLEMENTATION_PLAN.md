# Godot Space Program — spacecraft architecture and implementation plan

**Status: approved for continuous implementation of Phases 1–6. Updated 2026-10-01.**

**Implementation outcome:** Phases 1–6 are now implemented. See [UPGRADE_REPORT.md](UPGRADE_REPORT.md) for the actual architecture, deviations, acceptance evidence and deferred systems, and [VALIDATION.md](VALIDATION.md) for final results. The proposed large-craft atmospheric performance target is not met. The detailed proposal below is retained as the original design/acceptance record; the journal documents the concrete-runtime, composed-dictionary-module and clipmap adaptations.

This document replaces the completed vertical-slice plan. The implementation history and measured results remain in `DEVELOPMENT_JOURNAL.md` and `VALIDATION.md`. The game is renamed from Aster Flight Lab to **Godot Space Program**; **Aster** remains the planet name.

The architecture was approved on 2026-10-01. The subsequent execution brief removes inter-phase approval pauses. Execute **implement → validate → document → continue**, preserving each phase's validation gate. References below to stopping for review describe the original proposal and are superseded by this authorization. Do not weaken physics tolerances to pass a gate; document justified architectural deviations and actual remaining limitations.

## 1. Inspection findings and what is reusable

Reviewed the current README, prior plan, development journal, validation report, definitions and resources, simulation, game orchestration/rendering, UI, test assertions/ascent pilot, and Linux export tooling. The working tree also contains the completed, not-yet-committed Linux build support; preserve it.

| Current code | Observed behavior | Proposed treatment |
| --- | --- | --- |
| `simulation/dvec3.gd` | Position/velocity use three scalar doubles; only relative/render values become Vector3. | Reuse without changing its coordinate contract. |
| `planet_physics.gd`, `data/aster.tres` | Inverse-square central gravity, rotating exponential atmosphere, smooth density cutoff. | Retain numerical formulas and constants in Phase 1. Wrap environmental queries later. |
| `flight_body.gd` | One point-mass translational state, velocity Verlet with predicted endpoint drag, cylinder inertia, angular integration and air damping. | Keep integration order and timestep; add an aggregate force/torque interface and full inertia tensor for assemblies. Legacy defaults must still work. |
| `engine_definition.gd`, `rocket_stage.gd` | Pressure-dependent Isp/thrust; stage-local fuel and oxidizer; bounded consumption. | Reuse engine equations/definitions. Move authoritative resource quantities into tank modules; retain the old implementation as a regression oracle. |
| `rocket_state.gd` | A stage array defines mass/length; one engine is active; launchpad constraint; hard-coded two-stage separation. | Replace internal stage ownership with a part graph, module execution and staged actions behind a compatibility facade. |
| `attitude_controller.gd` | Eight SAS modes, quaternion attitude error, bounded body-rate/torque commands, direct calls to body angular integration. | Preserve target selection and feedback behavior; separate torque calculation from applying the aggregate wrench. |
| `aerodynamics.gd` | Whole-vehicle axial/side area, one pressure-centre offset, rotational damping. | Preserve an explicitly named compatibility model for Phase 1 parity; add a per-part force provider in Phase 2. |
| `orbital_mechanics.gd`, `kepler_coast.gd` | Osculating elements and double-scalar universal-variable vacuum propagation. | Keep the single-body algorithms and their tests. Phase 6 supplies relative body state through an adapter. |
| `time_warp.gd` | Repeated 120 Hz substeps at 1–4×; guarded analytic coast at 10–1,000×; attitude held in coast. | Reuse rates and boundary guard; eligibility must eventually account for all live engine/contact/structural events. |
| `orbit_prediction.gd`, `ui/orbit_map.gd` | Read-only conic preview; circular/escape/radial paths; surface clipping; independent map camera. | Reuse predictions and map navigation. Read active-body/vehicle snapshots instead of stage internals. |
| `game/main.gd` | Owns active rocket, separate bare-body debris array, input, scheduling, staging, drawing and cleanup. | Incrementally extract `FlightSession` and `SpacecraftRegistry`. All components use one simulation clock and body lifecycle. |
| `game/rocket_visual.gd` | Meshes are rebuilt by stage index, not part identity. | Preserve mesh/material helpers; add part visuals keyed by stable part IDs. |
| `ui/flight_hud.gd`, `ui/attitude_indicator.gd`, `flight_computer.gd` | Strongly typed to RocketState; HUD/map directly read `stage_index`, `stages`, `current_stage()`. | Introduce a common snapshot; keep existing instrumentation and keyboard behavior during migration. |
| `game/world_visual.gd`, shaders | Scaled sphere plus a visual tangent plane; cloud/ocean-like colours are shader patterns, not physical layers. | Keep the current presentation for Phases 1–3. Replace through a common surface query in Phases 4–5. |
| Current impact/debris logic | Radius check sets one `crashed` flag; nearby crashed debris is removed. No physical terrain, ocean, part contacts or buoyancy. | Keep the legacy fixture until Phase 2 contact/damage is validated; then replace blanket crash/cleanup with per-part outcomes. |

There are **no Godot RigidBody3D nodes driving flight** today. Moving to a graph does not require replacing the validated custom integrator with the engine's joint solver. Existing tests are an executable baseline, not proof that the proposed new systems already work.

## 2. Primary design decision: one body per connected component

Use the requested hybrid architecture. A spacecraft owns a graph of simulation parts and connections, but its connected assembly has one integrated position, velocity, orientation and angular state. Each part contributes mass, inertia, forces and identifiable collision geometry. Cutting connections partitions the graph; each resulting component becomes another spacecraft body.

```text
CraftDesign (immutable assembly recipe, no flight state)
    -> CraftFactory
       -> SpacecraftState : FlightBody       [one connected component]
          + PartGraph
          |  + PartInstance[] -> module states and local geometry
          |  + ConnectionState[] -> ports, crossfeed, strengths, loads
          + MassProperties -> mass, COM, full inertia, bounds
          + FuelNetwork + EngineSystem + StageController
          + AttitudeController + force/torque accumulator
          + ForceLedger -> later joint loads and contact damage
       -> FlightSnapshot -> HUD, nav indicator, map, inspectors
       -> SpacecraftVisual -> meshes, per-part query shapes, FX/audio

FlightSession -> SpacecraftRegistry -> all active/debris components
```

Part definitions are immutable Godot Resources; runtime instances are plain simulation objects. Meshes and collision proxies reference `(spacecraft_id, part_id)`, never own fuel or authoritative positions. Godot scene nodes may provide local collision queries, but cannot also integrate the same forces. Independent per-part engine rigid bodies are not the default; no claim is made that a joint-chain alternative has been benchmarked.

### Graph and ownership rules

- Every part has a stable craft-local string ID and exactly one owner component. A command part is the design root; graph orientation is an assembly convention, not a force direction.
- Connections are explicit edges between **two named attachment nodes**, with endpoint-local positions/orientations, mating rules, crossfeed permissions and structural ratings.
- The initial construction graph is a connected, rooted **tree**. It supports radial branches. Reject cycles at load/placement until a load-sharing solver is implemented; silently treating a loop as a tree would give false structural loads. Graph APIs still use adjacency and connected-component traversal.
- Root selection and control authority are separate. A detached component without command still simulates. On splitting, the component containing the selected command remains active; otherwise choose another surviving command deterministically or report control lost.
- Definitions are shared. Runtime tanks, engine ignition, damage, deployment, resource quantities and joint loads are instance-owned and are never shared accidentally between identical parts.
- Connectivity/resource-route caches change only on topology or crossfeed edits. Graph operations process stable sorted IDs for repeatable ordering.

## 3. Proposed data model and modules

| Type | Authoritative contents |
| --- | --- |
| `PartDefinition` | Catalog ID/revision, name/manufacturer/category/description; dry mass and local dry COM; primitive dimensions/shape descriptors, volume, inertia model; aero coefficients/pressure centre; attachment definitions; strength/crash limits; maximum-temperature placeholder; module definitions and procedural visual key. |
| `AttachmentNodeDefinition` | Node ID, local pose, stack/radial/surface kind, allowed size/mating categories, occupancy limit and structural/crossfeed defaults. Surface placement creates an explicit saved local frame. |
| `PartModuleDefinition` and concrete module Resources | Engine, tank, command, reaction wheel and decoupler settings in Phase 1. Battery, fin/control surface, parachute and landing-leg behavior are added in their scheduled phases. No unimplemented module may appear functional in the catalog. |
| `PartInstance` | Stable ID, definition reference, pose in the craft design frame, symmetry-group ID, current module states/resources, per-part force record and later damage/contact state. |
| `ConnectionDefinition` / `ConnectionState` | Endpoint part/node IDs and rest poses; tension/compression/shear/bending/torsion limits, stiffness/damping, crossfeed; runtime load/utilization and broken flag. Runtime load solving begins in Phase 2. |
| `CraftDesign` | Schema/catalog versions, name, root ID, part placements and initial settings, connection recipes, symmetry groups and ordered stage actions. |
| `MassProperties` | Current total/dry/resource mass, COM, symmetric 3×3 inertia/inverse, bounds and dirty/version counters. |
| `StageDefinition` replacement | New `StagePlan`/`StageActionDefinition` describes actions, not a physical tank/body. Preserve old `StageDefinition` for the converter and tests. |
| `FlightSnapshot` | Read-only flight/orbit data plus stage actions, aggregate and per-tank fuel, mass, TWR, delta-v and eventually stress/contact/current-body fields. |

Use module composition, not one subclass for every part combination. A capsule can contain Command + ReactionWheel + Battery definitions; a tank contains propellant storage; an engine references the existing EngineDefinition. Module dry mass is included in its owning part's dry mass, never added twice.

Electrical units are charge/energy, not kilograms. Resource definitions explicitly state density/mass-per-unit; fuel and oxidizer remain kilograms. Temperature remains visibly labelled as a placeholder until a thermal model exists.

## 4. Coordinates, mass, COM and inertia

### Coordinate contract

Preserve the current nonrotating, Aster-centred SI frame in Phase 1. `FlightBody.position`/`velocity` represent the assembly COM in scalar doubles. Craft-local part poses are authoritative design/simulation values, independent of Node3D transforms. Rendering uses a nearby double origin `O`:

```text
part_world_COM = X + rotate(Q, part_local_COM - assembly_local_COM)
part_render_position = Vector3(part_world_COM - O)
```

Rotate local metre-scale offsets before adding them to the absolute DVec3; never round the absolute sum through Vector3. The foreground, scaled planet and orbit map remain separate views of the same state. Introduce a small scalar-double symmetric tensor helper for mass aggregation; local quaternion attitude may retain the current precision initially, with drift tests.

### Aggregation

For each dry solid and resource volume `i`, obtain mass `m_i`, centroid `x_i`, and local inertia rotated into the craft axes. Compute:

```text
M = sum(m_i)
c = sum(m_i * x_i) / M
rho_i = x_i - c
I = sum(R_i I_i R_i^T + m_i * ((rho_i dot rho_i) Identity - rho_i rho_i^T))
```

Retain off-diagonal terms: asymmetric craft cannot use the current three cylinder moments. Require positive mass and a nonsingular positive-definite inertia tensor. Fuel initially occupies a uniform tank volume with a specified centroid; no slosh model. Asymmetric tank depletion still moves assembly COM and changes inertia.

Fuel burn must not make attached parts jump when the mass reference moves. At a mass-update boundary, change the COM reference by `delta_c` while retaining the remaining parts' poses and rigid velocity field: `X += rotate(Q, delta_c)` and `V += omega_world cross rotate(Q, delta_c)`. This is a change of reference for the remaining mass, not an engine impulse. Keep the design origin/part poses fixed and derive the render anchor from them.

A `MassFlowLedger` records consumed mass at tank centroids and its carried linear/angular momentum. Do not hold wet-body angular momentum fixed as mass leaves and thereby invent spin-up. The initial approximation is co-moving tank parcels with idealized instantaneous plumbing; engine thrust already represents exhaust momentum and must be applied exactly once. Validate reference continuity, zero-thrust mass-removal cases and variable-inertia rotation before connecting this to ascent.

## 5. Forces, engines, gimbal, fuel and SAS

Each force contribution identifies its owning part, application point, vector and any direct couple. Evaluate force locations relative to the **current COM**:

```text
F_total = sum(F_i)
tau_total = sum((point_i - COM) cross F_i + direct_torque_i)
```

Thrust follows the engine's local nozzle transform and actual gimbal orientation. Rotated or off-axis engines therefore create torque naturally. Pressure-dependent Isp and `F = mass_flow * Isp * g0` stay as implemented. Constrain gimbal angle and slew rate; allocate SAS requests between available reaction-wheel torque and enabled gimbals, without applying the same requested torque twice.

`FuelNetwork` caches reachable compatible tanks per engine over crossfeed-enabled edges. No implicit access to every tank in the structural component. For a fixed substep, calculate all engine requests first, reserve both propellants together, resolve shared shortages proportionally and deterministically, then withdraw from reachable tanks in a documented balanced order. Use actual consumed mass for thrust. This prevents engine iteration order and missing oxidizer from producing extra thrust or preferential starvation. In the migrated OTV, the interstage boundary blocks crossfeed so the booster cannot drain the upper tank.

Preserve the existing PD target/rate behavior. Refactor its final integration call into a torque request; the body integrates **all** control/engine/aero torques once. Command and reaction-wheel modules provide control availability and bounded authority. Keep current rate/acceleration limits as command limits during parity testing. Select sufficient explicit capsule wheel torque for the reference craft; do not introduce a new power-starvation gameplay rule during this phase.

The translational kick-drift-kick ordering and 1/120 s step remain. Generalize `FlightBody` to evaluate a supplied wrench/environment at the same samples it currently uses for gravity/drag; a bare FlightBody retains the current fallback. Recompute attitude-dependent forces consistently and avoid adding both the old whole-body drag and new part drag.

### Aerodynamic migration boundary

Phase 1 uses a named **LegacyEnvelopeAerodynamics** provider for the reference OTV, preserving its validated area/Cd/pressure-centre behavior while mass, inertia, engines and tanks genuinely become parts. This temporary provider is explicit in the design, not hidden corrections to gravity or thrust. Part aero definitions exist, but it is not yet the general per-part flight model.

Phase 2 adds `PartAerodynamics`: local air velocity includes rotational velocity at each part, exposed axial/side projected areas create forces at part pressure centres, and damping/couples feed the same force ledger. Cache approximate upstream shielding using part bounds and airflow-direction bins; rebuild when direction/topology changes significantly. Nose shielding affects frontal exposure, not all side drag. Calibrate aggregate forces against the old envelope and revalidate ascent. Fins/lift/control surfaces follow in Phase 3. No CFD or opaque force fudge factors.

## 6. Exact reference-vehicle migration

Convert the existing OTV into six simulation parts. The proposed dry-mass allocation is a design choice; totals, propellant, engine performance and external length are fixed migration invariants.

| Part | Dry mass | Fuel / oxidizer | Length | Root-frame centre Y |
| --- | ---: | ---: | ---: | ---: |
| Command capsule (command/wheel included) | 1,500 kg | 0 / 0 | 4 m | 0 m |
| Lumen tank | 700 kg | 1,666.6666666667 / 3,333.3333333333 kg | 6.5 m | -5.25 m |
| Lumen vacuum engine | 300 kg | 0 / 0 | 1.5 m | -9.25 m |
| Interstage decoupler, retained with booster | 100 kg | 0 / 0 | 0.5 m | -10.25 m |
| Forge tank | 2,500 kg | 6,000 / 12,000 kg | 11.5 m | -16.25 m |
| Forge atmospheric engine | 900 kg | 0 / 0 | 2 m | -23 m |

These six instances are coaxial; the capsule defines the root and +Y forward. Adjacent bottom/top nodes mate at the listed boundaries. Overall external length remains 26 m and maximum radius 1.5 m. Visual nozzle/interstage details must fit the defined collider envelopes.

Aggregate checks: 29,000 kg initial mass; 6,000 kg all-dry mass; 18,000 kg booster propellant; 5,000 kg upper propellant. Separated booster dry mass remains 3,500 kg and retained upper assembly starts at 7,500 kg wet. Retain 540/100 kN vacuum thrust, 285–320/270–360 s Isp and 2:1 oxidizer/fuel ratio. Vacuum ideal total delta-v remains approximately 6,921 m/s.

Preserve Space-key semantics using explicit ordered actions:

1. Ignite Forge engine.
2. Shut down Forge, break the upper-engine/interstage edge, then ignite Lumen on the retained command component.

The explicit shutdown preserves today's passive spent booster. A structural break later does **not** implicitly shut down engines: severed components keep ignition/throttle and remaining fuel unless damage or a defined action changes them. The final propulsion stage stays attached for parity; capsule separation is a later craft-design option.

Create `data/craft/orbital_test_vehicle.json` and minimal matching catalog resources. Keep `data/orbital_test_vehicle.tres`, EngineDefinition, StageDefinition and RocketStage intact as source fixtures until the converter and new flight path pass. Add Basic Suborbital Rocket with the broader usable catalog in Phase 3; Moon Test Vehicle belongs to Phase 6.

### Compatibility without duplicate physics state

`SpacecraftState : FlightBody` becomes the general runtime. `RocketState : SpacecraftState` can remain as a thin compatibility facade for the existing constructor and OTV tests. Its stage index, `current_stage()` and stage summaries are **views over actual part/module state**, not second tanks or second mass totals. A `StageView` exposes the old read operations while new UI reads FlightSnapshot. A staging compatibility method may return the first detached component for the two-stage fixture; production code consumes the complete `StageResult.components` list exactly once.

Retain the old RocketState implementation as a clearly named test fixture, not a second production backend or a hidden orbit mode. Parameterize comparison tests around both factories. Keep existing numerical tolerances and behavior assertions; change test plumbing only where the public snapshot boundary changes. Do not erase an old test because the new design fails it.

## 7. Splitting the graph and conserving motion

Implement deliberate decoupling through one shared graph-split operation in Phase 1. Automatic load-driven cuts are Phase 2.

1. Resolve actions/failures to stable connection IDs at a substep boundary. Freeze the pre-split state and resource totals; remove all requested edges as one batch.
2. Find connected components with O(parts + connections) traversal. Transfer existing PartInstance/module states without rebuilding or refilling them.
3. Recalculate each component's COM and full inertia from its remaining parts. Keep the inherited craft axes initially.
4. For component COM offset `rho_k` from the old COM, assign `X_k = X + rotate(Q, rho_k)` and `V_k = V + omega_world cross rotate(Q, rho_k)`. Preserve Q and angular velocity. All part world poses and point velocities remain continuous.
5. Apply a decoupler's equal-and-opposite impulses at the shared attachment point, including their angular impulses about each new COM. Use inverse-mass/inertia effective mass for a configured separation speed. Structural failure alone adds no arbitrary kick or spin.
6. Choose the active command component, update fuel routes, stage ownership, views/colliders and registry membership; invalidate coast warp. Newly created bodies begin their next full substep together, not an extra integration pass in the split tick.

Tests must check mass/resource totals, each part's identity/position/velocity, total linear momentum and total angular momentum **about a common inertial reference**, including orbital terms. Decoupler energy is supplied by its configured spring/ejection model; passive breakage creates no kinetic energy. The present mass-weighted centre offsets and arbitrary debris spin are not suitable as the general algorithm.

## 8. Structural loads, failure and damage — Phase 2 design only

Start rigid; do not implement elastic joint chains. Cache tree parent/child order and aggregate subtrees. With part-centroid offset `rho_i`, approximate its rigid-body acceleration as:

```text
a_i = a_COM + alpha_world cross rho_i
      + omega_world cross (omega_world cross rho_i)
residual_force_i = m_i * a_i - external_force_i
```

External forces include gravity, engine, aero and later contacts/buoyancy, with explicit application points. Sum each subtree's residual forces for its connecting joint's reaction. Sum their moments about the joint, plus each part's rotational inertia/couple residual, for the joint moment. Include mass-flow momentum terms during powered tests. Uniform free fall must give approximately zero joint load: counting gravity twice would falsely break an orbiting craft.

Resolve reactions into the attachment frame: signed axial tension/compression, perpendicular shear, bending moment and axial torsion. Report utilization against separate ratings. Initially use the maximum individual utilization as a documented independent-limit approximation, not an FEA or material fatigue model. Above-rated joints fail deterministically; capture diagnostic loads and queue the edge cut. Evaluate all joints before mutating topology to avoid iteration-order-dependent cascades. Multiple cuts use the same component splitter.

For actual cyclic structures, tree cuts do not determine load sharing; keep cycles unsupported until a stiffness-weighted constraint solution is validated. Stiffness/damping fields can exist earlier but have no physical flex effect yet. Optional small, bounded visual flex comes only after failure tests pass, and cannot disagree with collision geometry.

Per-part collision proxies supply contact identity, normal, point and penetration/relative speed to a single assembly contact solver. Compute impulses using the contacted assembly's effective mass and full inertia; include rotational point velocity and friction. Feed contact impulses divided by the fixed substep into the structural ledger. Use swept shape/segment tests or conservative substeps for fast impacts.

Damage is based on per-part impulse/energy limits, not random rolls. A gentle contact can remain supported; a leg can fail before its payload; a tank can become a ruptured physical wreck. Destroyed command capability does not delete the entire graph. Preserve nearby wreckage/resources or account for expelled material explicitly; remove wrecks only through a documented distant/settled lifecycle. Restrain explosions to energetic/fuel-bearing destruction; ordinary joint breakage produces separation and creaks/snaps. Render/audio events carry the cause and energy, and never drive forces themselves.

## 9. Editor, engineering analysis and craft serialization — Phase 3 design

The editor manipulates CraftDesign through reversible commands, not live SpacecraftState. Commands include place/move/rotate/detach/delete/duplicate, group edits, stage-action moves and undo/redo. Attachment compatibility and occupied-node checks run before committing placement. Use local broad-phase bounds followed by primitive/convex overlap checks with a small mating-contact tolerance; previews never modify the live design until accepted.

Radial 1/2/3/4/6/8 symmetry expands transforms around the selected parent axis and assigns a symmetry-group ID. Group operations preserve corresponding branches and generate independent runtime instances. Cutting/deleting the root requires selecting another eligible command root or creating a new design, not leaving a silently invalid craft.

Layout: catalog left; 3D assembly and attachment/COM/thrust/pressure markers centre; part settings right; action-based staging bottom; New/Save/Load/Launch top. Launch requires a connected valid design and command capability. Catalog grows to capsule/probe, three tank sizes, three engine roles, stack/radial decouplers and adapter, nose/fin/control surface, wheel, parachute and landing leg. Utility modules need their actual deployment/control behavior before being offered as functional parts.

Use the same mass/fuel/engine calculators for editor estimates. Display dry/wet mass, propellant, active-stage thrust, sea-level/vacuum TWR, stage/total ideal delta-v and burn time. Stage analysis runs actions on a disposable design-derived copy, partitions accessible fuel and discards jettisoned mass; it must not sum every tank once per engine. For mixed engines use simultaneous mass flow and effective exhaust velocity; label estimates that assume vacuum or constant throttle. Show thrust line/torque about COM, not just a centre marker. Aero-pressure indicators are directional estimates; issue a useful warning when thrust is offset from COM.

### Versioned design-only JSON

Proposed path: `user://craft/<sanitized-name>.json`. Catalog Resources remain shipped `.tres`; player files refer to catalog IDs, not arbitrary scripts or absolute resource paths. A minimal example is:

```json
{
  "schema_version": 1,
  "catalog_version": 1,
  "name": "Training stack",
  "root_part_id": "command-1",
  "parts": [
    {"id": "command-1", "definition_id": "command.capsule.small", "position_m": [0, 0, 0], "rotation_xyzw": [0, 0, 0, 1], "settings": {}},
    {"id": "tank-1", "definition_id": "tank.lumen", "position_m": [0, -5.25, 0], "rotation_xyzw": [0, 0, 0, 1], "settings": {"fuel_fill": 1.0, "oxidizer_fill": 1.0}},
    {"id": "engine-1", "definition_id": "engine.lumen", "position_m": [0, -9.25, 0], "rotation_xyzw": [0, 0, 0, 1], "settings": {"gimbal_enabled": true}}
  ],
  "connections": [
    {"id": "joint-1", "a": ["command-1", "bottom"], "b": ["tank-1", "top"], "crossfeed": true},
    {"id": "joint-2", "a": ["tank-1", "bottom"], "b": ["engine-1", "top"], "crossfeed": true}
  ],
  "symmetry_groups": [],
  "stages": [{"id": "stage-1", "actions": [{"part_id": "engine-1", "module_id": "engine", "action": "ignite"}]}]
}
```

Positions/orientations are root-local and validated against the connection rest frames. Initial fill settings are assembly choices, not remaining fuel from a flight. Do not serialize inertial position/velocity, elapsed time, accumulated joint load, temperature, active ignition or damage. Future flight saves need a separate schema.

Validate finite numbers, bounds/capacities, unique IDs, references, module/action compatibility, node mating/occupancy, root connectivity and the no-cycle rule before replacing the current design. Unknown future schema versions are rejected with a useful message; migrate known old versions in memory and retain the original on disk. Save atomically through a temporary file and rename. On load failure, preserve the editor's current craft. Phase 1 implements the codec and fixtures headlessly; Save/Load UI waits for Phase 3.

## 10. Surface, visual and celestial extension boundaries

These are integration decisions for review, not permission to implement Phases 4–6 now.

| Phase | Proposed approach and gate |
| --- | --- |
| **4 — terrain/ocean** | Add a body-fixed `SurfaceQuery` that supplies height, normal, material, ocean level and water state from double body-relative coordinates. A cube-sphere chunk/LOD renderer and nearby collision proxies sample the same field. Match launchpad/near-contact geometry to the authoritative surface; test chunk seams and LOD changes. Replace the tangent plane only after contact tests pass. |
| **4 — water** | Continuous planetary ocean at configured sea-level radius, with orbit and near-surface rendering. Per-part submerged volume/centroid supplies `rho_water * V_submerged * local_g` buoyancy; relative fluid motion supplies translational/angular drag. Apply forces at buoyancy/drag centres. Resolve entry impulses and damage without treating water as a rigid floor. Add splash/spray/foam/wake/ripples, camera submersion tint and limited visibility. Test capsule equilibrium/bobbing, dense-engine sinking, asymmetric floating and high-speed destructive entry. |
| **5 — living planet** | Separate cloud shells with advected procedural noise, approximate obscuration and optional shadows; atmospheric limb, daytime horizon and terminator colours; ocean normals/specular/depth colour. Share a Sun direction across sky, surface lighting, night emission and later Moon. Cluster city-light masks on land; daylight/altitude attenuation and optional cloud masking. Preserve the validated density law. |
| **6 — celestial system** | Generalize PlanetDefinition into CelestialBodyDefinition plus ephemeris state: ID, parent, radius/mu, orbital elements or initial state, rotation/tilt, atmosphere/ocean/terrain/visual definitions, SOI. Use one simulation epoch for all craft, planet rotation and moon state. Proposed moon name **Neris**, configurable and airless. Derive period consistently from orbit and mu rather than accepting contradictory values. |
| **6 — map/surface** | Display Neris and its orbit, dominant body/SOI and trajectory segments with encounter transitions/periapsis where predicted. Reuse terrain queries for cratered regolith, sharp light and lunar leg contacts. Add a Moon Test Vehicle only after a physical transfer, capture/escape/return and landing test can be demonstrated. |

### Multi-body recommendation and numerical risks

Retain the current Kepler solver as a **relative two-body kernel**. A future CelestialSystem supplies body position/velocity; do not feed planet-global craft coordinates into a Moon-relative propagation. At a reference-body change, preserve inertial craft position and velocity exactly and only change the relative coordinates/telemetry reference. Body dominance must not itself circularize/capture a trajectory.

Phase 6 should compare two consistent modes with a fixed translunar regression before choosing the production policy:

- **Patched-conic mode:** the same dominant-body gravity in ordinary flight, prediction and coast warp. This is the simplest deterministic KSP-style path using the existing solver, but is an explicit approximation to other bodies' perturbations.
- **Summed gravity mode:** sum moving-body accelerations in a defined inertial frame; use numerical prediction/high-warp integration near encounters. Analytic coast is allowed only where a measured perturbation/error budget makes it appropriate. Do not silently switch between incompatible force models merely because the player changes warp.

Recommendation: make consistent patched conics the first Phase 6 acceptance candidate, then evaluate summed gravity as a tested fidelity option. If summed gravity is retained in Aster-centred accelerating coordinates, include the frame's indirect acceleration; alternatively migrate to barycentric state once with explicit conversions. Moon SOI entry/exit requires crossing detection over the entire time interval, refined event times and hysteresis. A 1,000× step cannot skip an encounter. SOI is a gameplay/reference boundary, not a physical discontinuity in true n-body gravity.

The future world must therefore use a session clock (not the active rocket's `elapsed` as the celestial epoch) and a force-environment interface. Introduce those seams in Phase 1 while Aster's state remains the current constant-centre special case. Do not add Moon forces or change orbital validation now.

## 11. Concrete file/class migration inventory

Paths in this section are **proposed files**, not files already implemented by this review.

| Phase | New files/resources | Existing files changed |
| --- | --- | --- |
| 1: definitions/design | `definitions/part_definition.gd`, `attachment_node_definition.gd`, `connection_definition.gd`, `craft_design.gd`, `stage_action_definition.gd`; `definitions/modules/` with base/engine/tank/command/wheel/decoupler definitions; `data/parts/*.tres`; `data/craft/orbital_test_vehicle.json` | Keep existing engine/stage/vehicle resources for conversion and oracle tests. |
| 1: graph/state | `simulation/parts/part_instance.gd`, `part_graph.gd`, `connection_state.gd`; `simulation/modules/*_state.gd`; `simulation/spacecraft_state.gd`; `craft_factory.gd`, `legacy_vehicle_converter.gd`, `craft_codec.gd` | `rocket_state.gd` becomes a compatibility facade only after new runtime tests pass; `rocket_stage.gd` remains for legacy engine tests. |
| 1: dynamics/systems | `simulation/symmetric_tensor.gd`, `mass_properties.gd`, `mass_flow_ledger.gd`, `force_ledger.gd`, `fuel_network.gd`, `engine_system.gd`, `stage_controller.gd`, `spacecraft_splitter.gd`, `legacy_envelope_aerodynamics.gd`, `flight_snapshot.gd`, `stage_view.gd` | `flight_body.gd` gains wrench/full-inertia support with old defaults; `attitude_controller.gd` emits torque requests; `flight_computer.gd` reads snapshots. DVec3/gravity/orbit kernels stay compatible. |
| 1: orchestration/views | `simulation/flight_session.gd`, `spacecraft_registry.gd`; `game/spacecraft_visual.gd`, `part_visual.gd` | `game/main.gd` delegates session/staging, `rocket_visual.gd` retains primitive helpers, HUD/nav/map/FX consume snapshots, TimeWarp checks module activity. Update Linux build's source-copy inventory if new top-level directories are introduced. |
| 1: validation | `tests/fixtures/legacy_rocket_state.gd`; new part-mass, graph, fuel, wrench, split, codec, conversion and matched-ascent tests | Existing suites and both pilots retained; runner adds the new suites and reports runtime error logs. |
| 2 | `simulation/structure/structural_solver.gd`, `joint_load.gd`, `damage_model.gd`; `simulation/part_aerodynamics.gd`, `contact_solver.gd`; `game/part_collision_proxy.gd`, debris/failure FX/audio; structural overlay and in-flight part inspector | Session event/split handling, impact lifecycle and near-debris cleanup; force ledger and snapshots. |
| 3 | `game/assembly/` scene/controller/placement/selection tools; `ui/assembly/` catalog/properties/staging/engineering controls; design command history, symmetry and design validation; rest of part catalog and suborbital craft | Menu flow and launch factory; file dialog/save-load UI uses the Phase 1 codec. |
| 4–5 | Terrain/ocean definitions and SurfaceQuery; terrain chunks/LOD/colliders; buoyancy/water drag; clouds/atmosphere/ocean/city-light shaders and contact/water FX | WorldVisual, contacts, shared environmental state, surface-aware predictions and audio attenuation. |
| 6 | CelestialBodyDefinition, body state/system/ephemeris, SOI tracker, gravity/prediction policy adapters, Neris definitions/surface, lunar test fixtures | Relative adapters around Kepler/elements, global clock/warp guard, map/world render, gravity environment and body-aware telemetry. |

## 12. Performance and determinism

Cache dry mass moments, part transforms/collider bounds, graph traversal order and fuel reachability. Resource changes update tank contributions and aggregate mass/COM/inertia once per substep, not once per engine or force evaluation. Structural subtree sums are O(N + E); topology cuts occur only as queued events. Use broad-phase bounds/spatial bins for shielding and contacts instead of all-pairs tests for every part at every tick.

Evaluate representative 10/50/100/300-part craft at 120 simulated Hz, normal and 4× warp, with explicit counters for force calls, graph rebuilds, allocations and contact pairs. Proposed budget on the measured development machine: 100-part flight simulation below 4 ms per 60 Hz tick at 1× and below 16 ms at 4×, separate from rendering; record actual hardware/timings rather than claim portability. A 300-part stress case must remain finite and responsive; profile before promising a frame-rate target.

Near active/failing/contacting bodies retain full physics. Distant quiet components may use existing coast propagation when eligible, but cannot silently lose active engines/resources. Cap or reduce warp when important events require fixed substeps. Cache UI/map/editor statistics at presentation rates and keep IDs/events stable. Determinism means identical commands/step counts on the same runtime; cross-platform bit identity is not promised.

## 13. Phase 1 sequence and stop gate

After architecture approval, perform these steps in order:

1. Capture current factories/resources and both ascent traces as the reference; run all current suites in an isolated project copy.
2. Add immutable part/module/design definitions, graph validation and design-only codec. Create the six-part OTV recipe and converter. Prove exact dry/propellant/wet totals before flight integration.
3. Add mass properties/full inertia and reference-preserving COM updates. Validate known asymmetric examples and coordinate invariance at orbital distances.
4. Add tank routing, atomic multi-engine allocation, actual nozzle force/torque and controller torque handoff. Test starvation, cutoff, pressure interpolation, gimbal direction and off-axis angular response.
5. Add graph-based deliberate staging and multi-component registry ownership. Validate separation conservation and state continuity; keep automatic breakage disabled.
6. Connect the new runtime to session/views through the facade/snapshot, retaining all flight/map/warp controls. Render the same external OTV from identifiable parts.
7. Run the old suites and new unit/integration tests, then both matched launch profiles and engine-off orbits. Report measured differences and remaining limitations. **Stop here for review.**

### Quantitative acceptance criteria (proposed before implementation)

| Area | Required evidence |
| --- | --- |
| Definitions/mass | Dry, tank and total mass equal the fixed OTV totals to 1e-6 kg. Known COM cases to 1e-6 m, symmetric inertia/parallel-axis cases within 1e-8 relative using scalar-double calculations. No nonpositive inertia. |
| Fuel/thrust | Existing Isp/flow/depletion/cutoff tests retain their tolerances. Fuel cannot cross the closed interstage link; competing engines share shortages deterministically; mass/COM/inertia and remaining delta-v update. |
| Wrench/attitude | Centred opposed forces produce the analytic resultant; off-centre thrust produces the analytic sign/magnitude of torque and short-step angular acceleration; no double SAS/aero torque. Gimbal bounds/slew honored. |
| Split | Correct components/IDs; all resources and engine states retained; no pose jump above 1e-5 m or unintended velocity jump above 1e-6 m/s before the configured impulse. Linear/angular momentum conserved to 1e-8 relative with explicit absolute floors for zero-resultant cases. No unexplained kinetic-energy gain. |
| Precision | Translating the simulation origin by a large DVec3 offset leaves local contacts, part spacing and aggregate properties unchanged within the stated local tolerances. No authoritative render-space round trip. |
| Orbit/atmosphere | Existing gravity, density, drag, circular/ellipse/escape/radial, coast, warp and map tests pass at their current thresholds. |
| Matched ascent | Same reference controls and throttle/stage actions; preserve 29 t/26 m reference geometry and engine data. After the six-part COM launch-height adjustment, target <=2% differences in mass/force/speed and ascent envelope, <=5% Max-Q difference, orbit insertion time within 5 s, final Ap within 5 km, final Pe 65–70 km, remaining upper fuel within 2 percentage points of the recorded 72.6–72.7%. Both pilots must establish a stable orbit and meet the existing 5 m engine-off periapsis-drift limit. |
| Codec | Design round trip preserves topology/settings/stages/symmetry, contains no flight state, and rejects invalid/unknown schemas without overwriting current craft. |
| Playability | Menu, launch, controls, SAS, intentional staging/debris, pause, reentry FX, 1–4×/coast warp, map, and relaunch remain functional. New per-part identities/resources are inspectable in debug validation. |

The matched-ascent envelopes are acceptance proposals, not results. A real shift from cylinder inertia to distributed mass cannot be promised bit-identical. If a threshold fails, diagnose and report it; do not widen limits, change engine performance or alter gravity silently to force a pass.

Later stop gates: Phase 2 proves sub-rated survival, overload failure, multi-cut conservation, meaningful gentle/hard/catastrophic contact and visible nearby debris. Phase 3 proves building/saving/reloading/launching a two-stage rocket from scratch. Phase 4 proves terrain/water contact and equilibrium; Phase 5 validates day/night/cloud/ocean appearance and performance; Phase 6 proves a repeatable translunar encounter, lunar orbit/escape/return and terrain landing. Each gate reruns applicable previous validations.

## 14. Migration risks and review decisions

| Risk | Mitigation / review choice |
| --- | --- |
| COM changes teleport meshes or inject orbital energy | Separate immutable design frame from COM; explicit mass-flow/reference updates and invariant point-velocity tests. |
| Cylinder-to-tensor migration destabilizes SAS | Test full tensor separately; isolate controller wrench generation; use explicit actuator authority with preserved command limits. |
| Connected booster consumes upper-stage fuel | Separate structural adjacency from fuel crossfeed; closed interstage by default in the converted craft. |
| Staging loses resources, engines or angular momentum | One batched splitter, stable IDs, common-reference conservation tests and no fabricated offsets/spin. |
| Structural stress reports loads in free fall or depends on edge order | Subtree force/moment balance includes gravity and mass flow; process all cuts at substep boundary; reject loops until supported. |
| Part aero changes an already flyable ascent | Explicit Phase 1 envelope provider, force-budget comparison before introducing shielding/fin effects, matched pilots. |
| Old stage fields keep a second physics model alive | Derived facade/snapshots only; retain the original implementation solely as a test fixture; audit consumers before removing adapters. |
| Impact ends the whole craft or wrecks disappear nearby | Phase 2 per-part contact/damage and component lifecycle replace both crash flag handling and cleanup together. |
| Warp ignores a live fragment or skips terrain/SOI events | Evaluate eligibility per component and refine boundary/event times; shared clock; fall back to fixed physics where needed. |
| Moon frame/mixed gravity changes trajectories when warp changes | One documented propagation policy per fidelity mode; relative-state conversion and encounter regression. |
| Visual surface disagrees with collision/water | One SurfaceQuery feeds rendering, contacts and buoyancy; test LOD seams and shoreline transitions. |
| New files trigger stale editor resource IDs | Continue isolated CLI imports/tests, preserve `.uid` files, avoid deleting caches belonging to the user's open editor. |
| Scope grows into simultaneous editor/terrain/Moon work | Approve Phase 1 separately and stop at its gate. Future interfaces are described here, not implemented pre-emptively. |

Approval is requested for the hybrid/tree-first design, six-part OTV conversion, explicit temporary aero compatibility provider, tensor/COM migration, action staging, design-only JSON and the Phase 1 validation envelopes. Phases 2–6 remain sequenced future work.

## References checked

- [Godot 4.6 large-world coordinates](https://docs.godotengine.org/en/4.6/tutorials/physics/large_world_coordinates.html): scalar float versus Vector precision and standard-engine constraints.
- [Godot 4.6 RigidBody3D](https://docs.godotengine.org/en/4.6/classes/class_rigidbody3d.html): engine integration ownership; informs avoiding two independent integrators for the same assembly.
- [Godot 4.6 physics introduction](https://docs.godotengine.org/en/4.6/tutorials/physics/physics_introduction.html): fixed-step physics and collision-query context.

The structural approximation, file layout, migration tolerances and phase boundaries above are project-specific design proposals, not claims that Godot provides these systems automatically.
