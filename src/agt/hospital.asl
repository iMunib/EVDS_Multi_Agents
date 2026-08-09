// hospital.asl
// Shared by hospital_general and hospital_stmarys.
//
// Important: HospitalArtifact instances are created explicitly in
// cityHub. Ambulances also look them up in cityHub, so all agents
// use the same shared hospital-capacity resource.

+!setupHospital(Cap)
   <- .my_name(Me);
      .concat(Me,"_art",ArtName);

      // cityHub is declared in evds.jcm; the join can complete
      // asynchronously, so wait until its workspace identifier exists.
      ?joined(cityHub,CityHubWid);

      makeArtifact(ArtName,"evds.HospitalArtifact",
                   [Cap],HId)[wid(CityHubWid)];

      +hosp_art(HId);
      focus(HId);

      .print("[HOSPITAL] ",Me,
             " online with ",Cap," beds");

      !turnover.

+?joined(Name,Id) <- .wait(100); ?joined(Name,Id).

// Hospitals autonomously discharge patients over time, restoring bed
// capacity and demonstrating that they are active agents as well as
// shared environment resources.
+!turnover
   <- .wait(math.random*20000+15000);
      ?hosp_art(HId);
      dischargePatient[artifact_id(HId)];
      !turnover.

{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }
{ include("$moise/asl/org-obedient.asl") }