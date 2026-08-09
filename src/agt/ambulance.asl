// ambulance.asl -- medical responder.
// Movement, bidding, organisational response handling, and fallback
// behaviour come from common_responder.asl. This file provides the
// ambulance-specific patient-treatment and hospital-admission logic.

my_vehicle_type("medical").

// These names are created by hospital.asl:
// hospital_general  -> hospital_general_art
// hospital_stmarys  -> hospital_stmarys_art
hospital_artifact("hospital_general_art").
hospital_artifact("hospital_stmarys_art").

+!onSceneWork(IncId,Loc,Sev)
   <- .print("[AMBULANCE] treating patient at ",Loc,
             " (severity ",Sev,")");
      .wait(1500).

+!afterSceneWork(IncId,Loc,Sev)
   <- !deliverToAvailableHospital(Sev).

+!deliverToAvailableHospital(Sev)
   <- .findall(H,hospital_artifact(H),Hospitals);
      !tryHospitals(Hospitals,Sev).

// If both hospitals are full, the ambulance remains occupied and
// retries later. Hospital agents independently discharge patients,
// so capacity can become available without another request.
+!tryHospitals([],Sev)
   <- .print("[AMBULANCE] all hospitals are full; holding patient and retrying");
      .wait(3000);
      !deliverToAvailableHospital(Sev).

// Look up every hospital in cityHub explicitly. Without [wid(...)],
// lookupArtifact searches the ambulance's current/default workspace
// and fails with ArtifactNotAvailableException.
+!tryHospitals([HArt|Rest],Sev)
   <- ?joined(cityHub,CityHubWid);
      lookupArtifact(HArt,HId)[wid(CityHubWid)];

      admitPatient(Accepted)[artifact_id(HId)];

      if (Accepted) {
         .print("[AMBULANCE] patient admitted at ",HArt);
      } else {
         !tryHospitals(Rest,Sev);
      }.

{ include("common_responder.asl") }