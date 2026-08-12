// common_responder.asl
// ====================================================================
// Shared responder library for ambulance.asl, firetruck.asl, and
// police.asl.
//
// Type-specific files define only:
//   my_vehicle_type("medical" | "fire" | "patrol").
//   +!onSceneWork(IncId,Loc,Sev).
//   +!afterSceneWork(IncId,Loc,Sev).
//
// This shared file implements:
//   - vehicle artifact creation and map initialisation;
//   - Contract-Net bid submission;
//   - normal organisational assignment and mRespond commitment;
//   - Dijkstra next-hop routing and smooth map animation;
//   - return and normal incident closure;
//   - decentralised fallback / serious-fire medical backup;
//   - background fuel-station resource use.
//
// Prerequisites:
//   - CityMapArtifact.java exposes getNextHop(from,to,nextNode).
//   - Each vehicle is configured in evds.jcm with cityMap, board, and
//     its station fuel-pump artifact focused.
// ====================================================================

/* ---------- vehicle bootstrap ---------- */

// Called from each vehicle agent's initial JCM goal:
// setupVehicle("Station_North") or setupVehicle("Station_South").
+!setupVehicle(Home)
   <- .my_name(Me);

      // Local beliefs used by routing and return-to-station plans.
      +home_station(Home);
      +at(Home);

      // Artifact focus is asynchronous; retry map lookup if necessary.
      !safeGetCoords(Home,X0,Y0);

      // Every responder owns one VehicleArtifact. Its observable status,
      // posX, and posY properties become beliefs once focused.
      .concat(Me,"_veh",VehArtName);
      ?joined(cityHub,CityHubWid);
      makeArtifact(VehArtName,"evds.VehicleArtifact",
                   [Me,X0,Y0],VehId)[wid(CityHubWid)];
      +veh_art(VehId);
      focus(VehId);

      // Obtain the shared live map artifact and display initial state.
      lookupArtifact("mapView",MapViewId)[wid(CityHubWid)];
      +map_view(MapViewId);
      vehicleUpdate(Me,X0,Y0,"idle")[artifact_id(MapViewId)];

      .print("[VEHICLE] ",Me," ready at ",Home);

      // Start independent low-priority refuelling loop.
      !fuelLoop.

// Successful branch: cityMap focus is ready and coordinates are returned.
+!safeGetCoords(Node,X,Y)
   <- getCoords(Node,X,Y).

// Failure branch: wait briefly and retry when focus has not completed.
-!safeGetCoords(Node,X,Y)
   <- .wait(300);
      !safeGetCoords(Node,X,Y).

// General asynchronous workspace-join retry helper.
+?joined(Name,Id)
   <- .wait(100);
      ?joined(Name,Id).

/* ---------- shared vehicle/map update ---------- */

// Keep VehicleArtifact state and CityMapGUI state synchronized.
// All movement/status changes go through this one helper.
+!pushToMap(X,Y,Status)
   <- ?veh_art(VehId);
      updatePosition(X,Y,Status)[artifact_id(VehId)];

      ?map_view(MapViewId);
      .my_name(Me);
      vehicleUpdate(Me,X,Y,Status)[artifact_id(MapViewId)].

/* ---------- Contract-Net bidding ---------- */

// A responder bids only when:
//   1. Its observable VehicleArtifact status is idle; and
//   2. my_vehicle_type(Type) exactly matches the incident's string type.
+!bid(IncId,Type,Loc) : status("idle") & my_vehicle_type(Type)
   <- ?at(Node);

      // CityMapArtifact uses congestion-aware Dijkstra routing.
      getETA(Node,Loc,Eta);

      .my_name(Me);
      .print("[BID] ",Me,
             " bidding for ",IncId,
             " at ",Loc,
             "; ETA ~",Eta,"s");

      // DispatchBoardArtifact stores the responder name and ETA.
      submitBid(IncId,Me,Eta).

// Safe catch-all: busy or mismatched responders silently ignore the bid.
+!bid(_,_,_).

/* ---------- normal organisational response assignment ---------- */

// dispatcher1 sends this only to the Contract-Net winner.
// Store values locally before committing because the winner needs Loc
// and Sev later for routing/scene work; this avoids Java-string issues
// with direct scheme goalArgument retrieval.
+!joinIncident(IncId,Loc,Sev)
   <- +assigned_incident(IncId,Loc,Sev);

      // The dispatcher creates one Moise scheme named sch_<IncId>.
      .concat("sch_",IncId,SchName);
      ?joined(evdsOrg,OrgWid);
      lookupArtifact(SchName,SchArtId)[wid(OrgWid)];
      focus(SchArtId);

      .print("[ASSIGNMENT] received ",IncId,
             " at ",Loc," (severity ",Sev,")");

      // Permission for mRespond is defined in evds-os.xml. Committing
      // enables the organisational respondOnScene goal for this winner.
      commitMission(mRespond)[artifact_id(SchArtId)].

