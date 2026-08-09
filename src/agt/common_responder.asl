// common_responder.asl
// Shared behaviour for ambulance.asl, firetruck.asl, and police.asl.
//
// Prerequisites:
// - ambulance.asl must contain: my_vehicle_type("medical").
// - firetruck.asl must contain: my_vehicle_type("fire").
// - police.asl must contain:    my_vehicle_type("patrol").
// - CityMapArtifact.java must include the getNextHop(from,to,nextNode)
//   CArtAgO operation added during the routing fix.

/* ---------- bootstrap: create this responder's vehicle state ---------- */

+!setupVehicle(Home)
   <- .my_name(Me);
      +home_station(Home);
      +at(Home);

      // The cityMap focus declared in evds.jcm is asynchronous.
      // Wait/retry until getCoords can be invoked successfully.
      !safeGetCoords(Home,X0,Y0);

      .concat(Me,"_veh",VehArtName);
      ?joined(cityHub,CityHubWid);

      makeArtifact(VehArtName,"evds.VehicleArtifact",
                   [Me,X0,Y0],VehId)[wid(CityHubWid)];
      +veh_art(VehId);
      focus(VehId);

      lookupArtifact("mapView",MapViewId)[wid(CityHubWid)];
      +map_view(MapViewId);
      vehicleUpdate(Me,X0,Y0,"idle")[artifact_id(MapViewId)];

      .print("[VEHICLE] ",Me," ready at ",Home);
      !fuelLoop.

+!safeGetCoords(Node,X,Y)
   <- getCoords(Node,X,Y).

-!safeGetCoords(Node,X,Y)
   <- .wait(300);
      !safeGetCoords(Node,X,Y).

// Workspace joins declared in the JCM configuration finish asynchronously.
+?joined(Name,Id) <- .wait(100); ?joined(Name,Id).

/* ---------- vehicle/map update helper ---------- */

+!pushToMap(X,Y,Status)
   <- ?veh_art(VehId);
      updatePosition(X,Y,Status)[artifact_id(VehId)];

      ?map_view(MapViewId);
      .my_name(Me);
      vehicleUpdate(Me,X,Y,Status)[artifact_id(MapViewId)].

/* ---------- Contract-Net bidding ---------- */

// An idle responder bids only when its declared vehicle type exactly
// matches the string type in the incident broadcast.
+!bid(IncId,Type,Loc) : status("idle") & my_vehicle_type(Type)
   <- ?at(Node);
      getETA(Node,Loc,Eta);
      .my_name(Me);

      .print("[BID] ",Me,
             " bidding for ",IncId,
             " at ",Loc,
             "; ETA ~",Eta,"s");

      submitBid(IncId,Me,Eta).

// Ignore bids while busy or when the emergency type does not match.
+!bid(_,_,_).

/* ---------- organisational response assignment ---------- */

// dispatcher1 sends joinIncident(IncId,Loc,Sev) only to the winning
// Contract-Net bidder. Keep the assignment locally rather than relying
// on Moise goalArgument for Java-string-valued locations.
+!joinIncident(IncId,Loc,Sev)
   <- +assigned_incident(IncId,Loc,Sev);

      .concat("sch_",IncId,SchName);
      ?joined(evdsOrg,OrgWid);
      lookupArtifact(SchName,SchArtId)[wid(OrgWid)];
      focus(SchArtId);

      .print("[ASSIGNMENT] received ",IncId,
             " at ",Loc," (severity ",Sev,")");

      commitMission(mRespond)[artifact_id(SchArtId)].

// mRespond enables this organisational goal after the winner commits.
+!respondOnScene[scheme(Sch)]
   <- ?assigned_incident(IncId,Loc,Sev);

      .print("[RESPONDER] travelling to ",Loc,
             " for ",IncId);

      !travelTo(Loc);

      ?at(Node);
      getCoords(Node,X,Y);
      !pushToMap(X,Y,"on_scene");

      !onSceneWork(IncId,Loc,Sev).

