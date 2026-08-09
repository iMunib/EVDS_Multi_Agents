// dispatcher.asl
//
// Owns the "allocateVehicle" mission (mDispatch) of incidentResponseScheme.
// Reacts to the DispatchBoard's "incident" event (environment-mediated
// intake), opens a scheme instance per incident, runs a Contract-Net
// round over the board (environment-mediated bidding), then hands the
// winner off with a direct message (agent-mediated notification) --
// three coordination styles used back to back on purpose, so the
// contrast between them is visible in one short plan sequence.

+!setupDispatch <- .print("[DISPATCH] EVDS dispatcher online").
!setupDispatch.

+?joined(Name,Id) <- .wait(100); ?joined(Name,Id).

+incident(IncId,Type,Loc,Sev)
   <- .concat("sch_",IncId,SchName);
      +incident_data(IncId,Type,Loc,Sev);
      ?joined(evdsOrg,OrgWid);
      createScheme(SchName,incidentResponseScheme,SchArtId)[wid(OrgWid)];
      setArgumentValue(handleIncident,"IncId",IncId)[artifact_id(SchArtId)];
      setArgumentValue(handleIncident,"Type",Type)[artifact_id(SchArtId)];
      setArgumentValue(handleIncident,"Loc",Loc)[artifact_id(SchArtId)];
      setArgumentValue(handleIncident,"Sev",Sev)[artifact_id(SchArtId)];
      .my_name(Me);
      setOwner(Me)[artifact_id(SchArtId)];
      focus(SchArtId);
      addScheme(SchName)[wid(OrgWid)];
      // commitMission(mDispatch) intentionally NOT called explicitly here --
      // org-obedient.asl already reacts to dispatcher1's n1 obligation and
      // commits mDispatch automatically (see "I am obliged to commit..." in
      // the log). Calling it a second time here was tested and is suspected
      // of interfering with the scheme's goal-enablement notification for
      // allocateVehicle -- see README for what was actually observed.
      // let the supervisor watch this scheme's obligations for SLA breaches
      .send(supervisor1,tell,newScheme(SchName,IncId,Type,Loc));
      // put a marker on the live map
      getCoords(Loc,LX,LY);
	  showIncident(IncId,Type,Sev,LX,LY).

+!allocateVehicle[scheme(Sch)]
   <- .print("[DISPATCH] processing scheme ",Sch);

      // Take one pending incident record from the dispatcher's
      // local queue. It is removed immediately so another scheme
      // instance cannot dispatch the same incident a second time.
      ?incident_data(IncId,Type,Loc,Sev);
      -incident_data(IncId,Type,Loc,Sev);

      .print("[DISPATCH] requesting ",Type,
             " bids for ",IncId," at ",Loc);

      .broadcast(achieve,bid(IncId,Type,Loc));

      collectBids(IncId,6000,Winner,Eta);

      .print("[DISPATCH] assigning ",Winner," to ",IncId,
             " (best ETA ~",Eta,"s)");

      .send(Winner,achieve,joinIncident(IncId,Loc,Sev)).

-!allocateVehicle[scheme(Sch)]
   <- ?goalArgument(Sch,handleIncident,"IncId",IncId);
      .print("[DISPATCH] WARNING: no vehicle allocated for ",IncId,
             " within the SLA window -- handing off to peer-to-peer fallback").

+incidentClosed(IncId)
   <- clearIncident(IncId).

{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }
{ include("$moise/asl/org-obedient.asl") }