// Moise/org-obedient enables this after the winning responder commits.
+!respondOnScene[scheme(Sch)]
   <- ?assigned_incident(IncId,Loc,Sev);

      .print("[RESPONDER] travelling to ",Loc,
             " for ",IncId);

      !travelTo(Loc);

      // Explicit final on-scene update after the route reaches Loc.
      ?at(Node);
      getCoords(Node,X,Y);
      !pushToMap(X,Y,"on_scene");

      // Defined by ambulance.asl, firetruck.asl, or police.asl.
      !onSceneWork(IncId,Loc,Sev).

// Moise/org-obedient enables this after respondOnScene is fulfilled.
+!closeIncident[scheme(Sch)]
   <- ?assigned_incident(IncId,Loc,Sev);

      .print("[RESPONDER] scene work complete for ",IncId,
             "; returning to station");

      // Type-specific post-scene work: e.g. ambulance hospital admission
      // or serious-fire medical backup request.
      !afterSceneWork(IncId,Loc,Sev);
      !returnToStation;

      // DispatchBoardArtifact decrements active count and signals the
      // dispatcher, which removes the GUI incident marker.
      closeOutIncident(IncId);

      .print("[RESPONDER] incident ",IncId,
             " closed; vehicle is available again");

      -assigned_incident(IncId,Loc,Sev).

/* ---------- shortest-path movement and smooth visual animation ---------- */

// Start a journey from the vehicle's logical at(Origin) node.
+!travelTo(Dest)
   <- ?at(Origin);
      getCoords(Origin,OX,OY);
      !pushToMap(OX,OY,"en_route");
      !followRoute(Origin,Dest).

// Base case: no movement remains after reaching destination node.
+!followRoute(Dest,Dest).

// Move one Dijkstra hop at a time. getNextHop returns a normal node
// string; this avoids trying to pattern-match opaque Java List objects.
+!followRoute(Current,Dest)
   <- getNextHop(Current,Dest,Next);

      getCoords(Current,CX,CY);
      getCoords(Next,NX,NY);

      // Smoothly animate this one road segment before changing logical
      // at(Current) to at(Next).
      !animateSegment(CX,CY,NX,NY,1);

      -at(_);
      +at(Next);

      !followRoute(Next,Dest).

// Animation base case after ten interpolation updates.
+!animateSegment(_,_,_,_,11).

// Ten updates × 70 ms gives approximately the previous 700 ms road-hop
// timing while making yellow markers glide visually between graph nodes.
+!animateSegment(X1,Y1,X2,Y2,Step)
   : Step <= 10
   <- Ratio = Step / 10;
      X = X1 + (X2 - X1) * Ratio;
      Y = Y1 + (Y2 - Y1) * Ratio;

      !pushToMap(X,Y,"en_route");

      .wait(70);

      NextStep = Step + 1;
      !animateSegment(X1,Y1,X2,Y2,NextStep).

// Return uses exactly the same Dijkstra movement machinery.
+!returnToStation
   <- ?home_station(Home);
      !travelTo(Home);
      ?at(Node);
      getCoords(Node,X,Y);
      !pushToMap(X,Y,"idle").

/* ---------- decentralised fallback / serious-fire medical backup ---------- */

// This plan can be triggered by supervisor1 after an allocation SLA
// breach or by a fire truck requesting medical backup for Sev >= 4.
// It is intentionally different from normal dispatcher Contract-Net:
// responders self-select using ETA-proportional contention delay.
+!selfAssign(IncId,Type,Loc)
   : status("idle")
     & not claimed(IncId)
     & not assigned_incident(_,_,_)
     & not fallback_assignment(_)
     & my_vehicle_type(Type)
   <- ?at(Node);
      getETA(Node,Loc,Eta);

      // The lowest ETA responder normally waits least and claims first.
      DelayMs = Eta * 150;
      .wait(DelayMs);

      // Re-check after waiting: a normal dispatcher assignment might
      // have arrived while the responder was waiting.
      if (not claimed(IncId)
          & not assigned_incident(_,_,_)
          & not fallback_assignment(_)) {

         +fallback_assignment(IncId);
         .broadcast(tell,claimed(IncId));

         .print("[FALLBACK] self-assigning to ",IncId,
                " at ",Loc," (ETA ~",Eta,"s)");

         !travelTo(Loc);

         ?at(SceneNode);
         getCoords(SceneNode,SX,SY);
         !pushToMap(SX,SY,"on_scene");

         // A fallback request carries no original severity, so a safe
         // default value of 1 is supplied to type-specific plans.
         !onSceneWork(IncId,Loc,1);
         !afterSceneWork(IncId,Loc,1);

         !returnToStation;
         -fallback_assignment(IncId);
      }.

// Ignore requests when busy, mismatched, assigned, or already claimed.
+!selfAssign(_,_,_).

/* ---------- background fuel resource use ---------- */

// Each responder already focuses its station fuel artifact in evds.jcm.
// refuel blocks inside FuelStationArtifact until a pump becomes free.
+!fuelLoop
   <- .wait(math.random*25000+20000);
      if (status("idle")) {
         refuel;
      }
      !fuelLoop.

{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }
{ include("$moise/asl/org-obedient.asl") }