// mRespond enables closeIncident after respondOnScene is achieved.
+!closeIncident[scheme(Sch)]
   <- ?assigned_incident(IncId,Loc,Sev);

      .print("[RESPONDER] scene work complete for ",IncId,
             "; returning to station");

      !afterSceneWork(IncId,Loc,Sev);
      !returnToStation;

      closeOutIncident(IncId);

      .print("[RESPONDER] incident ",IncId,
             " closed; vehicle is available again");

      -assigned_incident(IncId,Loc,Sev).

/* ---------- shortest-path movement and smooth map animation ---------- */

+!travelTo(Dest)
   <- ?at(Origin);
      getCoords(Origin,OX,OY);
      !pushToMap(OX,OY,"en_route");
      !followRoute(Origin,Dest).

// End condition: the vehicle has arrived at the destination node.
+!followRoute(Dest,Dest).

// Obtain one Dijkstra hop at a time. getNextHop is implemented by
// CityMapArtifact and returns a normal node string, avoiding opaque
// Java list objects in AgentSpeak.
+!followRoute(Current,Dest)
   <- getNextHop(Current,Dest,Next);

      getCoords(Current,CX,CY);
      getCoords(Next,NX,NY);

      !animateSegment(CX,CY,NX,NY,1);

      -at(_);
      +at(Next);

      !followRoute(Next,Dest).

// Base case: ten visual interpolation updates have been sent.
+!animateSegment(_,_,_,_,11).

// Move one tenth of a road segment every 70 ms. Ten updates take about
// 700 ms, preserving the prior road-segment timing while making the
// yellow vehicle marker glide rather than jump between graph nodes.
+!animateSegment(X1,Y1,X2,Y2,Step)
   : Step <= 10
   <- Ratio = Step / 10;

      X = X1 + (X2 - X1) * Ratio;
      Y = Y1 + (Y2 - Y1) * Ratio;

      !pushToMap(X,Y,"en_route");

      .wait(70);

      NextStep = Step + 1;
      !animateSegment(X1,Y1,X2,Y2,NextStep).

+!returnToStation
   <- ?home_station(Home);
      !travelTo(Home);
      ?at(Node);
      getCoords(Node,X,Y);
      !pushToMap(X,Y,"idle").

/* ---------- decentralised fallback / medical backup ---------- */

/* ---------- decentralised fallback / medical backup ---------- */

// A responder may use fallback only when:
// - it is idle,
// - another agent has not already claimed this incident,
// - it has no normal dispatcher assignment,
// - it has not already started another fallback assignment,
// - and its vehicle type matches the requested type.

+!selfAssign(IncId,Type,Loc)
   : status("idle")
     & not claimed(IncId)
     & not assigned_incident(_,_,_)
     & not fallback_assignment(_)
     & my_vehicle_type(Type)

   <- ?at(Node);

      getETA(Node,Loc,Eta);

      // Lower ETA responders wait less, so they normally claim first.
      DelayMs = Eta * 150;
      .wait(DelayMs);

      // Re-check all conditions after waiting. A normal dispatcher
      // assignment may have arrived while this agent waited.
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

         // Fallback requests do not include original severity.
         !onSceneWork(IncId,Loc,1);
         !afterSceneWork(IncId,Loc,1);

         !returnToStation;

         -fallback_assignment(IncId);
      }.

// Ignore fallback requests when busy, already assigned, claimed,
// or a mismatched vehicle type.
+!selfAssign(_,_,_).
/* ---------- background fuel-station resource use ---------- */

// Each responder already focuses its own station's fuel artifact through
// evds.jcm (stationNorth.fuelPumpN or stationSouth.fuelPumpS).
+!fuelLoop
   <- .wait(math.random*25000+20000);
      if (status("idle")) {
         refuel;
      }
      !fuelLoop.

{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }
{ include("$moise/asl/org-obedient.asl") }