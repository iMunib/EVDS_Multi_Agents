// dispatcher.asl
// ====================================================================
// EVDS central dispatcher.
//
// Organisation role: dispatcher
// Organisational mission: mDispatch
// Organisational goal fulfilled: allocateVehicle
//
// Coordination sequence for each incident:
//   1. Perceive incident(...) from DispatchBoardArtifact.
//   2. Create and configure a Moise scheme instance.
//   3. Tell supervisor1 to monitor that scheme.
//   4. Request Contract-Net ETA bids from all agents.
//   5. DispatchBoardArtifact selects the lowest ETA bid.
//   6. Directly assign the winning responder.
// ====================================================================

// Startup message and initial goal.
+!setupDispatch
   <- .print("[DISPATCH] EVDS dispatcher online").

!setupDispatch.

// Declarative JCM workspace joins complete asynchronously. Retry the
// test goal until the requested workspace identifier becomes available.
+?joined(Name,Id)
   <- .wait(100);
      ?joined(Name,Id).

// --------------------------------------------------------------------
// INCIDENT INTAKE
// --------------------------------------------------------------------
// Triggered once when DispatchBoardArtifact signals:
// incident(IncId,Type,Loc,Sev).
//
// Example: incident("inc12","fire","Airport",4)
+incident(IncId,Type,Loc,Sev)
   <- // Scheme names are unique per incident, e.g. sch_inc12.
      .concat("sch_",IncId,SchName);

      // Keep a local dispatcher-side incident record. This avoids relying
      // on Moise goalArgument for Java-string location values later.
      +incident_data(IncId,Type,Loc,Sev);

      // Create the organisational scheme in the Moise workspace.
      ?joined(evdsOrg,OrgWid);
      createScheme(SchName,incidentResponseScheme,SchArtId)[wid(OrgWid)];

      // Fill the scheme's documented incident arguments.
      setArgumentValue(handleIncident,"IncId",IncId)[artifact_id(SchArtId)];
      setArgumentValue(handleIncident,"Type",Type)[artifact_id(SchArtId)];
      setArgumentValue(handleIncident,"Loc",Loc)[artifact_id(SchArtId)];
      setArgumentValue(handleIncident,"Sev",Sev)[artifact_id(SchArtId)];

      // Make dispatcher1 the scheme owner, focus the scheme board, then
      // register the scheme with the organisation.
      .my_name(Me);
      setOwner(Me)[artifact_id(SchArtId)];
      focus(SchArtId);
      addScheme(SchName)[wid(OrgWid)];

      // mDispatch is NOT explicitly committed here. org-obedient.asl
      // reacts to the dispatcher obligation defined in evds-os.xml and
      // commits automatically. Explicit double commitment can interfere
      // with Moise goal-enablement behaviour.

      // Give supervisor1 the data needed to monitor this scheme's SLA.
      .send(supervisor1,tell,newScheme(SchName,IncId,Type,Loc));

      // Display a labelled incident marker on CityMapGUI.
      getCoords(Loc,LX,LY);
      showIncident(IncId,Type,Sev,LX,LY).

// --------------------------------------------------------------------
// STANDARD CONTRACT-NET ALLOCATION
// --------------------------------------------------------------------
// Triggered after the organisation enables allocateVehicle for mDispatch.
+!allocateVehicle[scheme(Sch)]
   <- .print("[DISPATCH] processing scheme ",Sch);

      // Remove one queued incident record so another concurrent scheme
      // cannot allocate the same incident again.
      ?incident_data(IncId,Type,Loc,Sev);
      -incident_data(IncId,Type,Loc,Sev);

      .print("[DISPATCH] requesting ",Type,
             " bids for ",IncId," at ",Loc);

      // Contract-Net call for proposals. Every agent receives the goal,
      // but only idle responders whose my_vehicle_type(Type) matches
      // submit a bid; other agents safely ignore it.
      .broadcast(achieve,bid(IncId,Type,Loc));

      // Open/hold the environment-mediated bidding window for 6000 ms.
      // DispatchBoardArtifact returns the responder with the lowest ETA.
      collectBids(IncId,6000,Winner,Eta);

      .print("[DISPATCH] assigning ",Winner," to ",IncId,
             " (best ETA ~",Eta,"s)");

      // Direct agent-to-agent award. Location and severity are sent so
      // the winner can store them locally before committing to mRespond.
      .send(Winner,achieve,joinIncident(IncId,Loc,Sev)).

// If allocation fails or is dropped, Moise's deadline mechanism can
// later generate an oblUnfulfilled event for supervisor1 to observe.
-!allocateVehicle[scheme(Sch)]
   <- ?goalArgument(Sch,handleIncident,"IncId",IncId);
      .print("[DISPATCH] WARNING: no vehicle allocated for ",IncId,
             " within the SLA window -- handing off to peer-to-peer fallback").

// DispatchBoardArtifact emits incidentClosed after normal closeout.
// Remove the GUI marker and its incident-information label.
+incidentClosed(IncId)
   <- clearIncident(IncId).

{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }
{ include("$moise/asl/org-obedient.asl") }