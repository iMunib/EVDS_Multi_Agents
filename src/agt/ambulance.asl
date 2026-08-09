// ambulance.asl -- medical responder.
// Movement, bidding, org plans and the fallback protocol all come from
// common_responder.asl; this file only defines what an ambulance
// actually *does* at a scene and afterwards.

my_vehicle_type("medical").

// Known hospital artifact names (each hospital agent creates its own,
// see hospital.asl). A more open system would discover these through a
// directory/yellow-pages artifact instead of a static list -- noted as
// a simplification in the report.
hospital_artifact("hospital_general_art").
hospital_artifact("hospital_stmarys_art").

+!onSceneWork(IncId,Loc,Sev)
   <- .print("[AMBULANCE] treating patient at ",Loc," (severity ",Sev,")");
      .wait(1500).

+!afterSceneWork(IncId,Loc,Sev)
   <- !deliverToNearestHospital(Sev).

+!deliverToNearestHospital(Sev)
   <- .findall(H,hospital_artifact(H),All);
      !tryHospitals(All,Sev).

+!tryHospitals([],Sev)
   <- .print("[AMBULANCE] every hospital is full -- holding patient and retrying");
      .wait(3000);
      !deliverToNearestHospital(Sev).

+!tryHospitals([HArt|Rest],Sev)
   <- lookupArtifact(HArt,HId);
      admitPatient(Accepted)[artifact_id(HId)];
      if (Accepted) {
         .print("[AMBULANCE] patient admitted at ",HArt);
      } else {
         !tryHospitals(Rest,Sev);
      }.

{ include("common_responder.asl") }
