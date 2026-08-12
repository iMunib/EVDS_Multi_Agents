// supervisor.asl
// ====================================================================
// EVDS organisational supervisor.
//
// Organisation role: supervisor_role
// Mission: none in incidentResponseScheme
//
// supervisor1 deliberately does not dispatch or respond to emergencies.
// It watches each incident scheme's Moise events. If the dispatcher does
// not fulfil allocateVehicle before its organisational deadline, Moise
// emits oblUnfulfilled and supervisor1 starts the decentralised fallback
// protocol in common_responder.asl.
// ====================================================================

// Wait/retry helper for asynchronous JCM workspace joins.
+?joined(Name,Id)
   <- .wait(100);
      ?joined(Name,Id).

// dispatcher1 sends this after it creates an incident scheme.
// supervisor1 focuses the named scheme board so it can perceive that
// particular scheme's obligation events. incident_watch keeps the
// incident details associated with the focused artifact ID.
+newScheme(SchName,IncId,Type,Loc)
   <- ?joined(evdsOrg,OrgWid);
      lookupArtifact(SchName,SchArtId)[wid(OrgWid)];
      focus(SchArtId);
      +incident_watch(SchArtId,IncId,Type,Loc).

// Moise emits this event when allocateVehicle is not achieved before
// its ttf deadline (20 seconds in evds-os.xml). The artifact_id context
// ensures the event is matched to the correct incident scheme when
// multiple schemes are active concurrently.
+oblUnfulfilled(obligation(_,_,achieved(_,allocateVehicle,_),_))[artifact_id(SchArtId)]
   : incident_watch(SchArtId,IncId,Type,Loc)
   <- .print("[SUPERVISOR] SLA breached for ",IncId,
             " -- switching to peer-to-peer fallback");

      // This is NOT a retry of dispatcher bidding. It is a decentralised
      // agent broadcast. Idle responders of the matching type calculate
      // ETA, wait in proportion to ETA, and the fastest normally claims
      // the incident using the selfAssign protocol.
      .broadcast(achieve,selfAssign(IncId,Type,Loc)).

{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }
{ include("$moise/asl/org-obedient.asl") }