// police.asl -- patrol responder.
// Movement, bidding, org plans and the fallback protocol all come from
// common_responder.asl; this file only defines what a police unit
// actually *does* at a scene and afterwards.

my_vehicle_type("patrol").

+!onSceneWork(IncId,Loc,Sev)
   <- .print("[POLICE] securing the scene and directing traffic at ",Loc);
      .wait(1200).

+!afterSceneWork(IncId,Loc,Sev)
   <- .print("[POLICE] scene cleared, road reopened at ",Loc).

{ include("common_responder.asl") }
