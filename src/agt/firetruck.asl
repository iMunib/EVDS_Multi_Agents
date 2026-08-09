// firetruck.asl -- fire responder.
// Movement, bidding, org plans and the fallback protocol all come from
// common_responder.asl; this file only defines what a fire truck
// actually *does* at a scene and afterwards.

my_vehicle_type("fire").

+!onSceneWork(IncId,Loc,Sev)
   <- .print("[FIRETRUCK] suppressing fire at ",Loc," (severity ",Sev,")");
      .wait(2000).

// For serious fires we ask for medical backup on the spot. Rather than
// invent a second dispatch mechanism, this simply reuses the very same
// selfAssign primitive that supervisor1 uses for SLA-breach fallback:
// one reusable "ask any idle peer to come here directly" building
// block, used both for resilience and for ordinary in-field requests.
+!afterSceneWork(IncId,Loc,Sev)
   <- .print("[FIRETRUCK] scene secured");
      if (Sev >= 4) {
         .print("[FIRETRUCK] requesting medical backup at ",Loc);
         .broadcast(achieve,selfAssign(IncId,"medical",Loc));
      }.

{ include("common_responder.asl") }
