// firetruck.asl
// ====================================================================
// Fire responder specialisation.
//
// common_responder.asl supplies all shared responder behaviour:
// vehicle setup, Contract-Net bidding, organisational assignment,
// Dijkstra movement, map animation, normal return, fallback, and fuel.
//
// This file only supplies behaviour unique to a fire truck.
// ====================================================================

// Must remain a Jason string because incident generator/dispatcher
// broadcasts incident types as strings such as "fire".
my_vehicle_type("fire").

// Called after this fire truck arrives at the incident location and the
// Moise respondOnScene goal is enabled for it.
+!onSceneWork(IncId,Loc,Sev)
   <- .print("[FIRETRUCK] suppressing fire at ",Loc,
             " (severity ",Sev,")");

      // Simulated fire suppression duration.
      .wait(2000).

// Called before the responder returns to station during closeIncident.
+!afterSceneWork(IncId,Loc,Sev)
   <- .print("[FIRETRUCK] scene secured");

      // Severity 4 and 5 fires request medical backup. This uses the
      // same decentralised selfAssign primitive as supervisor fallback;
      // it is not a second normal mRespond assignment.
      if (Sev >= 4) {
         .print("[FIRETRUCK] requesting medical backup at ",Loc);
         .broadcast(achieve,selfAssign(IncId,"medical",Loc));
      }.

{ include("common_responder.asl") }