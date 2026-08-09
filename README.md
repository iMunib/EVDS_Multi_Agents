# EVDS — Emergency Vehicle Dispatch System

> CST3118 Group Project · JaCaMo / Jason / CArtAgO / Moise

EVDS is a multi-agent emergency-dispatch simulation. It models incoming emergency calls, dispatches the most suitable available vehicle using a Contract-Net-style bidding round, routes responders over a traffic-sensitive city road graph, visualises activity on a live Swing map, manages hospital bed capacity, and coordinates roles and response missions through a Moise organisation.

The project deliberately demonstrates all three JaCaMo dimensions:

- **Agents** make local decisions and execute BDI plans.
- **Environment artifacts** provide shared routing, bidding, hospital, fuel, and GUI resources.
- **Organisation** defines roles, missions, permissions, obligations, goals, and response deadlines.

---

## Contents

- [Quick start](#quick-start)
- [What the simulation does](#what-the-simulation-does)
- [Map legend](#map-legend)
- [Severity levels](#severity-levels)
- [Architecture](#architecture)
- [Agents](#agents)
- [Environment artifacts](#environment-artifacts)
- [Organisation](#organisation)
- [Dispatch lifecycle](#dispatch-lifecycle)
- [Folder structure](#folder-structure)
- [Key files](#key-files)
- [Expected console output](#expected-console-output)
- [Testing checklist](#testing-checklist)
- [Known simplifications](#known-simplifications)

---

## Quick start

### Prerequisites

- Java 21, matching the project JRE configuration.
- A JaCaMo Gradle scaffold/project setup.
- Gradle wrapper files in the project root.

### Run

From the project root:

```powershell
.\gradlew clean run
```

On Linux/macOS:

```bash
./gradlew clean run
```

The application starts the JaCaMo runtime services, the Moise organisation server, CArtAgO workspaces, the agent mind inspector, and the `EVDS - City Dispatch Map` Swing window.

### Useful runtime endpoints

The exact host/ports are printed at startup. Typical services include:

- Agent mind inspector: `http://<host>:3272`
- CArtAgO HTTP server: `http://<host>:3273`
- Moise HTTP server: `http://<host>:3271`

---

## What the simulation does

1. `incident_generator` creates a medical, fire, or patrol emergency at a city node.
2. `dispatcher1` receives the incident from `DispatchBoardArtifact`.
3. The dispatcher creates a Moise scheme instance, records the incident data, and displays a labelled red incident marker on the map.
4. The dispatcher requests bids from responders.
5. Idle responders of the matching type calculate a traffic-sensitive Dijkstra ETA using `CityMapArtifact` and submit a bid to `DispatchBoardArtifact`.
6. The board waits for the bidding window, chooses the lowest ETA, and returns the winning vehicle.
7. The dispatcher sends the winner an assignment containing the incident ID, location, and severity.
8. The winning responder commits to `mRespond`, follows the shortest route, and updates its position/status on the map.
9. The responder performs type-specific on-scene work.
10. The responder returns to its home station, closes the incident, and becomes idle again.

Medical responders also reserve a bed in a hospital resource artifact before returning. If all beds are unavailable, an ambulance remains occupied and retries until a hospital has capacity.

---

## Map legend

| Visual | Meaning |
|---|---|
| Green vehicle marker | Idle responder at a station or after returning home |
| Yellow vehicle marker | Vehicle is travelling along a Dijkstra route |
| Red vehicle marker | Vehicle is on scene performing response work |
| Red incident circle | Active emergency location |
| Incident label | Incident ID, incident type, and severity, for example `inc12 | fire | Sev 3` |

Vehicles that share a station are vertically separated so their labels remain readable. A vehicle at an active incident is drawn below the incident marker to avoid overlapping the incident label.

---

## Severity levels

Every generated incident receives an integer severity from **1** through **5**:

| Severity | Interpretation in the simulation | Current behavioural effect |
|---:|---|---|
| 1 | Low priority | Standard response workflow |
| 2 | Moderate priority | Standard response workflow |
| 3 | Significant incident | Standard response workflow |
| 4 | Major incident | Fire incidents request medical backup after fire-scene work |
| 5 | Critical incident | Fire incidents request medical backup after fire-scene work |

Severity is displayed in the map incident label and passed to each responder's `onSceneWork` / `afterSceneWork` plans. Fire trucks use `Sev >= 4` to broadcast a medical-backup request. The current project does not change road speed, bid priority, or hospital choice by severity; those are suitable future extensions.

---

## Architecture

### Agent dimension

Jason AgentSpeak files define BDI plans for dispatching, responding, hospital turnover, incident generation, traffic updates, and supervision.

### Environment dimension

CArtAgO artifacts own shared state and domain operations:

- City graph, node coordinates, traffic congestion, Dijkstra ETA, and next-hop routing.
- Shared incident and bid board.
- Vehicle observable state.
- Hospital capacity.
- Fuel-pump resource contention.
- Swing map state and rendering.

### Organisation dimension

Moise defines responder roles, dispatch and response missions, scheme goals, responder permissions, dispatcher obligation, and response deadlines.

---

## Agents

| Agent(s) | Role / responsibility |
|---|---|
| `dispatcher1` | Creates incident schemes, requests bids, chooses the lowest ETA, and assigns the winner |
| `supervisor1` | Watches organisational obligations and can initiate decentralised fallback after an allocation SLA breach |
| `amb1`, `amb2`, `amb3` | Medical responders; treat patients and reserve hospital beds |
| `fire1`, `fire2` | Fire responders; suppress fires and request medical backup for severity 4–5 fires |
| `police1`, `police2` | Patrol responders; secure scenes and direct traffic |
| `hospital_general` | Creates `hospital_general_art` with 12 initial beds and periodically discharges patients |
| `hospital_stmarys` | Creates `hospital_stmarys_art` with 8 initial beds and periodically discharges patients |
| `incident_generator` | Generates simulated emergency calls |
| `traffic_monitor` | Randomly updates congestion multipliers on existing roads |

### Vehicle types

The incident type and vehicle type values are Jason strings and must remain consistent:

```prolog
// ambulance.asl
my_vehicle_type("medical").

// firetruck.asl
my_vehicle_type("fire").

// police.asl
my_vehicle_type("patrol").
```

A responder bids only when it is idle and its vehicle type matches the incident type.

---

## Environment artifacts

| Artifact | Java file | Purpose |
|---|---|---|
| `cityMap` | `CityMapArtifact.java` | Stores nodes, roads, coordinates, congestion, Dijkstra routing, ETA, and next-hop operations |
| `board` | `DispatchBoardArtifact.java` | Creates incident IDs, receives bids, holds the bidding window, and selects the lowest ETA winner |
| `mapView` | `CityMapGUI.java` | Renders vehicle positions/statuses and labelled active incidents |
| Per-vehicle artifacts | `VehicleArtifact.java` | Stores each vehicle name, coordinates, and status; drives GUI updates |
| Hospital artifacts | `HospitalArtifact.java` | Stores available bed capacity and supports admission/discharge |
| Station fuel artifacts | `FuelStationArtifact.java` | Models limited fuel pumps using CArtAgO guard/await resource scheduling |

### Workspaces

| Workspace | Contents |
|---|---|
| `cityHub` | `cityMap`, `board`, `mapView`, vehicles, and hospital resources |
| `stationNorth` | `fuelPumpN` |
| `stationSouth` | `fuelPumpS` |
| `evdsOrg` | Moise organisation board, group board, and incident scheme boards |

---

## Organisation

The organisational specification is in `src/org/evds-os.xml`.

### Roles

- `dispatcher`
- `ambulance_role`
- `firetruck_role`
- `police_role`
- `hospital_role`
- `supervisor_role`
- abstract `responder` role, extended by ambulance/fire/police roles

### Scheme: `incidentResponseScheme`

Each incident creates one scheme instance, for example `sch_inc12`.

The scheme goals execute in sequence:

1. `allocateVehicle` — dispatcher runs the bid/award round.
2. `respondOnScene` — selected responder travels and performs scene work.
3. `closeIncident` — responder completes post-scene work, returns home, and closes the incident.

### Missions

| Mission | Holder | Goals |
|---|---|---|
| `mDispatch` | `dispatcher1` | `allocateVehicle` |
| `mRespond` | One assigned responder | `respondOnScene`, `closeIncident` |

`mRespond` has a maximum cardinality of one. This prevents multiple responders from committing to the same standard incident response mission.

### Norms

- The dispatcher has an obligation to commit to `mDispatch`.
- Ambulance, firetruck, and police roles have permission to commit to `mRespond` after winning the bid.
- No responder obligation automatically commits all responders to `mRespond`; selection remains controlled by the dispatcher’s Contract-Net result.

---

## Dispatch lifecycle

### Standard response

```text
911 incident
  → dispatcher creates scheme
  → matching idle vehicles bid ETA
  → board selects lowest ETA
  → dispatcher assigns winner
  → winner travels yellow
  → winner arrives red/on scene
  → scene work
  → return yellow
  → station green/idle
  → incident marker removed
```

### Medical response

```text
Medical incident
  → ambulance wins bid
  → treatment on scene
  → hospital bed admission attempt
  → return to station
  → incident closeout
```

### Fire response

```text
Fire incident
  → fire truck wins bid
  → suppression on scene
  → for severity 4–5: request medical backup
  → return to station
  → incident closeout
```

### Fallback response

If the dispatcher fails to allocate a vehicle before the organisational deadline, `supervisor1` can broadcast `selfAssign(...)`. Matching idle responders delay proportionally to ETA; the fastest responder normally claims the incident first. This is a simplified decentralised contention protocol, not a consensus algorithm.

---

## Folder structure

```text
EVDS/
├── build.gradle
├── settings.gradle
├── gradlew
├── gradlew.bat
├── evds.jcm
├── README.md
│
└── src/
    ├── agt/
    │   ├── ambulance.asl
    │   ├── common_responder.asl
    │   ├── dispatcher.asl
    │   ├── firetruck.asl
    │   ├── hospital.asl
    │   ├── incident_generator.asl
    │   ├── police.asl
    │   ├── supervisor.asl
    │   └── traffic_monitor.asl
    │
    ├── env/
    │   └── evds/
    │       ├── CityMapArtifact.java
    │       ├── CityMapGUI.java
    │       ├── DispatchBoardArtifact.java
    │       ├── FuelStationArtifact.java
    │       ├── HospitalArtifact.java
    │       └── VehicleArtifact.java
    │
    └── org/
        └── evds-os.xml
```

---

## Key files

### `evds.jcm`

Defines the MAS configuration: agents, initial goals, workspaces, artifacts, organisational roles, and artifact focus declarations.

### `common_responder.asl`

Shared implementation used by ambulances, fire trucks, and police vehicles. It contains vehicle creation, bidding, assignment receipt, route movement, smooth interpolation, return-to-station, fallback logic, and refuelling.

### `dispatcher.asl`

Receives incidents, creates organisational schemes, stores incident data, runs the Contract-Net round, assigns the winner, and updates the GUI marker.

### `CityMapArtifact.java`

Externalises road-network knowledge. It contains Dijkstra routing and congestion-aware ETA calculations. Agents do not need to implement graph search themselves.

### `DispatchBoardArtifact.java`

Provides environment-mediated coordination for incident intake and the bidding window. It selects the responder with the smallest submitted ETA.

### `CityMapGUI.java`

Provides live visualization with vehicle status colours, non-overlapping vehicle labels, incident details, and the map legend.

### `HospitalArtifact.java`

Provides a shared, capacity-limited bed resource. Ambulances call `admitPatient`; hospital agents periodically call `dischargePatient`.

### `FuelStationArtifact.java`

Demonstrates resource contention with limited pumps, guards, and CArtAgO waits.

---

## Expected console output

A healthy standard dispatch should include messages similar to:

```text
[911] new fire incident inc8 at University (severity 3)
[DISPATCH] requesting fire bids for inc8 at University
[BID] fire1 bidding for inc8 at University; ETA ~40s
[BID] fire2 bidding for inc8 at University; ETA ~135s
[DISPATCH] assigning fire1 to inc8 (best ETA ~40s)
[ASSIGNMENT] received inc8 at University (severity 3)
[RESPONDER] travelling to University for inc8
[FIRETRUCK] suppressing fire at University (severity 3)
[RESPONDER] incident inc8 closed; vehicle is available again
```

A healthy medical response should additionally include:

```text
[AMBULANCE] treating patient at Airport (severity 2)
[AMBULANCE] patient admitted at hospital_general_art
[RESPONDER] incident inc... closed; vehicle is available again
```

---

## Testing checklist

Before submitting or demonstrating the project, verify all of the following:

- [ ] `gradlew clean run` starts with no Java, CArtAgO, Jason, or XML parsing error.
- [ ] The map window appears and shows idle vehicles in green.
- [ ] Incident markers display ID, type, and severity.
- [ ] A police incident receives patrol bids and dispatches one police unit.
- [ ] A fire incident receives fire-truck bids and dispatches one fire truck.
- [ ] A medical incident receives ambulance bids and dispatches one ambulance.
- [ ] A selected vehicle becomes yellow and moves smoothly across route segments.
- [ ] A selected vehicle becomes red when it reaches the incident.
- [ ] Fire/police responders return to their home station and become green.
- [ ] Ambulances admit a patient to a hospital and then return to their station.
- [ ] An incident circle and label disappear after closeout.
- [ ] Traffic-monitor messages change road congestion during the simulation.
- [ ] A severity 4 or 5 fire emits a medical-backup request.

---

## Known simplifications

These are intentional course-project scope decisions and good discussion points for a report or presentation:

1. **Hospital order is static.** Ambulances try `hospital_general_art` before `hospital_stmarys_art`; the implementation demonstrates capacity coordination rather than true nearest-hospital selection.
2. **Traffic changes between routing queries.** A vehicle chooses a Dijkstra next hop based on the current congestion state; later hops can be recalculated after congestion updates.
3. **Fallback is lightweight.** The ETA-delay claim mechanism is not fault-tolerant distributed consensus.
4. **Incidents are simulated.** `incident_generator` replaces a real 911/API input source.
5. **Vehicle motion is visual.** Smooth map movement interpolates between graph nodes; it is a visualization of route progress, not a physical motion model.
6. **Fuel is a background demonstration.** Fuel contention is intentionally outside the critical dispatch path.
7. **One responder per standard scheme.** `mRespond` has max cardinality one; serious-fire medical backup uses the separate fallback-style request instead of opening a second full response scheme.

---

## Demonstration script

A concise presentation sequence:

1. Start EVDS with `gradlew clean run`.
2. Point out the green vehicle markers, labelled incidents, map legend, and two station workspaces.
3. Wait for an incident; explain the type and severity label.
4. Show matching responders submit ETA bids.
5. Highlight the dispatcher selecting the lowest ETA.
6. Follow the yellow vehicle movement and red on-scene state.
7. Show type-specific fire, police, or ambulance output.
8. For medical incidents, show hospital admission and bed-resource coordination.
9. Show the vehicle return green and the incident marker disappear.
10. Explain traffic updates, organisation roles/missions, and the fallback protocol.

---

## License / course use

This project is intended for academic demonstration as part of the CST3118 group project. Review course requirements before reusing or publishing the code outside the course context.
