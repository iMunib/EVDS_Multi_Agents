// common_responder.asl (DIAGNOSTIC TRACE VERSION 2)
//
// Fix vs. the previous trace attempt: the fallback "+!bid(IncId,Type,Loc)"
// plan was missing its terminating "." after the .print(...) call --
// every Jason plan must end with a period, and that one only closed
// the print's parentheses, leaving the plan body technically
// unterminated. That's exactly why the parser choked on the very next
// line ("+!joinIncident...") -- it was still inside the previous plan.

+!setupVehicle(Home)
   <- .my_name(Me);
      +home_station(Home);
      +at(Home);
      !safeGetCoords(Home,X0,Y0);
      .concat(Me,"_veh",VehArtName);
      ?joined(cityHub,CityHubWid);
      makeArtifact(VehArtName,"evds.VehicleArtifact",[Me,X0,Y0],VehId)[wid(CityHubWid)];
      +veh_art(VehId);
      focus(VehId);
      lookupArtifact("mapView",MapViewId)[wid(CityHubWid)];
      +map_view(MapViewId);
      vehicleUpdate(Me,X0,Y0,"idle")[artifact_id(MapViewId)];
      .print("[TRACE] ",Me," setup complete. My beliefs: status=",status(_)," type=",my_vehicle_type(_));
      !fuelLoop.

+!safeGetCoords(Node,X,Y)
   <- getCoords(Node,X,Y).
-!safeGetCoords(Node,X,Y)
   <- .wait(300);
      !safeGetCoords(Node,X,Y).

+?joined(Name,Id) <- .wait(100); ?joined(Name,Id).

+!pushToMap(X,Y,Status)
   <- ?veh_art(VehId);
      updatePosition(X,Y,Status)[artifact_id(VehId)];
      ?map_view(MapViewId);
      .my_name(Me);
      vehicleUpdate(Me,X,Y,Status)[artifact_id(MapViewId)].

/* ---------- Contract-Net bidding when solicited by the dispatcher -------------- */

+!bid(IncId,Type,Loc) : status("idle")
   <- .my_name(Me);
      .print("[TRACE] ",Me," entered guarded +!bid for ",IncId,
             " (Type=",Type,", Loc=",Loc,")");
      ?my_vehicle_type(MyType);
      .term2string(Type,TypeS);
      .term2string(MyType,MyTypeS);
      .print("[TRACE] ",Me," TypeS=",TypeS," MyTypeS=",MyTypeS," equal=",(TypeS == MyTypeS));
      if (TypeS == MyTypeS) {
         ?at(Node);
         getETA(Node,Loc,Eta);
         .print("[TRACE] ",Me," got ETA ",Eta," from ",Node," to ",Loc,", submitting bid");
         submitBid(IncId,Me,Eta);
         .print("[TRACE] ",Me," submitBid call returned (no exception)");
      }.

// TRACE: if we land here instead of the plan above, the context guard
// (status("idle")) failed -- this prints proof of that, and shows the
// current status belief(s) so we can see the mismatch. NOTE the "."
// terminating the plan this time.
+!bid(IncId,Type,Loc) : status("idle") & my_vehicle_type(Type)
   <- ?at(Node);
      getETA(Node,Loc,Eta);
      .my_name(Me);
      .print("[BID] ",Me," bidding for ",IncId,
             " from ",Node," to ",Loc,"; ETA ~",Eta,"s");
      submitBid(IncId,Me,Eta).

+!bid(_,_,_).

/* ---------- organisational goal: I won the Contract-Net round ------------------ */

+!joinIncident(IncId)
   <- .concat("sch_",IncId,SchName);
      ?joined(evdsOrg,OrgWid);
      lookupArtifact(SchName,SchArtId)[wid(OrgWid)];
      focus(SchArtId);
      commitMission(mRespond)[artifact_id(SchArtId)].

+!respondOnScene[scheme(Sch)]
   <- ?goalArgument(Sch,handleIncident,"IncId",IncId);
      ?goalArgument(Sch,handleIncident,"Loc",Loc);
      ?goalArgument(Sch,handleIncident,"Sev",Sev);
      !travelTo(Loc);
      ?at(Node);
      getCoords(Node,X,Y);
      !pushToMap(X,Y,"on_scene");
      !onSceneWork(IncId,Loc,Sev).

+!closeIncident[scheme(Sch)]
   <- ?goalArgument(Sch,handleIncident,"IncId",IncId);
      ?goalArgument(Sch,handleIncident,"Loc",Loc);
      ?goalArgument(Sch,handleIncident,"Sev",Sev);
      !afterSceneWork(IncId,Loc,Sev);
      !returnToStation;
      closeOutIncident(IncId).

/* ---------- movement: follow the shortest path hop by hop ---------------------- */

+!travelTo(Dest)
   <- ?at(Origin);
      getCoords(Origin,OX,OY);
      !pushToMap(OX,OY,"en_route");
      getRoute(Origin,Dest,Path);
      !followRoute(Path).

+!followRoute([]).
+!followRoute([Node|Rest])
   <- getCoords(Node,NX,NY);
      !pushToMap(NX,NY,"en_route");
      -at(_);
      +at(Node);
      .wait(700);
      !followRoute(Rest).

+!returnToStation
   <- ?home_station(Home);
      !travelTo(Home);
      ?at(Node);
      getCoords(Node,X,Y);
      !pushToMap(X,Y,"idle").

/* ---------- decentralised fallback: peer-to-peer self-assignment --------------- */

+!selfAssign(IncId,Type,Loc)
   : status("idle") & not claimed(IncId) & my_vehicle_type(Type)
   <- ?at(Node2);
      getETA(Node2,Loc,Eta);
      DelayMs = Eta * 150;
      .wait(DelayMs);
      if (not claimed(IncId)) {
         .broadcast(tell,claimed(IncId));
         .print("[FALLBACK] self-assigning to ",IncId," (ETA ~",Eta,"s)");
         !travelTo(Loc);
         ?at(Node3);
         getCoords(Node3,X3,Y3);
         !pushToMap(X3,Y3,"on_scene");
         !onSceneWork(IncId,Loc,"unknown");
         !afterSceneWork(IncId,Loc,"unknown");
         !returnToStation;
      }.

+!selfAssign(_,_,_).

/* ---------- background fuel loop (uses the station's FuelStationArtifact) ------ */

+!fuelLoop
   <- .wait(math.random*25000+20000);
      if (status("idle")) {
         refuel;
      }
      !fuelLoop.

{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }
{ include("$moise/asl/org-obedient.asl") }