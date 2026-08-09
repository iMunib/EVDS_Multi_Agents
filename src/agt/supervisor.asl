// supervisor.asl
//
// Plays supervisor_role but is deliberately NOT given a mission in
// incidentResponseScheme -- its job is to watch the normative dimension
// from the outside, not to do dispatch work itself. For every scheme
// dispatcher1 opens, it namespace-focuses that scheme board (so beliefs
// from several concurrently active incidents never collide -- e.g.
// "sch_inc4::oblUnfulfilled(...)" vs "sch_inc7::oblUnfulfilled(...)")
// and reacts if the mDispatch obligation (allocateVehicle) is not
// fulfilled before its deadline, switching that incident to the
// decentralised peer-to-peer protocol implemented in
// common_responder.asl (+!selfAssign).

+?joined(Name,Id) <- .wait(100); ?joined(Name,Id).

+newScheme(SchName,IncId,Type,Loc)
   <- ?joined(evdsOrg,OrgWid);
      lookupArtifact(SchName,SchArtId)[wid(OrgWid)];
      focus(SchArtId);
      +incident_watch(SchArtId,IncId,Type,Loc).

+oblUnfulfilled(obligation(_,_,achieved(_,allocateVehicle,_),_))[artifact_id(SchArtId)]
   :  incident_watch(SchArtId,IncId,Type,Loc)
   <- .print("[SUPERVISOR] SLA breached for ",IncId,
             " -- switching to peer-to-peer fallback");
      .broadcast(achieve,selfAssign(IncId,Type,Loc)).

{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }
{ include("$moise/asl/org-obedient.asl") }
