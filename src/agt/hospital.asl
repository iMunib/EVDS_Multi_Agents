// hospital.asl (FIXED)
//
// BUG: the original makeArtifact() call had no [wid(...)] annotation,
// so the HospitalArtifact was created in this agent's own default
// workspace. ambulance.asl's lookupArtifact("hospital_general_art",HId)
// (also with no wid) only succeeds if it happens to search the same
// workspace -- fragile, and observed to fail once agents explicitly
// join multiple workspaces. Fix: create it explicitly in cityHub,
// the one workspace every vehicle agent also joins.

+!setupHospital(Cap)
   <- .my_name(Me);
      .concat(Me,"_art",ArtName);
      ?joined(cityHub,CityHubWid);
      makeArtifact(ArtName,"evds.HospitalArtifact",[Cap],HId)[wid(CityHubWid)];
      +hosp_art(HId);
      focus(HId);
      .print("[HOSPITAL] ",Me," online with ",Cap," beds");
      !turnover.

+?joined(Name,Id) <- .wait(100); ?joined(Name,Id).

// Autonomous behaviour: the hospital is not just a passive resource --
// it periodically discharges a patient on its own initiative, freeing a
// bed without anyone asking.
+!turnover
   <- .wait(math.random*20000+15000);
      ?hosp_art(HId);
      dischargePatient[artifact_id(HId)];
      !turnover.

{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }
{ include("$moise/asl/org-obedient.asl") }
